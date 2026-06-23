"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { createClient } from "@/lib/supabase-client";
import {
  CATEGORIES,
  WARDROBE_BUCKET,
  type Category,
  type WardrobeItem,
} from "@/lib/wardrobe";

const FILTERS: (Category | "All")[] = ["All", ...CATEGORIES];

export function Wardrobe({
  initialItems,
  needsSetup,
}: {
  initialItems: WardrobeItem[];
  needsSetup: boolean;
}) {
  const t = useTranslations("wardrobe");
  const tc = useTranslations("categories");
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const [items, setItems] = useState<WardrobeItem[]>(initialItems);
  const [filter, setFilter] = useState<Category | "All">("All");
  const [query, setQuery] = useState("");
  const [byName, setByName] = useState(false);

  const counts = useMemo(() => {
    const map: Record<string, number> = { All: items.length };
    for (const c of CATEGORIES) {
      map[c] = 0;
    }
    for (const item of items) {
      map[item.category] = (map[item.category] ?? 0) + 1;
    }
    return map;
  }, [items]);

  const visibleItems = useMemo(() => {
    let list =
      filter === "All" ? items : items.filter((i) => i.category === filter);
    const q = query.trim().toLowerCase();
    if (q) {
      list = list.filter((i) => i.name.toLowerCase().includes(q));
    }
    if (byName) {
      list = [...list].sort((a, b) => a.name.localeCompare(b.name));
    }
    return list;
  }, [items, filter, query, byName]);

  async function handleDelete(item: WardrobeItem) {
    setItems((prev) => prev.filter((entry) => entry.id !== item.id));
    if (item.imagePath) {
      await supabase.storage.from(WARDROBE_BUCKET).remove([item.imagePath]);
    }
    await supabase.from("wardrobe_items").delete().eq("id", item.id);
  }

  return (
    <div className="flex flex-col gap-5">
      {needsSetup && (
        <div className="rounded-2xl border border-amber-500/30 bg-amber-500/10 p-4 text-sm text-amber-700 dark:text-amber-200">
          {t("setupNeeded")}
        </div>
      )}

      <div>
        <h1 className="text-2xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">
          {t("itemCount", { count: items.length })}
        </p>
      </div>

      <div className="no-scrollbar -mx-5 flex gap-2 overflow-x-auto px-5">
        {FILTERS.map((cat) => {
          const active = filter === cat;
          return (
            <button
              key={cat}
              type="button"
              onClick={() => setFilter(cat)}
              className={
                active
                  ? "flex min-w-[64px] shrink-0 flex-col items-center gap-0.5 rounded-2xl border border-primary bg-primary/10 px-3 py-2"
                  : "flex min-w-[64px] shrink-0 flex-col items-center gap-0.5 rounded-2xl border border-border bg-card px-3 py-2 transition hover:border-primary/40"
              }
            >
              <span
                className={
                  active
                    ? "text-lg font-bold text-primary"
                    : "text-lg font-bold text-foreground"
                }
              >
                {counts[cat] ?? 0}
              </span>
              <span className="text-[11px] font-medium text-muted-foreground">
                {tc(cat)}
              </span>
            </button>
          );
        })}
      </div>

      <div className="flex items-center gap-2">
        <div className="relative flex-1">
          <SearchIcon />
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t("searchPlaceholder")}
            className="h-11 w-full rounded-xl border border-border bg-input pl-10 pr-3 text-sm text-foreground placeholder:text-muted-foreground outline-none transition focus:border-primary"
          />
        </div>
        <button
          type="button"
          onClick={() => setByName((v) => !v)}
          aria-label="Sort"
          className={
            byName
              ? "flex h-11 w-11 items-center justify-center rounded-xl border border-primary bg-primary/10 text-primary"
              : "flex h-11 w-11 items-center justify-center rounded-xl border border-border bg-card text-muted-foreground transition hover:text-foreground"
          }
        >
          <SortIcon />
        </button>
      </div>

      {visibleItems.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-border py-20 text-center">
          <p className="text-muted-foreground">{t("empty")}</p>
          <button
            type="button"
            onClick={() => router.push("/detect")}
            className="mt-4 text-sm font-medium text-primary transition hover:opacity-80"
          >
            {t("addFirst")}
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {visibleItems.map((item) => (
            <WardrobeCard key={item.id} item={item} onDelete={handleDelete} />
          ))}
        </div>
      )}

      <div
        className="fixed inset-x-0 z-30 px-5"
        style={{ bottom: "calc(env(safe-area-inset-bottom) + 64px)" }}
      >
        <button
          type="button"
          onClick={() => router.push("/detect")}
          className="fc-gradient mx-auto flex h-12 w-full max-w-xl items-center justify-center gap-2 rounded-2xl text-sm font-semibold text-white shadow-lg shadow-violet-500/20 transition active:scale-[0.99]"
        >
          <PlusIcon />
          {t("addItem")}
        </button>
      </div>
    </div>
  );
}

function WardrobeCard({
  item,
  onDelete,
}: {
  item: WardrobeItem;
  onDelete: (item: WardrobeItem) => void;
}) {
  const t = useTranslations("wardrobe");
  const tc = useTranslations("categories");

  return (
    <div className="group relative overflow-hidden rounded-2xl border border-border bg-card">
      <div className="aspect-square w-full bg-muted">
        {item.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={item.imageUrl}
            alt={item.name}
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center text-muted-foreground">
            <ShirtIcon />
          </div>
        )}
      </div>
      <button
        type="button"
        onClick={() => onDelete(item)}
        aria-label={t("delete", { name: item.name })}
        className="absolute right-2 top-2 flex h-7 w-7 items-center justify-center rounded-full bg-zinc-950/55 text-white opacity-80 backdrop-blur transition hover:bg-red-500/80"
      >
        ✕
      </button>
      <div className="p-2.5">
        <p className="truncate text-sm font-medium text-foreground">
          {item.name}
        </p>
        <p className="mt-0.5 text-xs text-muted-foreground">
          {tc(item.category)}
        </p>
      </div>
    </div>
  );
}

function SearchIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
      aria-hidden="true"
    >
      <circle cx="11" cy="11" r="7" />
      <path d="M21 21l-4.3-4.3" />
    </svg>
  );
}

function SortIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5" aria-hidden="true">
      <path d="M4 6h10M4 12h7M4 18h4M17 5v14M17 19l3-3M17 19l-3-3" />
    </svg>
  );
}

function PlusIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5" aria-hidden="true">
      <path d="M12 5v14M5 12h14" />
    </svg>
  );
}

function ShirtIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.4} strokeLinecap="round" strokeLinejoin="round" className="h-10 w-10" aria-hidden="true">
      <path d="M8 3l4 3 4-3 5 4-3 3-2-1v9H8v-9l-2 1-3-3 5-4z" />
    </svg>
  );
}
