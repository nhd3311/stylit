"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import { ChangeEvent, useState } from "react";
import {
  categoryForGarment,
  DEFAULT_MODELS,
  type TryonCategory,
} from "@/lib/tryon";
import { type WardrobeItem } from "@/lib/wardrobe";

const MAX_DIM = 1024;

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("image load failed"));
    img.src = src;
  });
}

async function fileToDataUrl(file: File): Promise<string> {
  const url = URL.createObjectURL(file);
  const img = await loadImage(url);
  const scale = Math.min(1, MAX_DIM / Math.max(img.width, img.height));
  const w = Math.max(1, Math.round(img.width * scale));
  const h = Math.max(1, Math.round(img.height * scale));
  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  canvas.getContext("2d")?.drawImage(img, 0, 0, w, h);
  URL.revokeObjectURL(url);
  return canvas.toDataURL("image/jpeg", 0.9);
}

export function TryonFlow({ items }: { items: WardrobeItem[] }) {
  const t = useTranslations("tryon");

  const garmentItems = items.filter((i) => i.imageUrl);
  const [garment, setGarment] = useState<WardrobeItem | null>(null);
  const [category, setCategory] = useState<TryonCategory>("tops");
  const [modelMode, setModelMode] = useState<"upload" | "default">("upload");
  const [modelData, setModelData] = useState<string | null>(null);
  const [modelUrl, setModelUrl] = useState<string | null>(null);
  const [status, setStatus] = useState<"idle" | "running" | "done" | "error">(
    "idle",
  );
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  function pickGarment(it: WardrobeItem) {
    setGarment(it);
    setCategory(categoryForGarment(it.category));
  }

  async function handleUpload(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) {
      return;
    }
    const data = await fileToDataUrl(file);
    setModelData(data);
  }

  const modelImage = modelMode === "upload" ? modelData : modelUrl;
  const canRun = Boolean(garment?.imageUrl && modelImage) && status !== "running";

  async function run() {
    if (!garment?.imageUrl || !modelImage) {
      return;
    }
    setStatus("running");
    setError(null);
    setResult(null);
    try {
      const res = await fetch("/api/tryon", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          garmentImageUrl: garment.imageUrl,
          modelImageBase64: modelMode === "upload" ? modelData : undefined,
          modelImageUrl: modelMode === "default" ? modelUrl : undefined,
          category,
        }),
      });
      const info = (await res.json().catch(() => null)) as {
        id?: string;
        error?: string;
      } | null;
      if (!res.ok || !info?.id) {
        throw new Error(info?.error ?? "tryon failed");
      }
      const id = info.id;
      for (let i = 0; i < 28; i += 1) {
        await sleep(2500);
        const s = await fetch(`/api/tryon/status?id=${encodeURIComponent(id)}`);
        const sj = (await s.json().catch(() => null)) as {
          status?: string;
          output?: string[] | null;
          error?: string | null;
        } | null;
        if (sj?.status === "completed" && sj.output?.[0]) {
          setResult(sj.output[0]);
          setStatus("done");
          return;
        }
        if (sj?.status === "failed" || sj?.status === "canceled") {
          throw new Error(sj.error ?? "tryon failed");
        }
      }
      throw new Error(t("timeout"));
    } catch (err) {
      const m = err instanceof Error ? err.message : "";
      setError(m && m !== "tryon failed" ? `${t("error")} — ${m}` : t("error"));
      setStatus("error");
    }
  }

  if (garmentItems.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-border py-16 text-center">
        <p className="text-sm text-muted-foreground">{t("noItems")}</p>
        <Link
          href="/detect"
          className="mt-3 inline-block text-sm font-medium text-primary transition hover:opacity-80"
        >
          {t("goAdd")}
        </Link>
      </div>
    );
  }

  if (status === "done" && result) {
    return (
      <div className="flex flex-col items-center gap-5">
        <h2 className="self-start text-sm font-semibold">{t("result")}</h2>
        <div className="overflow-hidden rounded-2xl border border-border bg-card">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={result} alt="Try-on result" className="max-h-[70vh] w-auto" />
        </div>
        <div className="flex gap-3">
          <button
            type="button"
            onClick={() => {
              setResult(null);
              setStatus("idle");
            }}
            className="h-11 rounded-xl border border-border px-5 text-sm font-semibold text-foreground transition hover:bg-muted"
          >
            {t("tryAnother")}
          </button>
          <a
            href={result}
            target="_blank"
            rel="noreferrer"
            className="fc-gradient flex h-11 items-center rounded-xl px-5 text-sm font-semibold text-white"
          >
            {t("download")}
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-7">
      <section>
        <p className="mb-3 text-sm font-semibold">{t("pickGarment")}</p>
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-4 md:grid-cols-5">
          {garmentItems.map((it) => (
            <button
              key={it.id}
              type="button"
              onClick={() => pickGarment(it)}
              className={
                garment?.id === it.id
                  ? "overflow-hidden rounded-xl border-2 border-primary"
                  : "overflow-hidden rounded-xl border border-border transition hover:border-primary/40"
              }
            >
              <div className="aspect-square w-full bg-white">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={it.imageUrl}
                  alt={it.name}
                  className="h-full w-full object-cover"
                />
              </div>
            </button>
          ))}
        </div>
      </section>

      <section>
        <p className="mb-3 text-sm font-semibold">{t("modelOn")}</p>
        <div className="mb-4 inline-flex rounded-xl border border-border bg-card p-1">
          <button
            type="button"
            onClick={() => setModelMode("upload")}
            className={
              modelMode === "upload"
                ? "rounded-lg bg-primary/15 px-4 py-1.5 text-sm font-semibold text-primary"
                : "rounded-lg px-4 py-1.5 text-sm font-medium text-muted-foreground"
            }
          >
            {t("tabUpload")}
          </button>
          <button
            type="button"
            onClick={() => setModelMode("default")}
            className={
              modelMode === "default"
                ? "rounded-lg bg-primary/15 px-4 py-1.5 text-sm font-semibold text-primary"
                : "rounded-lg px-4 py-1.5 text-sm font-medium text-muted-foreground"
            }
          >
            {t("tabDefault")}
          </button>
        </div>

        {modelMode === "upload" ? (
          <div>
            {modelData ? (
              <div className="flex items-center gap-4">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={modelData}
                  alt="Your photo"
                  className="h-32 w-24 rounded-xl border border-border object-cover"
                />
                <label className="cursor-pointer text-sm font-medium text-primary transition hover:opacity-80">
                  {t("change")}
                  <input type="file" accept="image/*" onChange={handleUpload} className="hidden" />
                </label>
              </div>
            ) : (
              <label className="flex h-32 cursor-pointer items-center justify-center rounded-2xl border-2 border-dashed border-border bg-card px-4 text-center text-sm text-muted-foreground transition hover:border-primary/50">
                {t("uploadHint")}
                <input type="file" accept="image/*" onChange={handleUpload} className="hidden" />
              </label>
            )}
          </div>
        ) : (
          <div>
            <div className="flex gap-3">
              {DEFAULT_MODELS.map((m) => (
                <button
                  key={m.id}
                  type="button"
                  onClick={() => setModelUrl(m.url)}
                  className={
                    modelUrl === m.url
                      ? "overflow-hidden rounded-xl border-2 border-primary"
                      : "overflow-hidden rounded-xl border border-border transition hover:border-primary/40"
                  }
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={m.url}
                    alt="Model"
                    className="h-40 w-28 bg-muted object-cover"
                  />
                </button>
              ))}
            </div>
            <p className="mt-2 text-xs text-muted-foreground">{t("defaultNote")}</p>
          </div>
        )}
      </section>

      <section>
        <p className="mb-3 text-sm font-semibold">{t("category")}</p>
        <div className="flex flex-wrap gap-2">
          {(
            [
              ["tops", t("catTops")],
              ["bottoms", t("catBottoms")],
              ["one-pieces", t("catOnepiece")],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              onClick={() => setCategory(value)}
              className={
                category === value
                  ? "rounded-full border border-primary bg-primary/15 px-4 py-2 text-sm font-medium text-foreground"
                  : "rounded-full border border-border bg-card px-4 py-2 text-sm font-medium text-muted-foreground transition hover:text-foreground"
              }
            >
              {label}
            </button>
          ))}
        </div>
      </section>

      {error && (
        <p className="text-sm text-red-400" role="alert">
          {error}
        </p>
      )}

      {status === "running" ? (
        <div className="flex flex-col items-center justify-center gap-4 rounded-2xl border border-border bg-card py-12">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          <p className="text-sm text-muted-foreground">{t("running")}</p>
        </div>
      ) : (
        <button
          type="button"
          onClick={run}
          disabled={!canRun}
          className="fc-gradient flex h-12 items-center justify-center rounded-xl text-sm font-semibold text-white transition active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-50"
        >
          {t("run")}
        </button>
      )}
    </div>
  );
}
