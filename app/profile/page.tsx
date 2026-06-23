import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { BottomNav } from "@/components/bottom-nav";
import { StyleProfileForm } from "@/components/style-profile-form";
import { TopBar } from "@/components/top-bar";
import { type Profile } from "@/lib/profile";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "Chỉ số của tôi — Fitcheck",
};

export default async function ProfilePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const t = await getTranslations("profilePage");

  const { data: row } = await supabase
    .from("profiles")
    .select(
      "height_cm, weight_kg, body_type, skin_tone, styles, colors, occasions, onboarded",
    )
    .eq("user_id", user.id)
    .maybeSingle();

  const profile: Profile = {
    heightCm: (row?.height_cm as number | null) ?? null,
    weightKg: (row?.weight_kg as number | null) ?? null,
    bodyType: (row?.body_type as string | null) ?? null,
    skinTone: (row?.skin_tone as string | null) ?? null,
    styles: (row?.styles as string[] | null) ?? [],
    colors: (row?.colors as string[] | null) ?? [],
    occasions: (row?.occasions as string[] | null) ?? [],
    onboarded: (row?.onboarded as boolean | null) ?? false,
  };

  return (
    <div className="flex min-h-full flex-1 flex-col bg-background pb-24 text-foreground md:pb-10">
      <TopBar />
      <main className="mx-auto w-full max-w-2xl flex-1 px-5 py-6 md:py-8">
        <h1 className="text-2xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-1 text-sm text-muted-foreground">{t("subtitle")}</p>
        <div className="mt-6">
          <StyleProfileForm userId={user.id} initial={profile} />
        </div>
      </main>
      <BottomNav />
    </div>
  );
}
