import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase-server";
import { CATEGORIES } from "@/lib/wardrobe";

const MODEL = process.env.GEMINI_MODEL ?? "gemini-3.5-flash";

const PROMPT = `Detect each distinct wearable fashion item (clothing, footwear, or accessory) in this image, and segment each one.
Return ONLY a JSON array. Each element must be exactly:
{"name": a short English product name, "category": one of ["Tops","Bottoms","Outerwear","Shoes","Accessories"], "color": the main color in English, "box_2d": [ymin, xmin, ymax, xmax] normalized to 0-1000, "mask": the segmentation mask of the item as a base64-encoded PNG data URL that covers its bounding box}.
Only include wearable items. Maximum 20 items. If there are none, return [].`;

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
      { error: "Detection is not configured (missing GEMINI_API_KEY)." },
      { status: 500 },
    );
  }

  let body: { imageBase64?: string; mimeType?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Bad request" }, { status: 400 });
  }
  const imageBase64 = body.imageBase64;
  const mimeType = body.mimeType ?? "image/jpeg";
  if (!imageBase64) {
    return NextResponse.json({ error: "No image provided" }, { status: 400 });
  }

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
          contents: [
            {
              parts: [
                { inline_data: { mime_type: mimeType, data: imageBase64 } },
                { text: PROMPT },
              ],
            },
          ],
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.1,
          },
        }),
      },
    );
  } catch {
    return NextResponse.json({ error: "Detection request failed" }, { status: 502 });
  }

  if (!res.ok) {
    return NextResponse.json({ error: "Detection failed" }, { status: 502 });
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

  const items = list.slice(0, 20).map((raw) => {
    const r = (raw ?? {}) as Record<string, unknown>;
    const category =
      typeof r.category === "string" && (CATEGORIES as string[]).includes(r.category)
        ? r.category
        : "Accessories";
    const rawBox = Array.isArray(r.box_2d) ? r.box_2d.map((n) => Number(n)) : [];
    const box2d =
      rawBox.length === 4 && rawBox.every((n) => Number.isFinite(n))
        ? rawBox.map((n) => Math.min(1000, Math.max(0, n)))
        : [0, 0, 1000, 1000];
    return {
      name: typeof r.name === "string" ? r.name.slice(0, 60) : "Item",
      category,
      color: typeof r.color === "string" ? r.color.slice(0, 30) : "",
      box2d,
      mask: typeof r.mask === "string" ? r.mask : null,
    };
  });

  return NextResponse.json({ items });
}
