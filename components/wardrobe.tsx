"use client";

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
          Wardrobe table not found. Run <code>supabase/wardrobe.sql</code> in
          your Supabase SQL editor, then refresh this page.
        </div>
      )}

      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">
            Your wardrobe
          </h1>
          <p className="mt-1 text-sm text-zinc-400">
            {items.length} {items.length === 1 ? "item" : "items"} in your closet
          </p>
        </div>
        <button
          type="button"
          onClick={() => setShowAdd(true)}
          className="inline-flex h-11 items-center justify-center gap-1 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 px-5 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 active:scale-[0.98]"
        >
          <span className="text-lg leading-none">+</span> Add item
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
                : "rounded-full bg-zinc-900/60 px-4 py-1.5 text-sm font-medium text-zinc-400 ring-1 ring-zinc-800 transition hover:text-zinc-200"
            }
          >
            {cat}
          </button>
        ))}
      </div>

      {visibleItems.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-zinc-800 py-20 text-center">
          <p className="text-zinc-400">No items here yet.</p>
          <button
            type="button"
            onClick={() => setShowAdd(true)}
            className="mt-4 text-sm font-medium text-violet-400 transition hover:text-violet-300"
          >
            Add your first piece
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
  return (
    <div className="group relative overflow-hidden rounded-2xl border border-zinc-800 bg-zinc-900/40">
      <div className="aspect-square w-full">
        {item.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={item.imageUrl}
            alt={item.name}
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-linear-to-br from-zinc-800 to-zinc-900 text-zinc-600">
            <ShirtIcon />
          </div>
        )}
      </div>
      <button
        type="button"
        onClick={() => onDelete(item)}
        aria-label={`Delete ${item.name}`}
        className="absolute right-2 top-2 flex h-8 w-8 items-center justify-center rounded-full bg-zinc-950/70 text-zinc-300 opacity-0 backdrop-blur transition group-hover:opacity-100 hover:bg-red-500/80 hover:text-white"
      >
        ✕
      </button>
      <div className="p-3">
        <p className="truncate text-sm font-medium text-white">{item.name}</p>
        <p className="mt-0.5 text-xs text-zinc-500">{item.category}</p>
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
      setError("Something went wrong. Please try again.");
      setSubmitting(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-zinc-800 bg-zinc-950 p-6">
        <h2 className="text-lg font-semibold text-white">Add an item</h2>
        <form onSubmit={handleSubmit} className="mt-5 flex flex-col gap-4">
          <label className="flex aspect-video cursor-pointer items-center justify-center overflow-hidden rounded-xl border border-dashed border-zinc-700 bg-zinc-900/60 text-sm text-zinc-500 transition hover:border-violet-500">
            {preview ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={preview}
                alt="Preview"
                className="h-full w-full object-cover"
              />
            ) : (
              <span>Click to upload a photo</span>
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
              className="mb-2 block text-sm font-medium text-zinc-300"
            >
              Name
            </label>
            <input
              id="item-name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. White linen shirt"
              className="h-11 w-full rounded-xl border border-zinc-800 bg-zinc-900/80 px-4 text-sm text-white placeholder:text-zinc-500 outline-none transition focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20"
            />
          </div>

          <div>
            <label
              htmlFor="item-category"
              className="mb-2 block text-sm font-medium text-zinc-300"
            >
              Category
            </label>
            <select
              id="item-category"
              value={category}
              onChange={(e) => setCategory(e.target.value as Category)}
              className="h-11 w-full rounded-xl border border-zinc-800 bg-zinc-900/80 px-4 text-sm text-white outline-none transition focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20"
            >
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {c}
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
              className="h-11 flex-1 rounded-xl border border-zinc-800 text-sm font-medium text-zinc-300 transition hover:text-white disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!name.trim() || submitting}
              className="h-11 flex-1 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {submitting ? "Saving..." : "Add to wardrobe"}
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
