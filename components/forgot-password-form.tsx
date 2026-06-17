"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import { FormEvent, useState } from "react";
import {
  authButtonClassName,
  authInputClassName,
  authLabelClassName,
} from "@/components/auth-shell";
import { validateEmail } from "@/lib/auth-validation";
import { createClient } from "@/lib/supabase-client";

export function ForgotPasswordForm() {
  const t = useTranslations("auth");
  const tv = useTranslations("validation");
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);

    const emailError = validateEmail(email);
    if (emailError) {
      setError(tv(emailError));
      return;
    }

    setLoading(true);
    const supabase = createClient();
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      {
        redirectTo: `${window.location.origin}/auth/confirm?next=/reset-password`,
      },
    );
    setLoading(false);

    if (resetError) {
      setError(tv("generic"));
      return;
    }
    setSent(true);
  }

  if (sent) {
    return (
      <div className="flex flex-col gap-5">
        <p className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 px-5 py-4 text-center text-sm text-emerald-200">
          {t("resetEmailSent")}
        </p>
        <p className="text-center text-sm text-muted-foreground">
          <Link
            href="/login"
            className="font-medium text-violet-400 transition hover:text-violet-300"
          >
            {t("backToLogin")}
          </Link>
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5">
      <div>
        <label htmlFor="forgot-email" className={authLabelClassName}>
          {t("email")}
        </label>
        <input
          id="forgot-email"
          type="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder={t("emailPlaceholder")}
          disabled={loading}
          className={authInputClassName}
        />
      </div>

      {error && (
        <p className="text-sm text-red-400" role="alert">
          {error}
        </p>
      )}

      <button type="submit" disabled={loading} className={authButtonClassName}>
        {loading ? t("sending") : t("sendResetLink")}
      </button>

      <p className="text-center text-sm text-muted-foreground">
        <Link
          href="/login"
          className="font-medium text-violet-400 transition hover:text-violet-300"
        >
          {t("backToLogin")}
        </Link>
      </p>
    </form>
  );
}
