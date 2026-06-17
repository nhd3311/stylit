import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { AppHeader } from "@/components/app-header";
import { DetectFlow } from "@/components/detect-flow";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "Scan — Fitcheck",
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
    <div className="flex min-h-full flex-1 flex-col bg-background text-foreground">
      <AppHeader email={user.email} />
      <main className="mx-auto w-full max-w-xl flex-1 px-6 py-10 sm:px-8">
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
          <DetectFlow userId={user.id} />
        </div>
      </main>
    </div>
  );
}
