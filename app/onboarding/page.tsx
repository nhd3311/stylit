import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { OnboardingWizard } from "@/components/onboarding-wizard";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "Set up your profile — Fitcheck",
  description: "Set up your Fitcheck style profile",
};

export default async function OnboardingPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("onboarded")
    .eq("user_id", user.id)
    .maybeSingle();

  if (profile?.onboarded) {
    redirect("/dashboard");
  }

  return (
    <div className="flex min-h-full flex-1 flex-col bg-background text-foreground">
      <main className="mx-auto flex w-full max-w-xl flex-1 flex-col px-6 py-10 sm:px-8">
        <OnboardingWizard userId={user.id} />
      </main>
    </div>
  );
}
