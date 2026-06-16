"use client";

import { FormEvent, useState } from "react";
import { supabase } from "@/lib/supabase";

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

export function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);

    const trimmed = email.trim();
    if (!isValidEmail(trimmed)) {
      setError("Please enter a valid email (with @ and a domain).");
      return;
    }

    setLoading(true);

    const { error: insertError } = await supabase
      .from("waitlist")
      .insert({ email: trimmed.toLowerCase() });

    setLoading(false);

    if (insertError) {
      if (insertError.code === "23505") {
        setError("This email is already on the list.");
      } else {
        setError("Couldn't sign you up right now. Please try again later.");
      }
      return;
    }

    setSuccess(true);
  }

  if (success) {
    return (
      <p className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 px-5 py-4 text-center text-sm text-emerald-200 sm:text-base">
        {"You're on the list!"}
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
          placeholder="Your email"
          disabled={loading}
          className="h-12 flex-1 rounded-xl border border-zinc-800 bg-zinc-900/80 px-4 text-base text-white placeholder:text-zinc-500 outline-none transition focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20 disabled:cursor-not-allowed disabled:opacity-60"
        />
        <button
          type="submit"
          disabled={loading}
          className="h-12 shrink-0 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 px-6 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-60 sm:text-base"
        >
          {loading ? "Sending..." : "Get early access"}
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
