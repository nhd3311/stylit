"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { authButtonClassName } from "@/components/auth-shell";
import { createClient } from "@/lib/supabase-client";

export function SignOutButton({ className }: { className?: string }) {
  const t = useTranslations("header");
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function handleSignOut() {
    setLoading(true);

    const supabase = createClient();
    await supabase.auth.signOut();

    router.push("/login");
    router.refresh();
  }

  return (
    <button
      type="button"
      onClick={handleSignOut}
      disabled={loading}
      className={className ?? `${authButtonClassName} max-w-xs`}
    >
      {loading ? t("signingOut") : t("signOut")}
    </button>
  );
}
