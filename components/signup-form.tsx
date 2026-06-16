"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import {
  authButtonClassName,
  authInputClassName,
  authLabelClassName,
} from "@/components/auth-shell";
import {
  getAuthErrorMessage,
  validateEmail,
  validatePassword,
} from "@/lib/auth-validation";
import { createClient } from "@/lib/supabase-client";

export function SignupForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    const emailError = validateEmail(email);
    if (emailError) {
      setError(emailError);
      return;
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      setError(passwordError);
      return;
    }

    if (password !== confirmPassword) {
      setError("Mật khẩu xác nhận không khớp.");
      return;
    }

    setLoading(true);

    const supabase = createClient();
    const { data, error: signUpError } = await supabase.auth.signUp({
      email: email.trim().toLowerCase(),
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/confirm`,
      },
    });

    setLoading(false);

    if (signUpError) {
      setError(getAuthErrorMessage(signUpError.message));
      return;
    }

    if (data.session) {
      setSuccess("Đăng ký thành công!");
      router.push("/dashboard");
      router.refresh();
      return;
    }

    setSuccess(
      "Đăng ký thành công! Vui lòng kiểm tra email để xác nhận tài khoản.",
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5">
      <div>
        <label htmlFor="signup-email" className={authLabelClassName}>
          Email
        </label>
        <input
          id="signup-email"
          type="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="ten@email.com"
          disabled={loading || !!success}
          className={authInputClassName}
        />
      </div>

      <div>
        <label htmlFor="signup-password" className={authLabelClassName}>
          Mật khẩu
        </label>
        <input
          id="signup-password"
          type="password"
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="Ít nhất 6 ký tự"
          disabled={loading || !!success}
          className={authInputClassName}
        />
      </div>

      <div>
        <label htmlFor="signup-confirm-password" className={authLabelClassName}>
          Xác nhận mật khẩu
        </label>
        <input
          id="signup-confirm-password"
          type="password"
          autoComplete="new-password"
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          placeholder="Nhập lại mật khẩu"
          disabled={loading || !!success}
          className={authInputClassName}
        />
      </div>

      {error && (
        <p className="text-sm text-red-400" role="alert">
          {error}
        </p>
      )}

      {success && (
        <p className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 px-5 py-4 text-center text-sm text-emerald-200">
          {success}
        </p>
      )}

      <button
        type="submit"
        disabled={loading || !!success}
        className={authButtonClassName}
      >
        {loading ? "Đang đăng ký..." : "Đăng ký"}
      </button>

      <p className="text-center text-sm text-zinc-500">
        Đã có tài khoản?{" "}
        <Link
          href="/login"
          className="font-medium text-violet-400 transition hover:text-violet-300"
        >
          Đăng nhập
        </Link>
      </p>
    </form>
  );
}
