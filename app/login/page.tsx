import type { Metadata } from "next";
import { AuthShell } from "@/components/auth-shell";
import { LoginForm } from "@/components/login-form";

export const metadata: Metadata = {
  title: "Log in — Fitcheck",
  description: "Log in to your Fitcheck account",
};

export default function LoginPage() {
  return (
    <AuthShell title="Log in" subtitle="Welcome back to Fitcheck">
      <LoginForm />
    </AuthShell>
  );
}
