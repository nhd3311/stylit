"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import { authButtonClassName, authLabelClassName } from "@/components/auth-shell";
import { PasswordInput } from "@/components/password-input";
import { validatePassword } from "@/lib/auth-validation";
import { createClient } from "@/lib/supabase-client";

export function ResetPasswordForm() {
  const t = useTranslations("auth");
  const tv = useTranslations("validation");
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);

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
    const { error: updateError } = await supabase.auth.updateUser({ password });
    setLoading(false);

    if (updateError) {
      setError(tv("generic"));
      return;
    }

    setDone(true);
    router.push("/dashboard");
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5">
      <div>
        <label htmlFor="new-password" className={authLabelClassName}>
          {t("newPassword")}
        </label>
        <PasswordInput
          id="new-password"
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder={t("newPasswordPlaceholder")}
          disabled={loading || done}
        />
      </div>

      <div>
        <label htmlFor="confirm-new-password" className={authLabelClassName}>
          {t("confirmPassword")}
        </label>
        <PasswordInput
          id="confirm-new-password"
          autoComplete="new-password"
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          placeholder={t("confirmPlaceholder")}
          disabled={loading || done}
        />
      </div>

      {error && (
        <p className="text-sm text-red-400" role="alert">
          {error}
        </p>
      )}

      {done && (
        <p className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 px-5 py-4 text-center text-sm text-emerald-200">
          {t("passwordUpdated")}
        </p>
      )}

      <button
        type="submit"
        disabled={loading || done}
        className={authButtonClassName}
      >
        {loading ? t("updating") : t("updatePassword")}
      </button>
    </form>
  );
}
