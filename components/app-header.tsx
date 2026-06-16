import Link from "next/link";
import { SignOutButton } from "@/components/sign-out-button";

export function AppHeader({ email }: { email?: string | null }) {
  return (
    <header className="sticky top-0 z-30 border-b border-white/5 bg-zinc-950/70 backdrop-blur">
      <div className="mx-auto flex w-full max-w-6xl items-center justify-between px-6 py-4 sm:px-8">
        <Link
          href="/dashboard"
          className="bg-linear-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-lg font-bold tracking-tight text-transparent"
        >
          Fitcheck
        </Link>
        <div className="flex items-center gap-3">
          {email ? (
            <span className="hidden text-sm text-zinc-400 sm:inline">
              {email}
            </span>
          ) : null}
          <SignOutButton className="rounded-lg border border-zinc-800 bg-zinc-900/60 px-4 py-2 text-sm font-medium text-zinc-200 transition hover:border-zinc-700 hover:text-white disabled:opacity-60" />
        </div>
      </div>
    </header>
  );
}
