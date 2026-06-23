import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { BottomNav } from "@/components/bottom-nav";
import { DetectFlow } from "@/components/detect-flow";
import { TopBar } from "@/components/top-bar";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "Thêm món đồ — Fitcheck",
  description: "Detect clothing items from a photo",
};

export default async function DetectPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const t = await getTranslations("detect");

  return (
    <div className="flex min-h-full flex-1 flex-col bg-background pb-24 text-foreground">
      <TopBar />
      <main className="mx-auto w-full max-w-xl flex-1 px-5 py-6">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold tracking-tight">{t("title")}</h1>
            <p className="mt-1 text-sm text-muted-foreground">{t("subtitle")}</p>
          </div>
          <Link
            href="/dashboard"
            className="shrink-0 text-sm font-medium text-primary transition hover:opacity-80"
          >
            {t("back")}
          </Link>
        </div>
        <div className="mt-6">
          <DetectFlow userId={user.id} />
        </div>
      </main>
      <BottomNav />
    </div>
  );
}
