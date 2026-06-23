import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase-server";

export const maxDuration = 60;

const IMAGE_MODEL = process.env.GEMINI_IMAGE_MODEL ?? "gemini-2.5-flash-image";

const CAT_TEXT: Record<string, string> = {
  tops: "top / upper-body garment",
  bottoms: "bottoms / lower-body garment",
  "one-pieces": "one-piece outfit (dress or jumpsuit)",
};

type Inline = { mime: string; data: string };

function dataUrlToInline(dataUrl: string): Inline | null {
  const m = dataUrl.match(/^data:([^;]+);base64,(.+)$/);
  if (!m) {
    return null;
  }
  return { mime: m[1], data: m[2] };
}

async function urlToInline(url: string): Promise<Inline | null> {
  try {
    const r = await fetch(url);
    if (!r.ok) {
      return null;
    }
    const mime = (r.headers.get("content-type") ?? "image/jpeg").split(";")[0];
    const buf = Buffer.from(await r.arrayBuffer());
    return { mime, data: buf.toString("base64") };
  } catch {
    return null;
  }
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
      { error: "Try-on is not configured (missing GEMINI_API_KEY)." },
      { status: 500 },
    );
  }

  let body: {
    garmentImageUrl?: string;
    modelImageUrl?: string;
    modelImageBase64?: string;
    category?: string;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Bad request" }, { status: 400 });
  }

  const category =
    body.category && CAT_TEXT[body.category] ? body.category : "tops";

  const garment =
    typeof body.garmentImageUrl === "string"
      ? await urlToInline(body.garmentImageUrl)
      : null;

  let model: Inline | null = null;
  if (typeof body.modelImageBase64 === "string" && body.modelImageBase64) {
    model = dataUrlToInline(body.modelImageBase64);
  } else if (typeof body.modelImageUrl === "string" && body.modelImageUrl) {
    model = await urlToInline(body.modelImageUrl);
  }

  if (!garment || !model) {
    return NextResponse.json(
      { error: "Couldn't read the images." },
      { status: 400 },
    );
  }

  const cat = CAT_TEXT[category];
  const prompt = `You are a professional virtual try-on engine. The FIRST image is a photo of a person. The SECOND image is a clothing item (a ${cat}). Generate ONE photorealistic image of the SAME person from the first image now wearing that exact clothing item. Keep the person's face, hairstyle, body shape, skin tone, pose and the original background unchanged. Fit the garment naturally with realistic folds, drape and lighting, matching the garment's colors and patterns. Replace only the ${cat}; keep the rest of their clothing. Output only the image.`;

  let res: Response;
  try {
    res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${IMAGE_MODEL}:generateContent`,
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
                { text: prompt },
                { inline_data: { mime_type: model.mime, data: model.data } },
                { inline_data: { mime_type: garment.mime, data: garment.data } },
              ],
            },
          ],
          generationConfig: { responseModalities: ["IMAGE"] },
        }),
      },
    );
  } catch {
    return NextResponse.json({ error: "Try-on request failed" }, { status: 502 });
  }

  if (!res.ok) {
    const errText = await res.text().catch(() => "");
    return NextResponse.json(
      { error: errText.slice(0, 200) || "Try-on failed" },
      { status: 502 },
    );
  }

  const json = (await res.json()) as {
    candidates?: {
      content?: {
        parts?: { text?: string; inlineData?: { mimeType?: string; data?: string } }[];
      };
    }[];
  };
  const parts = json.candidates?.[0]?.content?.parts ?? [];
  const imgPart = parts.find((p) => p.inlineData?.data);
  if (!imgPart?.inlineData?.data) {
    const txt = parts
      .map((p) => p.text ?? "")
      .join(" ")
      .trim();
    return NextResponse.json(
      { error: txt ? txt.slice(0, 200) : "No image generated" },
      { status: 502 },
    );
  }
  const mime = imgPart.inlineData.mimeType ?? "image/png";
  return NextResponse.json({
    image: `data:${mime};base64,${imgPart.inlineData.data}`,
  });
}
