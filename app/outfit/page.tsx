import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { BottomNav } from "@/components/bottom-nav";
import { OutfitFlow } from "@/components/outfit-flow";
import { TopBar } from "@/components/top-bar";
import { type SavedLook } from "@/lib/outfit";
import { createClient } from "@/lib/supabase-server";
import {
  WARDROBE_BUCKET,
  type Category,
  type WardrobeItem,
} from "@/lib/wardrobe";

export const metadata: Metadata = {
  title: "Phối đồ — Fitcheck",
  description: "AI outfit suggestions from your wardrobe",
};

export default async function OutfitPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/login");
  }

  const t = await getTranslations("outfit");

  const { data } = await supabase
    .from("wardrobe_items")
    .select("id, name, category, image_path")
    .order("created_at", { ascending: false });

  const items: WardrobeItem[] = (data ?? []).map((row) => {
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

  const { data: looksData } = await supabase
    .from("saved_looks")
    .select("id, title, reason, item_ids")
    .order("created_at", { ascending: false });

  const initialLooks: SavedLook[] = (looksData ?? []).map((row) => ({
    id: row.id as string,
    title: (row.title as string | null) ?? "Outfit",
    reason: (row.reason as string | null) ?? "",
    itemIds: (row.item_ids as string[] | null) ?? [],
  }));

  return (
    <div className="flex min-h-full flex-1 flex-col bg-background pb-24 text-foreground">
      <TopBar />
      <main className="mx-auto w-full max-w-xl flex-1 px-5 py-6">
        <h1 className="text-2xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">{t("subtitle")}</p>
        <div className="mt-6">
          <OutfitFlow
            items={items}
            userId={user.id}
            initialLooks={initialLooks}
          />
        </div>
      </main>
      <BottomNav />
    </div>
  );
}
