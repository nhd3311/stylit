import type { Metadata } from "next";
import { AuthShell } from "@/components/auth-shell";
import { SignupForm } from "@/components/signup-form";

export const metadata: Metadata = {
  title: "Sign up — Fitcheck",
  description: "Create a new Fitcheck account",
};

export default function SignupPage() {
  return (
    <AuthShell
      title="Sign up"
      subtitle="Create an account to start styling smarter"
    >
      <SignupForm />
    </AuthShell>
  );
}
