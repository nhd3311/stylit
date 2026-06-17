import type { Metadata } from "next";
import { useTranslations } from "next-intl";
import { AuthShell } from "@/components/auth-shell";
import { ForgotPasswordForm } from "@/components/forgot-password-form";

export const metadata: Metadata = {
  title: "Reset password — Fitcheck",
  description: "Reset your Fitcheck password",
};

export default function ForgotPasswordPage() {
  const t = useTranslations("auth");
  return (
    <AuthShell title={t("forgotTitle")} subtitle={t("forgotSubtitle")}>
      <ForgotPasswordForm />
    </AuthShell>
  );
}
