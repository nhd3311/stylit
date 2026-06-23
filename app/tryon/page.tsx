import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { BottomNav } from "@/components/bottom-nav";
import { TopBar } from "@/components/top-bar";
import { TryonFlow } from "@/components/tryon-flow";
import { createClient } from "@/lib/supabase-server";
import {
  WARDROBE_BUCKET,
  type Category,
  type WardrobeItem,
} from "@/lib/wardrobe";

export const metadata: Metadata = {
  title: "Thử đồ ảo — Fitcheck",
};

export default async function TryonPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/login");
  }

  const t = await getTranslations("tryon");

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

  return (
    <div className="flex min-h-full flex-1 flex-col bg-background pb-24 text-foreground md:pb-10">
      <TopBar />
      <main className="mx-auto w-full max-w-3xl flex-1 px-5 py-6 md:py-8">
        <h1 className="text-2xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">{t("subtitle")}</p>
        <div className="mt-6">
          <TryonFlow items={items} />
        </div>
      </main>
      <BottomNav />
    </div>
  );
}
