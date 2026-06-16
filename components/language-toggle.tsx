"use client";

import { useLocale } from "next-intl";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

const LOCALES = [
  { value: "en", label: "English", short: "EN" },
  { value: "vi", label: "Tiếng Việt", short: "VI" },
] as const;

function persistLocale(value: string) {
  document.cookie = `locale=${value};path=/;max-age=31536000`;
}

export function LanguageToggle() {
  const locale = useLocale();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, startTransition] = useTransition();

  function choose(value: string) {
    persistLocale(value);
    setOpen(false);
    startTransition(() => router.refresh());
  }

  const current = LOCALES.find((item) => item.value === locale) ?? LOCALES[0];

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        aria-label="Change language"
        className="flex h-9 items-center gap-1.5 rounded-lg border border-border bg-card px-2.5 text-sm font-medium text-muted-foreground transition hover:text-foreground"
      >
        <GlobeIcon />
        {current.short}
      </button>

      {open && (
        <>
          <button
            type="button"
            aria-hidden
            tabIndex={-1}
            onClick={() => setOpen(false)}
            className="fixed inset-0 z-40 cursor-default"
          />
          <div className="absolute right-0 z-50 mt-2 w-40 overflow-hidden rounded-xl border border-border bg-card p-1 shadow-lg">
            {LOCALES.map((item) => (
              <button
                key={item.value}
                type="button"
                disabled={pending}
                onClick={() => choose(item.value)}
                className={
                  locale === item.value
                    ? "flex w-full items-center rounded-lg bg-muted px-3 py-2 text-sm font-medium text-foreground"
                    : "flex w-full items-center rounded-lg px-3 py-2 text-sm text-muted-foreground transition hover:bg-muted hover:text-foreground disabled:opacity-50"
                }
              >
                {item.label}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function GlobeIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.7}
      strokeLinecap="round"
      strokeLinejoin="round"
      className="h-4 w-4"
      aria-hidden
    >
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18" />
    </svg>
  );
}
