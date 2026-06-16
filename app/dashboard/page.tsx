import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { AppHeader } from "@/components/app-header";
import { Wardrobe } from "@/components/wardrobe";
import { createClient } from "@/lib/supabase-server";
import {
  WARDROBE_BUCKET,
  type Category,
  type WardrobeItem,
} from "@/lib/wardrobe";

export const metadata: Metadata = {
  title: "Wardrobe — Fitcheck",
  description: "Your Fitcheck wardrobe",
};

export default async function DashboardPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const { data, error } = await supabase
    .from("wardrobe_items")
    .select("id, name, category, image_path")
    .order("created_at", { ascending: false });

  const initialItems: WardrobeItem[] = (data ?? []).map((row) => {
    const imagePath = (row.image_path as string | null) ?? null;
    return {
      id: row.id as string,
      name: row.name as string,
      category: row.category as Category,
      imagePath,
      imageUrl: imagePath
        ? supabase.storage.from(WARDROBE_BUCKET).getPublicUrl(imagePath).data
            .publicUrl
        : undefined,
    };
  });

  return (
    <div className="flex min-h-full flex-1 flex-col bg-background text-foreground">
      <AppHeader email={user.email} />
      <main className="mx-auto w-full max-w-6xl flex-1 px-6 py-10 sm:px-8">
        <Wardrobe
          userId={user.id}
          initialItems={initialItems}
          needsSetup={Boolean(error)}
        />
      </main>
    </div>
  );
}
