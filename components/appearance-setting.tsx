"use client";

import { useTranslations } from "next-intl";
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";

export function AppearanceSetting() {
  const t = useTranslations("settings");
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  // Mounted guard prevents a hydration mismatch with next-themes.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => setMounted(true), []);

  const current = mounted ? (theme ?? "system") : "system";

  const options = [
    { value: "light", label: t("themeLight") },
    { value: "dark", label: t("themeDark") },
    { value: "system", label: t("themeSystem") },
  ];

  return (
    <div className="inline-flex rounded-xl border border-border bg-card p-1">
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          onClick={() => setTheme(option.value)}
          className={
            current === option.value
              ? "rounded-lg bg-muted px-4 py-2 text-sm font-medium text-foreground"
              : "rounded-lg px-4 py-2 text-sm text-muted-foreground transition hover:text-foreground"
          }
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}
