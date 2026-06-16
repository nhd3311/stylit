import type { Metadata } from "next";
import { useTranslations } from "next-intl";
import { AuthShell } from "@/components/auth-shell";
import { SignupForm } from "@/components/signup-form";

export const metadata: Metadata = {
  title: "Sign up — Fitcheck",
  description: "Create a new Fitcheck account",
};

export default function SignupPage() {
  const t = useTranslations("auth");
  return (
    <AuthShell title={t("signupTitle")} subtitle={t("signupSubtitle")}>
      <SignupForm />
    </AuthShell>
  );
}
