"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import { useMemo, useState } from "react";
import type { SuggestedOutfit } from "@/lib/outfit";
import { OCCASIONS } from "@/lib/profile";
import { type WardrobeItem } from "@/lib/wardrobe";

function chipClass(active: boolean): string {
  return active
    ? "rounded-full border border-violet-500 bg-violet-500/15 px-4 py-2 text-sm font-medium text-foreground"
    : "rounded-full border border-border bg-card px-4 py-2 text-sm font-medium text-muted-foreground transition hover:text-foreground";
}

export function OutfitFlow({ items }: { items: WardrobeItem[] }) {
  const t = useTranslations("outfit");
  const tc = useTranslations("categories");
  const to = useTranslations("profileOptions");

  const itemMap = useMemo(() => {
    const map = new Map<string, WardrobeItem>();
    for (const it of items) {
      map.set(it.id, it);
    }
    return map;
  }, [items]);

  const [occasion, setOccasion] = useState<string | null>(null);
  const [note, setNote] = useState("");
  const [loading, setLoading] = useState(false);
  const [outfits, setOutfits] = useState<SuggestedOutfit[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function suggest() {
    setLoading(true);
    setError(null);
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);
    try {
      const res = await fetch("/api/outfit", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ occasion, note: note.trim() }),
        signal: controller.signal,
      });
      if (!res.ok) {
        const info = (await res.json().catch(() => null)) as {
          error?: string;
        } | null;
        throw new Error(info?.error ?? "suggest failed");
      }
      const data = (await res.json()) as { outfits: SuggestedOutfit[] };
      setOutfits(data.outfits ?? []);
    } catch (err) {
      const message = err instanceof Error ? err.message : "";
      setError(
        message && message !== "suggest failed"
          ? `${t("error")} — ${message}`
          : t("error"),
      );
    } finally {
      clearTimeout(timeout);
      setLoading(false);
    }
  }

  if (items.length < 2) {
    return (
      <div className="rounded-2xl border border-dashed border-border py-16 text-center">
        <p className="text-sm text-muted-foreground">{t("needItems")}</p>
        <div className="mt-4 flex justify-center gap-4">
          <Link
            href="/detect"
            className="text-sm font-medium text-violet-400 transition hover:text-violet-300"
          >
            {t("goScan")}
          </Link>
          <Link
            href="/dashboard"
            className="text-sm font-medium text-violet-400 transition hover:text-violet-300"
          >
            {t("goWardrobe")}
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <p className="mb-2 text-sm font-medium">{t("occasionLabel")}</p>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => setOccasion(null)}
            className={chipClass(occasion === null)}
          >
            {t("anyOccasion")}
          </button>
          {OCCASIONS.map((o) => (
            <button
              key={o.value}
              type="button"
              onClick={() => setOccasion(o.value)}
              className={chipClass(occasion === o.value)}
            >
              {to(o.labelKey)}
            </button>
          ))}
        </div>
      </div>

      <div>
        <label htmlFor="outfit-note" className="mb-2 block text-sm font-medium">
          {t("noteLabel")}
        </label>
        <input
          id="outfit-note"
          type="text"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          maxLength={200}
          placeholder={t("notePlaceholder")}
          className="h-11 w-full rounded-xl border border-border bg-input px-4 text-sm text-foreground placeholder:text-muted-foreground outline-none transition focus:border-violet-500"
        />
      </div>

      <button
        type="button"
        onClick={suggest}
        disabled={loading}
        className="flex h-12 items-center justify-center gap-2 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {loading
          ? t("suggesting")
          : outfits
            ? t("regenerate")
            : t("suggest")}
      </button>

      {error && (
        <p className="text-sm text-red-400" role="alert">
          {error}
        </p>
      )}

      {loading && (
        <div className="flex flex-col items-center justify-center gap-4 rounded-2xl border border-border bg-card py-16">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-violet-500 border-t-transparent" />
          <p className="text-sm text-muted-foreground">{t("suggesting")}</p>
        </div>
      )}

      {!loading && outfits && outfits.length === 0 && (
        <div className="rounded-2xl border border-dashed border-border py-16 text-center text-sm text-muted-foreground">
          {t("noResults")}
        </div>
      )}

      {!loading && outfits && outfits.length > 0 && (
        <div className="flex flex-col gap-5">
          {outfits.map((outfit, index) => {
            const outfitItems = outfit.itemIds
              .map((id) => itemMap.get(id))
              .filter((x): x is WardrobeItem => Boolean(x));
            return (
              <div
                key={index}
                className="rounded-2xl border border-border bg-card p-5"
              >
                <h3 className="text-lg font-semibold">{outfit.title}</h3>
                {outfit.reason && (
                  <p className="mt-1 text-sm text-muted-foreground">
                    {outfit.reason}
                  </p>
                )}
                <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
                  {outfitItems.map((it) => (
                    <div key={it.id} className="flex flex-col gap-2">
                      <div className="aspect-square w-full overflow-hidden rounded-xl border border-border bg-muted">
                        {it.imageUrl ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={it.imageUrl}
                            alt={it.name}
                            className="h-full w-full object-cover"
                          />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center text-muted-foreground">
                            <ShirtIcon />
                          </div>
                        )}
                      </div>
                      <div>
                        <p className="truncate text-xs font-medium text-foreground">
                          {it.name}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {tc(it.category)}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function ShirtIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.4}
      strokeLinecap="round"
      strokeLinejoin="round"
      className="h-8 w-8"
      aria-hidden
    >
      <path d="M8 3l4 3 4-3 5 4-3 3-2-1v9H8v-9l-2 1-3-3 5-4z" />
    </svg>
  );
}
