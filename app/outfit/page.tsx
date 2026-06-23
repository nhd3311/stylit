import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { AppHeader } from "@/components/app-header";
import { OutfitFlow } from "@/components/outfit-flow";
import { createClient } from "@/lib/supabase-server";
import {
  WARDROBE_BUCKET,
  type Category,
  type WardrobeItem,
} from "@/lib/wardrobe";

export const metadata: Metadata = {
  title: "Outfit ideas — Fitcheck",
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

  return (
    <div className="flex min-h-full flex-1 flex-col bg-background text-foreground">
      <AppHeader email={user.email} />
      <main className="mx-auto w-full max-w-3xl flex-1 px-6 py-10 sm:px-8">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">
              {t("title")}
            </h1>
            <p className="mt-1 text-sm text-muted-foreground">
              {t("subtitle")}
            </p>
          </div>
          <Link
            href="/dashboard"
            className="shrink-0 text-sm font-medium text-violet-400 transition hover:text-violet-300"
          >
            {t("back")}
          </Link>
        </div>
        <div className="mt-8">
          <OutfitFlow items={items} />
        </div>
      </main>
    </div>
  );
}
