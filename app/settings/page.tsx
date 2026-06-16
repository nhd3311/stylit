import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { AppHeader } from "@/components/app-header";
import { AppearanceSetting } from "@/components/appearance-setting";
import { LanguageSetting } from "@/components/language-setting";
import { SignOutButton } from "@/components/sign-out-button";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "Settings — Fitcheck",
  description: "Manage your Fitcheck account and preferences",
};

export default async function SettingsPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const t = await getTranslations("settings");
  const memberSince = user.created_at
    ? new Date(user.created_at).toLocaleDateString()
    : null;

  return (
    <div className="flex min-h-full flex-1 flex-col bg-background text-foreground">
      <AppHeader email={user.email} />
      <main className="mx-auto w-full max-w-3xl flex-1 px-6 py-10 sm:px-8">
        <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">
          {t("title")}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">{t("subtitle")}</p>

        <div className="mt-8 flex flex-col gap-5">
          <section className="rounded-2xl border border-border bg-card p-6">
            <h2 className="text-lg font-semibold">{t("account")}</h2>
            <dl className="mt-4 flex flex-col gap-3 text-sm">
              <div className="flex items-center justify-between gap-4">
                <dt className="text-muted-foreground">{t("email")}</dt>
                <dd className="font-medium">{user.email}</dd>
              </div>
              {memberSince && (
                <div className="flex items-center justify-between gap-4">
                  <dt className="text-muted-foreground">{t("memberSince")}</dt>
                  <dd className="font-medium">{memberSince}</dd>
                </div>
              )}
            </dl>
            <div className="mt-5">
              <SignOutButton className="rounded-lg border border-border bg-background px-4 py-2 text-sm font-medium text-foreground transition hover:bg-muted disabled:opacity-60" />
            </div>
          </section>

          <section className="rounded-2xl border border-border bg-card p-6">
            <h2 className="text-lg font-semibold">{t("appearance")}</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {t("appearanceDesc")}
            </p>
            <div className="mt-4">
              <p className="mb-2 text-sm font-medium">{t("theme")}</p>
              <AppearanceSetting />
            </div>
          </section>

          <section className="rounded-2xl border border-border bg-card p-6">
            <h2 className="text-lg font-semibold">{t("language")}</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {t("languageDesc")}
            </p>
            <div className="mt-4">
              <LanguageSetting />
            </div>
          </section>
        </div>
      </main>
    </div>
  );
}
