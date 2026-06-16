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

export function LoginForm() {
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
      setError(emailError);
      return;
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      setError(passwordError);
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
      setError(getAuthErrorMessage(signInError.message));
      return;
    }

    setSuccess("Logged in successfully!");
    router.push("/dashboard");
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5">
      <div>
        <label htmlFor="login-email" className={authLabelClassName}>
          Email
        </label>
        <input
          id="login-email"
          type="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@email.com"
          disabled={loading}
          className={authInputClassName}
        />
      </div>

      <div>
        <label htmlFor="login-password" className={authLabelClassName}>
          Password
        </label>
        <input
          id="login-password"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="••••••••"
          disabled={loading}
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

      <button type="submit" disabled={loading} className={authButtonClassName}>
        {loading ? "Logging in..." : "Log in"}
      </button>

      <p className="text-center text-sm text-zinc-500">
        No account yet?{" "}
        <Link
          href="/signup"
          className="font-medium text-violet-400 transition hover:text-violet-300"
        >
          Sign up
        </Link>
      </p>
    </form>
  );
}
