import type { Metadata } from "next";
import { AuthShell } from "@/components/auth-shell";
import { LoginForm } from "@/components/login-form";

export const metadata: Metadata = {
  title: "Đăng nhập — Fitcheck",
  description: "Đăng nhập vào tài khoản Fitcheck của bạn",
};

export default function LoginPage() {
  return (
    <AuthShell
      title="Đăng nhập"
      subtitle="Chào mừng trở lại Fitcheck"
    >
      <LoginForm />
    </AuthShell>
  );
}
