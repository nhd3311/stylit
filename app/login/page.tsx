import type { Metadata } from "next";
import { useTranslations } from "next-intl";
import { AuthShell } from "@/components/auth-shell";
import { LoginForm } from "@/components/login-form";
import { OAuthButtons } from "@/components/oauth-buttons";

export const metadata: Metadata = {
  title: "Log in — Fitcheck",
  description: "Log in to your Fitcheck account",
};

export default function LoginPage() {
  const t = useTranslations("auth");
  return (
    <AuthShell title={t("loginTitle")} subtitle={t("loginSubtitle")}>
      <OAuthButtons />
      <LoginForm />
    </AuthShell>
  );
}
