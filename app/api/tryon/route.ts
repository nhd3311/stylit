import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase-server";

export const maxDuration = 60;

const FASHN_RUN = "https://api.fashn.ai/v1/run";
const CATEGORIES = ["tops", "bottoms", "one-pieces"];

export async function POST(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const apiKey = process.env.FASHN_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: "Try-on is not configured (missing FASHN_API_KEY)." },
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

  const garment =
    typeof body.garmentImageUrl === "string" ? body.garmentImageUrl : "";
  const modelImage =
    typeof body.modelImageBase64 === "string" && body.modelImageBase64
      ? body.modelImageBase64
      : typeof body.modelImageUrl === "string"
        ? body.modelImageUrl
        : "";
  const category =
    typeof body.category === "string" && CATEGORIES.includes(body.category)
      ? body.category
      : "tops";

  if (!garment || !modelImage) {
    return NextResponse.json({ error: "Missing image" }, { status: 400 });
  }

  let res: Response;
  try {
    res = await fetch(FASHN_RUN, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model_image: modelImage,
        garment_image: garment,
        category,
      }),
    });
  } catch {
    return NextResponse.json({ error: "Try-on request failed" }, { status: 502 });
  }

  const json = (await res.json().catch(() => null)) as {
    id?: string;
    error?: { message?: string } | string | null;
  } | null;

  if (!res.ok || !json?.id) {
    const raw = json?.error;
    const msg =
      typeof raw === "string"
        ? raw
        : raw && typeof raw.message === "string"
          ? raw.message
          : "Try-on failed";
    return NextResponse.json({ error: msg }, { status: 502 });
  }

  return NextResponse.json({ id: json.id });
}
