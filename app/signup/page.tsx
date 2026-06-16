import type { Metadata } from "next";
import { AuthShell } from "@/components/auth-shell";
import { SignupForm } from "@/components/signup-form";

export const metadata: Metadata = {
  title: "Đăng ký — Fitcheck",
  description: "Tạo tài khoản Fitcheck mới",
};

export default function SignupPage() {
  return (
    <AuthShell
      title="Đăng ký"
      subtitle="Tạo tài khoản để bắt đầu phối đồ thông minh"
    >
      <SignupForm />
    </AuthShell>
  );
}
