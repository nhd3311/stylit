import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase-server";

export const maxDuration = 60;

const MODEL = process.env.GEMINI_MODEL ?? "gemini-3.5-flash";

type Msg = { role: "user" | "assistant"; content: string };
type WardrobeRow = { name: string; category: string };

function buildSystem(wardrobe: WardrobeRow[], prof: Record<string, unknown> | null) {
  const styles = ((prof?.styles as string[] | null) ?? []).join(", ") || "not specified";
  const colors = ((prof?.colors as string[] | null) ?? []).join(", ") || "not specified";
  const occasions = ((prof?.occasions as string[] | null) ?? []).join(", ") || "not specified";
  const body = (prof?.body_type as string | null) || "not specified";
  const skin = (prof?.skin_tone as string | null) || "not specified";
  const wj = JSON.stringify(wardrobe);
  return `You are Fitcheck's friendly AI stylist for a Gen Z user. Be warm, encouraging, concise and practical — keep replies to about 2-5 sentences. Reply in the SAME language as the user's latest message (Vietnamese or English).

USER STYLE PROFILE — preferred styles: ${styles}; color tones: ${colors}; usual occasions: ${occasions}; body shape: ${body}; skin tone: ${skin}.

USER WARDROBE (name · category): ${wj}

When you suggest a specific outfit, build it ONLY from items in the wardrobe above and name those items. You may also give general styling tips, color/fit advice tailored to their skin tone and body shape. If the wardrobe is missing something useful, you can gently suggest what kind of piece to add. Never invent specific items they do not own.`;
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
      { error: "Stylist is not configured (missing GEMINI_API_KEY)." },
      { status: 500 },
    );
  }

  let body: { messages?: Msg[] };
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const raw = Array.isArray(body.messages) ? body.messages : [];
  let conv: Msg[] = raw
    .filter(
      (m) =>
        m &&
        (m.role === "user" || m.role === "assistant") &&
        typeof m.content === "string" &&
        m.content.trim().length > 0,
    )
    .map((m) => ({ role: m.role, content: m.content.slice(0, 1200) }));
  while (conv.length > 0 && conv[0].role !== "user") {
    conv = conv.slice(1);
  }
  if (conv.length === 0) {
    return NextResponse.json({ error: "No message" }, { status: 400 });
  }

  const { data: wardrobeData } = await supabase
    .from("wardrobe_items")
    .select("name, category")
    .order("created_at", { ascending: false });
  const wardrobe: WardrobeRow[] = (wardrobeData ?? []).slice(0, 120).map((r) => ({
    name: String(r.name),
    category: String(r.category),
  }));

  const { data: prof } = await supabase
    .from("profiles")
    .select("body_type, skin_tone, styles, colors, occasions")
    .eq("user_id", user.id)
    .maybeSingle();

  const systemText = buildSystem(wardrobe, prof);

  const contents = [
    { role: "user", parts: [{ text: systemText }] },
    { role: "model", parts: [{ text: "OK, mình sẵn sàng giúp bạn phối đồ!" }] },
    ...conv.slice(-12).map((m) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{ text: m.content }],
    })),
  ];

  let res: Response;
  try {
    res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "x-goog-api-key": apiKey, "Content-Type": "application/json" },
        body: JSON.stringify({ contents, generationConfig: { temperature: 0.8 } }),
      },
    );
  } catch {
    return NextResponse.json({ error: "Stylist request failed" }, { status: 502 });
  }
  if (!res.ok) {
    return NextResponse.json({ error: "Stylist failed" }, { status: 502 });
  }

  const json = (await res.json()) as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  };
  const reply =
    json.candidates?.[0]?.content?.parts?.map((p) => p.text ?? "").join("").trim() ||
    "";

  return NextResponse.json({ reply });
}
