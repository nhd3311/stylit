import type { Metadata } from "next";
import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { AuthShell } from "@/components/auth-shell";
import { ResetPasswordForm } from "@/components/reset-password-form";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "New password — Fitcheck",
  description: "Set a new password",
};

export default async function ResetPasswordPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const t = await getTranslations("auth");

  if (!user) {
    return (
      <AuthShell title={t("resetTitle")}>
        <div className="flex flex-col gap-4 text-center">
          <p className="text-sm text-muted-foreground">
            {t("resetLinkInvalid")}
          </p>
          <Link
            href="/forgot-password"
            className="text-sm font-medium text-violet-400 transition hover:text-violet-300"
          >
            {t("requestNewLink")}
          </Link>
        </div>
      </AuthShell>
    );
  }

  return (
    <AuthShell title={t("resetTitle")} subtitle={t("resetSubtitle")}>
      <ResetPasswordForm />
    </AuthShell>
  );
}
