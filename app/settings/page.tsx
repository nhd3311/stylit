import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { AccountActions } from "@/components/account-actions";
import { AppHeader } from "@/components/app-header";
import { AppearanceSetting } from "@/components/appearance-setting";
import { ChangePasswordForm } from "@/components/change-password-form";
import { LanguageSetting } from "@/components/language-setting";
import { SignOutButton } from "@/components/sign-out-button";
import { StyleProfileForm } from "@/components/style-profile-form";
import { type Profile } from "@/lib/profile";
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

  const { data: profileRow } = await supabase
    .from("profiles")
    .select("height_cm, weight_kg, body_type, styles, colors, occasions, onboarded")
    .eq("user_id", user.id)
    .maybeSingle();

  const profile: Profile = {
    heightCm: (profileRow?.height_cm as number | null) ?? null,
    weightKg: (profileRow?.weight_kg as number | null) ?? null,
    bodyType: (profileRow?.body_type as string | null) ?? null,
    styles: (profileRow?.styles as string[] | null) ?? [],
    colors: (profileRow?.colors as string[] | null) ?? [],
    occasions: (profileRow?.occasions as string[] | null) ?? [],
    onboarded: (profileRow?.onboarded as boolean | null) ?? false,
  };

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

          <section className="rounded-2xl border border-border bg-card p-6">
            <h2 className="text-lg font-semibold">{t("styleProfile")}</h2>
            <p className="mt-1 mb-5 text-sm text-muted-foreground">
              {t("styleProfileDesc")}
            </p>
            <StyleProfileForm userId={user.id} initial={profile} />
          </section>

          <section className="rounded-2xl border border-border bg-card p-6">
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
    </div>
  );
}
