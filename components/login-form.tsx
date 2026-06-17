"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import {
  authButtonClassName,
  authInputClassName,
  authLabelClassName,
} from "@/components/auth-shell";
import { PasswordInput } from "@/components/password-input";
import {
  getAuthErrorKey,
  validateEmail,
  validatePassword,
} from "@/lib/auth-validation";
import { createClient } from "@/lib/supabase-client";

export function LoginForm() {
  const t = useTranslations("auth");
  const tv = useTranslations("validation");
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    const emailError = validateEmail(email);
    if (emailError) {
      setError(tv(emailError));
      return;
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      setError(tv(passwordError));
      return;
    }

    setLoading(true);

    const supabase = createClient();
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: email.trim().toLowerCase(),
      password,
    });

    setLoading(false);

    if (signInError) {
      setError(tv(getAuthErrorKey(signInError.message)));
      return;
    }

    setSuccess(t("loginSuccess"));
    router.push("/dashboard");
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5">
      <div>
        <label htmlFor="login-email" className={authLabelClassName}>
          {t("email")}
        </label>
        <input
          id="login-email"
          type="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder={t("emailPlaceholder")}
          disabled={loading}
          className={authInputClassName}
        />
      </div>

      <div>
        <div className="mb-2 flex items-center justify-between">
          <label htmlFor="login-password" className="text-sm font-medium text-foreground">
            {t("password")}
          </label>
          <Link
            href="/forgot-password"
            className="text-sm font-medium text-violet-400 transition hover:text-violet-300"
          >
            {t("forgotPassword")}
          </Link>
        </div>
        <PasswordInput
          id="login-password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder={t("passwordPlaceholder")}
          disabled={loading}
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

      <button type="submit" disabled={loading} className={authButtonClassName}>
        {loading ? t("loggingIn") : t("logIn")}
      </button>

      <p className="text-center text-sm text-muted-foreground">
        {t("noAccount")}{" "}
        <Link
          href="/signup"
          className="font-medium text-violet-400 transition hover:text-violet-300"
        >
          {t("signUp")}
        </Link>
      </p>
    </form>
  );
}
