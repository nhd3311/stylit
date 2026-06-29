import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase-server";

export const maxDuration = 60;

const IMAGE_MODEL = process.env.GEMINI_IMAGE_MODEL ?? "gemini-2.5-flash-image";

const ANGLE_PROMPTS: Record<string, string> = {
  right:
    "now viewed from the person's right side, with the camera rotated about 90 degrees to the right",
  back: "now viewed from directly behind — a full back view",
  left:
    "now viewed from the person's left side, with the camera rotated about 90 degrees to the left",
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
    garmentImageUrls?: string[];
    modelImageUrl?: string;
    modelImageBase64?: string;
    referenceImageBase64?: string;
    angle?: string;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Bad request" }, { status: 400 });
  }

  const angle = typeof body.angle === "string" ? body.angle : "front";

  let subject: Inline | null = null;
  let isReference = false;
  if (typeof body.referenceImageBase64 === "string" && body.referenceImageBase64) {
    subject = dataUrlToInline(body.referenceImageBase64);
    isReference = true;
  } else if (typeof body.modelImageBase64 === "string" && body.modelImageBase64) {
    subject = dataUrlToInline(body.modelImageBase64);
  } else if (typeof body.modelImageUrl === "string" && body.modelImageUrl) {
    subject = await urlToInline(body.modelImageUrl);
  }
  if (!subject) {
    return NextResponse.json({ error: "Couldn't read the photo." }, { status: 400 });
  }

  let parts: { text?: string; inline_data?: { mime_type: string; data: string } }[];

  if (isReference && ANGLE_PROMPTS[angle]) {
    const prompt = `The image shows a person wearing an outfit. Generate ONE photorealistic, full-body image of the EXACT SAME person in the EXACT SAME outfit, ${ANGLE_PROMPTS[angle]}. Keep identical clothing, colors, hairstyle, body shape and the clean studio background; change only the camera viewpoint. Output only the image.`;
    parts = [
      { text: prompt },
      { inline_data: { mime_type: subject.mime, data: subject.data } },
    ];
  } else {
    const urls = Array.isArray(body.garmentImageUrls)
      ? body.garmentImageUrls.slice(0, 6)
      : [];
    const garments = (await Promise.all(urls.map(urlToInline))).filter(
      (g): g is Inline => Boolean(g),
    );
    if (garments.length === 0) {
      return NextResponse.json({ error: "No garment image." }, { status: 400 });
    }
    const prompt = `The FIRST image is a photo of a person. The following ${garments.length} image(s) are clothing items. Generate ONE photorealistic, full-body image of the SAME person wearing ALL of these items together as one complete outfit, viewed from the front, standing on a clean light studio background. Keep the person's face, hairstyle, body shape and skin tone. Render a realistic fit with natural fabric folds and lighting, matching each garment's colors and patterns. Output only the image.`;
    parts = [
      { text: prompt },
      { inline_data: { mime_type: subject.mime, data: subject.data } },
      ...garments.map((g) => ({
        inline_data: { mime_type: g.mime, data: g.data },
      })),
    ];
  }

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
          contents: [{ parts }],
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
  const outParts = json.candidates?.[0]?.content?.parts ?? [];
  const imgPart = outParts.find((p) => p.inlineData?.data);
  if (!imgPart?.inlineData?.data) {
    const txt = outParts
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
