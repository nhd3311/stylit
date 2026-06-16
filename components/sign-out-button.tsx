"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { authButtonClassName } from "@/components/auth-shell";
import { createClient } from "@/lib/supabase-client";

export function SignOutButton() {
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
      className={`${authButtonClassName} max-w-xs`}
    >
      {loading ? "Signing out..." : "Sign out"}
    </button>
  );
}
