import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { BottomNav } from "@/components/bottom-nav";
import { TopBar } from "@/components/top-bar";
import { Wardrobe } from "@/components/wardrobe";
import { createClient } from "@/lib/supabase-server";
import {
  WARDROBE_BUCKET,
  type Category,
  type WardrobeItem,
} from "@/lib/wardrobe";

export const metadata: Metadata = {
  title: "Tủ đồ — Fitcheck",
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

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("onboarded")
    .eq("user_id", user.id)
    .maybeSingle();
  if (!profileError && !profile?.onboarded) {
    redirect("/onboarding");
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
    <div className="flex min-h-full flex-1 flex-col bg-background pb-40 text-foreground">
      <TopBar />
      <main className="mx-auto w-full max-w-xl flex-1 px-5 py-6">
        <Wardrobe
          initialItems={initialItems}
          needsSetup={Boolean(error)}
        />
      </main>
      <BottomNav />
    </div>
  );
}
