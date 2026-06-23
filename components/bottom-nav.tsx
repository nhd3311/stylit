"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import { usePathname } from "next/navigation";

const TABS = [
  { href: "/dashboard", key: "wardrobe" },
  { href: "/outfit", key: "outfit" },
  { href: "/stylist", key: "stylist" },
  { href: "/profile", key: "profile" },
] as const;

export function BottomNav() {
  const pathname = usePathname();
  const t = useTranslations("tabs");

  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-border bg-card/90 backdrop-blur">
      <div
        className="mx-auto flex max-w-xl items-stretch justify-around px-2"
        style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
      >
        {TABS.map((tab) => {
          const active =
            pathname === tab.href || pathname.startsWith(`${tab.href}/`);
          const cls = active ? "text-primary" : "text-muted-foreground";
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`flex flex-1 flex-col items-center gap-1 py-2.5 text-[11px] font-medium transition ${cls}`}
            >
              <TabIcon name={tab.key} active={active} />
              <span>{t(tab.key)}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

function TabIcon({ name, active }: { name: string; active: boolean }) {
  const cls = "h-6 w-6";
  const sw = active ? 2.1 : 1.7;
  const common = {
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: sw,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    className: cls,
    "aria-hidden": true,
  };
  if (name === "wardrobe") {
    return (
      <svg {...common}>
        <path d="M8 3l4 3 4-3 5 4-3 3-2-1v9H8v-9l-2 1-3-3 5-4z" />
      </svg>
    );
  }
  if (name === "outfit") {
    return (
      <svg {...common}>
        <path d="M5 3v4M3 5h4M6 17v4M4 19h4M13 3l3 7 5 2-5 2-3 7-3-7-5-2 5-2 3-7z" />
      </svg>
    );
  }
  if (name === "stylist") {
    return (
      <svg {...common}>
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
      </svg>
    );
  }
  return (
    <svg {...common}>
      <path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0" />
    </svg>
  );
}
