"use client";

import { useLocale } from "next-intl";
import { useRouter } from "next/navigation";
import { useTransition } from "react";

const OPTIONS = [
  { value: "en", label: "English" },
  { value: "vi", label: "Tiếng Việt" },
];

function persistLocale(value: string) {
  document.cookie = `locale=${value};path=/;max-age=31536000`;
}

export function LanguageSetting() {
  const locale = useLocale();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function choose(value: string) {
    persistLocale(value);
    startTransition(() => router.refresh());
  }

  return (
    <div className="inline-flex rounded-xl border border-border bg-card p-1">
      {OPTIONS.map((option) => (
        <button
          key={option.value}
          type="button"
          disabled={pending}
          onClick={() => choose(option.value)}
          className={
            locale === option.value
              ? "rounded-lg bg-muted px-4 py-2 text-sm font-medium text-foreground"
              : "rounded-lg px-4 py-2 text-sm text-muted-foreground transition hover:text-foreground disabled:opacity-50"
          }
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}
