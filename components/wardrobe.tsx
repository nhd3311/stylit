"use client";

import { useTranslations } from "next-intl";
import { ChangeEvent, FormEvent, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase-client";
import {
  CATEGORIES,
  WARDROBE_BUCKET,
  type Category,
  type WardrobeItem,
} from "@/lib/wardrobe";

type NewItem = {
  name: string;
  category: Category;
  file: File | null;
};

const FILTERS: (Category | "All")[] = ["All", ...CATEGORIES];

export function Wardrobe({
  userId,
  initialItems,
  needsSetup,
}: {
  userId: string;
  initialItems: WardrobeItem[];
  needsSetup: boolean;
}) {
  const t = useTranslations("wardrobe");
  const tc = useTranslations("categories");
  const supabase = useMemo(() => createClient(), []);
  const [items, setItems] = useState<WardrobeItem[]>(initialItems);
  const [filter, setFilter] = useState<Category | "All">("All");
  const [showAdd, setShowAdd] = useState(false);

  const visibleItems = useMemo(
    () =>
      filter === "All"
        ? items
        : items.filter((item) => item.category === filter),
    [items, filter],
  );

  async function addItem({ name, category, file }: NewItem) {
    let imagePath: string | null = null;

    if (file) {
      const ext = file.name.split(".").pop() ?? "jpg";
      const path = `${userId}/${crypto.randomUUID()}.${ext}`;
      const { error: uploadError } = await supabase.storage
        .from(WARDROBE_BUCKET)
        .upload(path, file);
      if (uploadError) {
        throw new Error("Image upload failed.");
      }
      imagePath = path;
    }

    const { data, error: insertError } = await supabase
      .from("wardrobe_items")
      .insert({ name, category, image_path: imagePath })
      .select("id, name, category, image_path")
      .single();

    if (insertError || !data) {
      throw new Error("Couldn't save the item.");
    }

    const savedPath = (data.image_path as string | null) ?? null;
    setItems((prev) => [
      {
        id: data.id as string,
        name: data.name as string,
        category: data.category as Category,
        imagePath: savedPath,
        imageUrl: savedPath
          ? supabase.storage.from(WARDROBE_BUCKET).getPublicUrl(savedPath).data
              .publicUrl
          : undefined,
      },
      ...prev,
    ]);
    setShowAdd(false);
  }

  async function handleDelete(item: WardrobeItem) {
    setItems((prev) => prev.filter((entry) => entry.id !== item.id));
    if (item.imagePath) {
      await supabase.storage.from(WARDROBE_BUCKET).remove([item.imagePath]);
    }
    await supabase.from("wardrobe_items").delete().eq("id", item.id);
  }

  return (
    <div className="flex flex-col gap-8">
      {needsSetup && (
        <div className="rounded-2xl border border-amber-500/30 bg-amber-500/10 p-4 text-sm text-amber-200">
          {t("setupNeeded")}
        </div>
      )}

      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">
            {t("title")}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {t("itemCount", { count: items.length })}
          </p>
        </div>
        <button
          type="button"
          onClick={() => setShowAdd(true)}
          className="inline-flex h-11 items-center justify-center gap-1 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 px-5 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 active:scale-[0.98]"
        >
          <span className="text-lg leading-none">+</span> {t("addItem")}
        </button>
      </div>

      <div className="flex flex-wrap gap-2">
        {FILTERS.map((cat) => (
          <button
            key={cat}
            type="button"
            onClick={() => setFilter(cat)}
            className={
              filter === cat
                ? "rounded-full bg-violet-500/20 px-4 py-1.5 text-sm font-medium text-violet-200 ring-1 ring-violet-500/40"
                : "rounded-full bg-card px-4 py-1.5 text-sm font-medium text-muted-foreground ring-1 ring-border transition hover:text-foreground"
            }
          >
            {tc(cat)}
          </button>
        ))}
      </div>

      {visibleItems.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-border py-20 text-center">
          <p className="text-muted-foreground">{t("empty")}</p>
          <button
            type="button"
            onClick={() => setShowAdd(true)}
            className="mt-4 text-sm font-medium text-violet-400 transition hover:text-violet-300"
          >
            {t("addFirst")}
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
          {visibleItems.map((item) => (
            <WardrobeCard key={item.id} item={item} onDelete={handleDelete} />
          ))}
        </div>
      )}

      {showAdd && (
        <AddItemModal onClose={() => setShowAdd(false)} onAdd={addItem} />
      )}
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
      <div className="aspect-square w-full">
        {item.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={item.imageUrl}
            alt={item.name}
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-muted text-muted-foreground">
            <ShirtIcon />
          </div>
        )}
      </div>
      <button
        type="button"
        onClick={() => onDelete(item)}
        aria-label={t("delete", { name: item.name })}
        className="absolute right-2 top-2 flex h-8 w-8 items-center justify-center rounded-full bg-zinc-950/70 text-white opacity-0 backdrop-blur transition group-hover:opacity-100 hover:bg-red-500/80"
      >
        ✕
      </button>
      <div className="p-3">
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

function AddItemModal({
  onClose,
  onAdd,
}: {
  onClose: () => void;
  onAdd: (item: NewItem) => Promise<void>;
}) {
  const t = useTranslations("wardrobe");
  const tc = useTranslations("categories");
  const [name, setName] = useState("");
  const [category, setCategory] = useState<Category>("Tops");
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function handleFile(e: ChangeEvent<HTMLInputElement>) {
    const selected = e.target.files?.[0] ?? null;
    setFile(selected);
    setPreview(selected ? URL.createObjectURL(selected) : null);
  }

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const trimmed = name.trim();
    if (!trimmed || submitting) {
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await onAdd({ name: trimmed, category, file });
    } catch {
      setError(t("saveError"));
      setSubmitting(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-border bg-background p-6">
        <h2 className="text-lg font-semibold text-foreground">
          {t("modalTitle")}
        </h2>
        <form onSubmit={handleSubmit} className="mt-5 flex flex-col gap-4">
          <label className="flex aspect-video cursor-pointer items-center justify-center overflow-hidden rounded-xl border border-dashed border-border bg-card text-sm text-muted-foreground transition hover:border-violet-500">
            {preview ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={preview}
                alt="Preview"
                className="h-full w-full object-cover"
              />
            ) : (
              <span>{t("uploadHint")}</span>
            )}
            <input
              type="file"
              accept="image/*"
              onChange={handleFile}
              className="hidden"
            />
          </label>

          <div>
            <label
              htmlFor="item-name"
              className="mb-2 block text-sm font-medium text-foreground"
            >
              {t("name")}
            </label>
            <input
              id="item-name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder={t("namePlaceholder")}
              className="h-11 w-full rounded-xl border border-border bg-input px-4 text-sm text-foreground placeholder:text-muted-foreground outline-none transition focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20"
            />
          </div>

          <div>
            <label
              htmlFor="item-category"
              className="mb-2 block text-sm font-medium text-foreground"
            >
              {t("category")}
            </label>
            <select
              id="item-category"
              value={category}
              onChange={(e) => setCategory(e.target.value as Category)}
              className="h-11 w-full rounded-xl border border-border bg-input px-4 text-sm text-foreground outline-none transition focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20"
            >
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {tc(c)}
                </option>
              ))}
            </select>
          </div>

          {error && (
            <p className="text-sm text-red-400" role="alert">
              {error}
            </p>
          )}

          <div className="mt-2 flex gap-3">
            <button
              type="button"
              onClick={onClose}
              disabled={submitting}
              className="h-11 flex-1 rounded-xl border border-border text-sm font-medium text-muted-foreground transition hover:text-foreground disabled:opacity-50"
            >
              {t("cancel")}
            </button>
            <button
              type="submit"
              disabled={!name.trim() || submitting}
              className="h-11 flex-1 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {submitting ? t("saving") : t("save")}
            </button>
          </div>
        </form>
      </div>
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
      className="h-10 w-10"
    >
      <path d="M8 3l4 3 4-3 5 4-3 3-2-1v9H8v-9l-2 1-3-3 5-4z" />
    </svg>
  );
}
