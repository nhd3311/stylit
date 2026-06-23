import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase-server";

export async function GET(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const apiKey = process.env.FASHN_API_KEY;
  if (!apiKey) {
    return NextResponse.json({ error: "Not configured" }, { status: 500 });
  }

  const id = new URL(request.url).searchParams.get("id");
  if (!id) {
    return NextResponse.json({ error: "Missing id" }, { status: 400 });
  }

  let res: Response;
  try {
    res = await fetch(`https://api.fashn.ai/v1/status/${encodeURIComponent(id)}`, {
      headers: { Authorization: `Bearer ${apiKey}` },
    });
  } catch {
    return NextResponse.json({ error: "Status request failed" }, { status: 502 });
  }

  const json = (await res.json().catch(() => null)) as {
    status?: string;
    output?: string[] | null;
    error?: { message?: string } | string | null;
  } | null;

  if (!json) {
    return NextResponse.json({ error: "Status failed" }, { status: 502 });
  }

  const raw = json.error;
  const errMsg =
    typeof raw === "string"
      ? raw
      : raw && typeof raw.message === "string"
        ? raw.message
        : null;

  return NextResponse.json({
    status: json.status ?? "unknown",
    output: json.output ?? null,
    error: errMsg,
  });
}
