"use client";

import { useTranslations } from "next-intl";
import { FormEvent, useState } from "react";
import {
  authButtonClassName,
  authLabelClassName,
} from "@/components/auth-shell";
import { PasswordInput } from "@/components/password-input";
import { validatePassword } from "@/lib/auth-validation";
import { createClient } from "@/lib/supabase-client";

export function ChangePasswordForm() {
  const t = useTranslations("settings");
  const ta = useTranslations("auth");
  const tv = useTranslations("validation");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setDone(false);

    const passwordError = validatePassword(password);
    if (passwordError) {
      setError(tv(passwordError));
      return;
    }
    if (password !== confirmPassword) {
      setError(ta("passwordsNoMatch"));
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

    setPassword("");
    setConfirmPassword("");
    setDone(true);
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div>
        <label htmlFor="settings-new-password" className={authLabelClassName}>
          {t("newPassword")}
        </label>
        <PasswordInput
          id="settings-new-password"
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder={ta("newPasswordPlaceholder")}
          disabled={loading}
        />
      </div>

      <div>
        <label htmlFor="settings-confirm-password" className={authLabelClassName}>
          {t("confirmNewPassword")}
        </label>
        <PasswordInput
          id="settings-confirm-password"
          autoComplete="new-password"
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          placeholder={ta("confirmPlaceholder")}
          disabled={loading}
        />
      </div>

      {error && (
        <p className="text-sm text-red-400" role="alert">
          {error}
        </p>
      )}
      {done && <p className="text-sm text-emerald-400">{t("passwordUpdated")}</p>}

      <button
        type="submit"
        disabled={loading}
        className={`${authButtonClassName} sm:max-w-xs`}
      >
        {loading ? t("updating") : t("updatePassword")}
      </button>
    </form>
  );
}
