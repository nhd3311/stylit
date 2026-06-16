import Link from "next/link";
import type { ReactNode } from "react";

type AuthShellProps = {
  title: string;
  subtitle?: string;
  children: ReactNode;
  footer?: ReactNode;
};

export function AuthShell({ title, subtitle, children, footer }: AuthShellProps) {
  return (
    <div className="relative flex min-h-full flex-1 flex-col overflow-hidden bg-zinc-950 text-white">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_-20%,rgba(168,85,247,0.25),transparent)]"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -right-32 top-1/3 h-64 w-64 rounded-full bg-fuchsia-500/10 blur-3xl sm:h-96 sm:w-96"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -left-32 bottom-1/4 h-64 w-64 rounded-full bg-violet-500/10 blur-3xl sm:h-96 sm:w-96"
      />

      <main className="relative z-10 mx-auto flex w-full max-w-md flex-1 flex-col justify-center px-6 py-16 sm:px-8 sm:py-24">
        <Link
          href="/"
          className="mb-8 text-sm font-medium text-violet-400 transition hover:text-violet-300"
        >
          ← Fitcheck
        </Link>

        <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">{title}</h1>
        {subtitle && (
          <p className="mt-2 text-sm text-zinc-400 sm:text-base">{subtitle}</p>
        )}

        <div className="mt-8">{children}</div>

        {footer && <div className="mt-6 text-center text-sm text-zinc-500">{footer}</div>}
      </main>
    </div>
  );
}

export const authInputClassName =
  "h-12 w-full rounded-xl border border-zinc-800 bg-zinc-900/80 px-4 text-base text-white placeholder:text-zinc-500 outline-none transition focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20 disabled:cursor-not-allowed disabled:opacity-60";

export const authButtonClassName =
  "h-12 w-full rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 px-6 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-60 sm:text-base";

export const authLabelClassName = "mb-2 block text-sm font-medium text-zinc-300";
