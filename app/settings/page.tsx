import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { AccountActions } from "@/components/account-actions";
import { AppearanceSetting } from "@/components/appearance-setting";
import { BottomNav } from "@/components/bottom-nav";
import { ChangePasswordForm } from "@/components/change-password-form";
import { LanguageSetting } from "@/components/language-setting";
import { SignOutButton } from "@/components/sign-out-button";
import { TopBar } from "@/components/top-bar";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "Cài đặt — Fitcheck",
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
    <div className="flex min-h-full flex-1 flex-col bg-background pb-24 text-foreground">
      <TopBar />
      <main className="mx-auto w-full max-w-xl flex-1 px-5 py-6">
        <h1 className="text-2xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">{t("subtitle")}</p>

        <div className="mt-6 flex flex-col gap-5">
          <section className="rounded-2xl border border-border bg-card p-5">
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

          <Link
            href="/profile"
            className="flex items-center justify-between rounded-2xl border border-border bg-card p-5 transition hover:border-primary/40"
          >
            <div>
              <h2 className="text-lg font-semibold">{t("styleProfile")}</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                {t("styleProfileDesc")}
              </p>
            </div>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5 shrink-0 text-muted-foreground" aria-hidden="true">
              <path d="M9 6l6 6-6 6" />
            </svg>
          </Link>

          <section className="rounded-2xl border border-border bg-card p-5">
            <h2 className="text-lg font-semibold">{t("appearance")}</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {t("appearanceDesc")}
            </p>
            <div className="mt-4">
              <p className="mb-2 text-sm font-medium">{t("theme")}</p>
              <AppearanceSetting />
            </div>
          </section>

          <section className="rounded-2xl border border-border bg-card p-5">
            <h2 className="text-lg font-semibold">{t("language")}</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {t("languageDesc")}
            </p>
            <div className="mt-4">
              <LanguageSetting />
            </div>
          </section>

          <section className="rounded-2xl border border-border bg-card p-5">
            <h2 className="text-lg font-semibold">{t("security")}</h2>
            <div className="mt-5 flex flex-col gap-8">
              <div>
                <h3 className="text-sm font-medium">{t("changePassword")}</h3>
                <p className="mt-1 text-sm text-muted-foreground">
                  {t("changePasswordDesc")}
                </p>
                <div className="mt-4">
                  <ChangePasswordForm />
                </div>
              </div>
              <AccountActions />
            </div>
          </section>
        </div>
      </main>
      <BottomNav />
    </div>
  );
}
