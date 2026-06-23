"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import { useMemo, useState } from "react";
import type { SavedLook, SuggestedOutfit } from "@/lib/outfit";
import { OCCASIONS } from "@/lib/profile";
import { createClient } from "@/lib/supabase-client";
import { type WardrobeItem } from "@/lib/wardrobe";

function chipClass(active: boolean): string {
  return active
    ? "rounded-full border border-primary bg-primary/15 px-4 py-2 text-sm font-medium text-foreground"
    : "rounded-full border border-border bg-card px-4 py-2 text-sm font-medium text-muted-foreground transition hover:text-foreground";
}

export function OutfitFlow({
  items,
  userId,
  initialLooks,
}: {
  items: WardrobeItem[];
  userId: string;
  initialLooks: SavedLook[];
}) {
  const t = useTranslations("outfit");
  const tc = useTranslations("categories");
  const to = useTranslations("profileOptions");
  const supabase = useMemo(() => createClient(), []);

  const itemMap = useMemo(() => {
    const map = new Map<string, WardrobeItem>();
    for (const it of items) {
      map.set(it.id, it);
    }
    return map;
  }, [items]);

  const [looks, setLooks] = useState<SavedLook[]>(initialLooks);
  const [occasion, setOccasion] = useState<string | null>(null);
  const [note, setNote] = useState("");
  const [loading, setLoading] = useState(false);
  const [outfits, setOutfits] = useState<SuggestedOutfit[] | null>(null);
  const [savedKeys, setSavedKeys] = useState<Set<number>>(new Set());
  const [error, setError] = useState<string | null>(null);

  async function suggest() {
    setLoading(true);
    setError(null);
    setSavedKeys(new Set());
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

  async function saveLook(outfit: SuggestedOutfit, index: number) {
    const { data, error: saveError } = await supabase
      .from("saved_looks")
      .insert({
        user_id: userId,
        title: outfit.title,
        reason: outfit.reason,
        item_ids: outfit.itemIds,
        occasion,
      })
      .select("id")
      .single();
    if (saveError || !data) {
      return;
    }
    setLooks((prev) => [
      {
        id: data.id as string,
        title: outfit.title,
        reason: outfit.reason,
        itemIds: outfit.itemIds,
      },
      ...prev,
    ]);
    setSavedKeys((prev) => {
      const next = new Set(prev);
      next.add(index);
      return next;
    });
  }

  async function deleteLook(id: string) {
    setLooks((prev) => prev.filter((l) => l.id !== id));
    await supabase.from("saved_looks").delete().eq("id", id);
  }

  function Thumbs({ itemIds }: { itemIds: string[] }) {
    const outfitItems = itemIds
      .map((id) => itemMap.get(id))
      .filter((x): x is WardrobeItem => Boolean(x));
    return (
      <div className="mt-3 grid grid-cols-4 gap-2">
        {outfitItems.map((it) => (
          <div key={it.id} className="flex flex-col gap-1">
            <div className="aspect-square w-full overflow-hidden rounded-xl border border-border bg-white">
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
            <p className="truncate text-[11px] text-muted-foreground">
              {tc(it.category)}
            </p>
          </div>
        ))}
      </div>
    );
  }

  const canGenerate = items.length >= 2;

  return (
    <div className="flex flex-col gap-7">
      {looks.length > 0 && (
        <section>
          <p className="mb-3 text-sm font-semibold">{t("savedTitle")}</p>
          <div className="flex flex-col gap-4">
            {looks.map((look) => (
              <div
                key={look.id}
                className="relative rounded-2xl border border-border bg-card p-4"
              >
                <button
                  type="button"
                  onClick={() => deleteLook(look.id)}
                  aria-label={t("deleteLook")}
                  className="absolute right-3 top-3 flex h-7 w-7 items-center justify-center rounded-full bg-muted text-muted-foreground transition hover:bg-red-500/80 hover:text-white"
                >
                  ✕
                </button>
                <h3 className="pr-8 text-base font-semibold">{look.title}</h3>
                {look.reason && (
                  <p className="mt-0.5 text-sm text-muted-foreground">
                    {look.reason}
                  </p>
                )}
                <Thumbs itemIds={look.itemIds} />
              </div>
            ))}
          </div>
        </section>
      )}

      {!canGenerate ? (
        <div className="rounded-2xl border border-dashed border-border py-16 text-center">
          <p className="text-sm text-muted-foreground">{t("needItems")}</p>
          <div className="mt-4 flex justify-center gap-4">
            <Link
              href="/detect"
              className="text-sm font-medium text-primary transition hover:opacity-80"
            >
              {t("goScan")}
            </Link>
            <Link
              href="/dashboard"
              className="text-sm font-medium text-primary transition hover:opacity-80"
            >
              {t("goWardrobe")}
            </Link>
          </div>
        </div>
      ) : (
        <div className="flex flex-col gap-6">
          <div>
            <p className="mb-2 text-sm font-semibold">{t("occasionLabel")}</p>
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
            <label
              htmlFor="outfit-note"
              className="mb-2 block text-sm font-semibold"
            >
              {t("noteLabel")}
            </label>
            <input
              id="outfit-note"
              type="text"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              maxLength={200}
              placeholder={t("notePlaceholder")}
              className="h-11 w-full rounded-xl border border-border bg-input px-4 text-sm text-foreground placeholder:text-muted-foreground outline-none transition focus:border-primary"
            />
          </div>

          <button
            type="button"
            onClick={suggest}
            disabled={loading}
            className="fc-gradient flex h-12 items-center justify-center gap-2 rounded-xl text-sm font-semibold text-white transition active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-50"
          >
            {loading ? t("suggesting") : outfits ? t("regenerate") : t("suggest")}
          </button>

          {error && (
            <p className="text-sm text-red-400" role="alert">
              {error}
            </p>
          )}

          {loading && (
            <div className="flex flex-col items-center justify-center gap-4 rounded-2xl border border-border bg-card py-16">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
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
              {outfits.map((outfit, index) => (
                <div
                  key={index}
                  className="rounded-2xl border border-border bg-card p-5"
                >
                  <div className="flex items-start justify-between gap-3">
                    <h3 className="text-lg font-semibold">{outfit.title}</h3>
                    <button
                      type="button"
                      onClick={() => saveLook(outfit, index)}
                      disabled={savedKeys.has(index)}
                      className={
                        savedKeys.has(index)
                          ? "flex shrink-0 items-center gap-1 rounded-full bg-primary/15 px-3 py-1.5 text-xs font-semibold text-primary"
                          : "flex shrink-0 items-center gap-1 rounded-full border border-border px-3 py-1.5 text-xs font-semibold text-muted-foreground transition hover:text-foreground"
                      }
                    >
                      <HeartIcon filled={savedKeys.has(index)} />
                      {savedKeys.has(index) ? t("saved") : t("save")}
                    </button>
                  </div>
                  {outfit.reason && (
                    <p className="mt-1 text-sm text-muted-foreground">
                      {outfit.reason}
                    </p>
                  )}
                  <Thumbs itemIds={outfit.itemIds} />
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function HeartIcon({ filled }: { filled: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill={filled ? "currentColor" : "none"}
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      className="h-4 w-4"
      aria-hidden="true"
    >
      <path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8z" />
    </svg>
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
      className="h-7 w-7"
      aria-hidden="true"
    >
      <path d="M8 3l4 3 4-3 5 4-3 3-2-1v9H8v-9l-2 1-3-3 5-4z" />
    </svg>
  );
}
