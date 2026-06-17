import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase-admin";
import { createClient } from "@/lib/supabase-server";
import { WARDROBE_BUCKET } from "@/lib/wardrobe";

// Deletes ONLY the currently authenticated user's account + data.
export async function POST() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const admin = createAdminClient();
  if (!admin) {
    return NextResponse.json(
      { error: "Account deletion is not configured on the server." },
      { status: 500 },
    );
  }

  // Best-effort: remove the user's wardrobe images from storage.
  const { data: files } = await admin.storage
    .from(WARDROBE_BUCKET)
    .list(user.id);
  if (files && files.length > 0) {
    await admin.storage
      .from(WARDROBE_BUCKET)
      .remove(files.map((file) => `${user.id}/${file.name}`));
  }

  // Delete the auth user (wardrobe_items cascade via FK on delete cascade).
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    return NextResponse.json({ error: "Delete failed" }, { status: 500 });
  }

  await supabase.auth.signOut();

  return NextResponse.json({ ok: true });
}
