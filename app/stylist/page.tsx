import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { BottomNav } from "@/components/bottom-nav";
import { StylistChat } from "@/components/stylist-chat";
import { TopBar } from "@/components/top-bar";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "AI Stylist — Fitcheck",
};

export default async function StylistPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/login");
  }
  const t = await getTranslations("stylist");

  return (
    <div className="flex min-h-full flex-1 flex-col bg-background pb-44 text-foreground md:pb-28">
      <TopBar />
      <main className="mx-auto w-full max-w-3xl flex-1 px-5 py-5 md:py-8">
        <h1 className="text-2xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-0.5 mb-5 text-sm text-muted-foreground">
          {t("subtitle")}
        </p>
        <StylistChat />
      </main>
      <BottomNav />
    </div>
  );
}
