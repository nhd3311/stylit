import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { AuthShell } from "@/components/auth-shell";
import { SignOutButton } from "@/components/sign-out-button";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "Dashboard — Fitcheck",
  description: "Your Fitcheck dashboard",
};

export default async function DashboardPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  return (
    <AuthShell title="Dashboard">
      <div className="flex flex-col gap-6">
        <p className="text-lg text-zinc-300 sm:text-xl">
          Hi, <span className="font-semibold text-white">{user.email}</span>
        </p>
        <SignOutButton />
      </div>
    </AuthShell>
  );
}
