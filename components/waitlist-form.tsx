"use client";

import { useTranslations } from "next-intl";
import { FormEvent, useState } from "react";
import { supabase } from "@/lib/supabase";

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

export function WaitlistForm() {
  const t = useTranslations("waitlist");
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);

    const trimmed = email.trim();
    if (!isValidEmail(trimmed)) {
      setError(t("invalidEmail"));
      return;
    }

    setLoading(true);

    const { error: insertError } = await supabase
      .from("waitlist")
      .insert({ email: trimmed.toLowerCase() });

    setLoading(false);

    if (insertError) {
      setError(insertError.code === "23505" ? t("alreadyOnList") : t("genericError"));
      return;
    }

    setSuccess(true);
  }

  if (success) {
    return (
      <p className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 px-5 py-4 text-center text-sm text-emerald-200 sm:text-base">
        {t("success")}
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <form onSubmit={handleSubmit} className="flex flex-col gap-3 sm:flex-row">
        <label htmlFor="email" className="sr-only">
          Email
        </label>
        <input
          id="email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder={t("placeholder")}
          disabled={loading}
          className="h-12 flex-1 rounded-xl border border-border bg-input px-4 text-base text-foreground placeholder:text-muted-foreground outline-none transition focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20 disabled:cursor-not-allowed disabled:opacity-60"
        />
        <button
          type="submit"
          disabled={loading}
          className="h-12 shrink-0 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 px-6 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-60 sm:text-base"
        >
          {loading ? t("sending") : t("submit")}
        </button>
      </form>
      {error && (
        <p className="text-sm text-red-400" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
