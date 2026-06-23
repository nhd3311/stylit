import { NextResponse } from "next/server";
import type { SuggestedOutfit } from "@/lib/outfit";
import { createClient } from "@/lib/supabase-server";

export const maxDuration = 60;

const MODEL = process.env.GEMINI_MODEL ?? "gemini-3.5-flash";
const OUTFIT_COUNT = 3;

// Map the profile occasion value to a natural English phrase for the prompt.
const OCCASION_EN: Record<string, string> = {
  work: "work or the office",
  daily: "everyday casual wear",
  sport: "sport or the gym",
  party: "a party or a night out",
  date: "a date",
  travel: "travel",
  school: "school or campus",
};

type WardrobeRow = { id: string; name: string; category: string };

function buildPrompt(args: {
  wardrobe: WardrobeRow[];
  styles: string[];
  colors: string[];
  bodyType: string;
  occasion: string;
  note: string;
}): string {
  const { wardrobe, styles, colors, bodyType, occasion, note } = args;
  const wardrobeJson = JSON.stringify(
    wardrobe.map((w) => ({ id: w.id, name: w.name, category: w.category })),
  );
  const stylesText = styles.length ? styles.join(", ") : "not specified";
  const colorsText = colors.length ? colors.join(", ") : "not specified";
  const bodyText = bodyType || "not specified";
  const noteLine = note ? `\nADDITIONAL REQUEST FROM THE USER: ${note}` : "";

  return `You are an expert fashion stylist helping someone create outfits from clothes they already own.

USER STYLE PROFILE
- Preferred styles: ${stylesText}
- Preferred color tones: ${colorsText}
- Body type: ${bodyText}

OCCASION: ${occasion}${noteLine}

WARDROBE (you may ONLY use these items, and you must reference each item by its exact "id"):
${wardrobeJson}

TASK
Create up to ${OUTFIT_COUNT} distinct, complete outfits suitable for the occasion, using ONLY items from the wardrobe above. A good outfit usually combines a top and a bottom (or a one-piece), and may add outerwear, shoes, and accessories when available. Favor the user's preferred styles and color tones when possible. Do not repeat the same combination. Each outfit must use at least 2 items.

Return ONLY a JSON array. Each element must be exactly:
{"title": a short catchy outfit name (max 6 words), "itemIds": [the ids of the items in this outfit], "reason": one short sentence on why this outfit works for the occasion and the person}
If the wardrobe is too limited to build any sensible outfit, return [].`;
}

export async function POST(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: "Suggestions are not configured (missing GEMINI_API_KEY)." },
      { status: 500 },
    );
  }

  let body: { occasion?: string | null; note?: string };
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const occasionKey = typeof body.occasion === "string" ? body.occasion : "";
  const occasion = OCCASION_EN[occasionKey] ?? "everyday, any occasion";
  const note =
    typeof body.note === "string" ? body.note.slice(0, 200).trim() : "";

  // Wardrobe — RLS limits this to the current user's items.
  const { data: wardrobeData, error: wardrobeError } = await supabase
    .from("wardrobe_items")
    .select("id, name, category")
    .order("created_at", { ascending: false });
  if (wardrobeError) {
    return NextResponse.json(
      { error: "Couldn't read your wardrobe." },
      { status: 500 },
    );
  }
  const wardrobe: WardrobeRow[] = (wardrobeData ?? []).map((row) => ({
    id: String(row.id),
    name: String(row.name),
    category: String(row.category),
  }));
  if (wardrobe.length < 2) {
    return NextResponse.json({ outfits: [] });
  }
  const validIds = new Set(wardrobe.map((w) => w.id));

  // Style profile is optional — suggestions still work without it.
  const { data: profileRow } = await supabase
    .from("profiles")
    .select("body_type, styles, colors")
    .eq("user_id", user.id)
    .maybeSingle();
  const styles = (profileRow?.styles as string[] | null) ?? [];
  const colors = (profileRow?.colors as string[] | null) ?? [];
  const bodyType = (profileRow?.body_type as string | null) ?? "";

  const prompt = buildPrompt({
    wardrobe,
    styles,
    colors,
    bodyType,
    occasion,
    note,
  });

  let res: Response;
  try {
    res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: {
          "x-goog-api-key": apiKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.7,
          },
        }),
      },
    );
  } catch {
    return NextResponse.json(
      { error: "Suggestion request failed" },
      { status: 502 },
    );
  }

  if (!res.ok) {
    return NextResponse.json({ error: "Suggestion failed" }, { status: 502 });
  }

  const json = (await res.json()) as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  };
  const text = json.candidates?.[0]?.content?.parts?.[0]?.text ?? "[]";

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = [];
  }
  const list = Array.isArray(parsed) ? parsed : [];

  const outfits: SuggestedOutfit[] = [];
  for (const raw of list) {
    const r = (raw ?? {}) as Record<string, unknown>;
    const rawIds = Array.isArray(r.itemIds) ? r.itemIds : [];
    const itemIds: string[] = [];
    for (const id of rawIds) {
      const s = String(id);
      if (validIds.has(s) && !itemIds.includes(s)) {
        itemIds.push(s);
      }
    }
    if (itemIds.length < 2) {
      continue;
    }
    const title =
      typeof r.title === "string" && r.title.trim()
        ? r.title.slice(0, 60)
        : "Outfit";
    const reason = typeof r.reason === "string" ? r.reason.slice(0, 200) : "";
    outfits.push({ title, itemIds: itemIds.slice(0, 6), reason });
    if (outfits.length >= OUTFIT_COUNT) {
      break;
    }
  }

  return NextResponse.json({ outfits });
}
