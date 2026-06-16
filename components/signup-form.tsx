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

export function SignupForm() {
  const t = useTranslations("auth");
  const tv = useTranslations("validation");
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
      setError(tv(emailError));
      return;
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      setError(tv(passwordError));
      return;
    }

    if (password !== confirmPassword) {
      setError(t("passwordsNoMatch"));
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
      setError(tv(getAuthErrorKey(signUpError.message)));
      return;
    }

    if (data.session) {
      setSuccess(t("accountCreated"));
      router.push("/dashboard");
      router.refresh();
      return;
    }

    setSuccess(t("accountCreatedConfirm"));
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5">
      <div>
        <label htmlFor="signup-email" className={authLabelClassName}>
          {t("email")}
        </label>
        <input
          id="signup-email"
          type="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder={t("emailPlaceholder")}
          disabled={loading || !!success}
          className={authInputClassName}
        />
      </div>

      <div>
        <label htmlFor="signup-password" className={authLabelClassName}>
          {t("password")}
        </label>
        <PasswordInput
          id="signup-password"
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder={t("newPasswordPlaceholder")}
          disabled={loading || !!success}
        />
      </div>

      <div>
        <label htmlFor="signup-confirm-password" className={authLabelClassName}>
          {t("confirmPassword")}
        </label>
        <PasswordInput
          id="signup-confirm-password"
          autoComplete="new-password"
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          placeholder={t("confirmPlaceholder")}
          disabled={loading || !!success}
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
        {loading ? t("creatingAccount") : t("signUp")}
      </button>

      <p className="text-center text-sm text-muted-foreground">
        {t("haveAccount")}{" "}
        <Link
          href="/login"
          className="font-medium text-violet-400 transition hover:text-violet-300"
        >
          {t("logIn")}
        </Link>
      </p>
    </form>
  );
}
