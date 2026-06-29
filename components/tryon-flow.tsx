"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import {
  ChangeEvent,
  PointerEvent as ReactPointerEvent,
  useRef,
  useState,
} from "react";
import { DEFAULT_MODELS } from "@/lib/tryon";
import { type WardrobeItem } from "@/lib/wardrobe";

const MAX_DIM = 1024;

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("image load failed"));
    img.src = src;
  });
}

function drawToDataUrl(img: HTMLImageElement, maxDim: number): string {
  const scale = Math.min(1, maxDim / Math.max(img.width, img.height));
  const w = Math.max(1, Math.round(img.width * scale));
  const h = Math.max(1, Math.round(img.height * scale));
  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  canvas.getContext("2d")?.drawImage(img, 0, 0, w, h);
  return canvas.toDataURL("image/jpeg", 0.9);
}

async function fileToDataUrl(file: File): Promise<string> {
  const url = URL.createObjectURL(file);
  const img = await loadImage(url);
  const out = drawToDataUrl(img, MAX_DIM);
  URL.revokeObjectURL(url);
  return out;
}

async function downscaleDataUrl(dataUrl: string, maxDim: number): Promise<string> {
  const img = await loadImage(dataUrl);
  return drawToDataUrl(img, maxDim);
}

function Turntable({ frames }: { frames: string[] }) {
  const t = useTranslations("tryon");
  const [idx, setIdx] = useState(0);
  const drag = useRef<{ x: number; idx: number } | null>(null);

  function wrap(n: number) {
    return ((n % frames.length) + frames.length) % frames.length;
  }
  function onDown(e: ReactPointerEvent<HTMLDivElement>) {
    drag.current = { x: e.clientX, idx };
    e.currentTarget.setPointerCapture(e.pointerId);
  }
  function onMove(e: ReactPointerEvent<HTMLDivElement>) {
    if (!drag.current) {
      return;
    }
    const dx = e.clientX - drag.current.x;
    setIdx(wrap(drag.current.idx + Math.round(dx / 45)));
  }
  function onUp() {
    drag.current = null;
  }

  return (
    <div className="flex flex-col items-center gap-3">
      <div
        onPointerDown={onDown}
        onPointerMove={onMove}
        onPointerUp={onUp}
        onPointerLeave={onUp}
        className="relative w-full cursor-grab touch-none select-none overflow-hidden rounded-2xl border border-border bg-white active:cursor-grabbing"
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={frames[idx]}
          alt="Try-on"
          draggable={false}
          className="mx-auto max-h-[64vh] w-auto"
        />
        {frames.length > 1 && (
          <span className="absolute bottom-3 left-1/2 -translate-x-1/2 rounded-full bg-zinc-950/60 px-3 py-1 text-xs font-medium text-white backdrop-blur">
            {t("dragHint")}
          </span>
        )}
      </div>
      {frames.length > 1 && (
        <div className="flex items-center gap-4">
          <button
            type="button"
            onClick={() => setIdx(wrap(idx - 1))}
            aria-label="Prev"
            className="flex h-9 w-9 items-center justify-center rounded-full border border-border text-foreground transition hover:bg-muted"
          >
            ‹
          </button>
          <div className="flex gap-1.5">
            {frames.map((_, i) => (
              <span
                key={i}
                className={
                  i === idx
                    ? "h-2 w-2 rounded-full bg-primary"
                    : "h-2 w-2 rounded-full bg-border"
                }
              />
            ))}
          </div>
          <button
            type="button"
            onClick={() => setIdx(wrap(idx + 1))}
            aria-label="Next"
            className="flex h-9 w-9 items-center justify-center rounded-full border border-border text-foreground transition hover:bg-muted"
          >
            ›
          </button>
        </div>
      )}
    </div>
  );
}

export function TryonFlow({ items }: { items: WardrobeItem[] }) {
  const t = useTranslations("tryon");

  const garmentItems = items.filter((i) => i.imageUrl);
  const [selected, setSelected] = useState<string[]>([]);
  const [modelMode, setModelMode] = useState<"upload" | "default">("upload");
  const [modelData, setModelData] = useState<string | null>(null);
  const [modelUrl, setModelUrl] = useState<string | null>(null);
  const [phase, setPhase] = useState<"setup" | "generating" | "result">("setup");
  const [progress, setProgress] = useState(0);
  const [frames, setFrames] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);

  const selectedItems = garmentItems.filter((i) => selected.includes(i.id));
  const modelImage = modelMode === "upload" ? modelData : modelUrl;
  const canRun = selected.length >= 1 && Boolean(modelImage);

  function toggle(id: string) {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
    );
  }

  async function handleUpload(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) {
      return;
    }
    setModelData(await fileToDataUrl(file));
  }

  async function callTryon(payload: Record<string, unknown>): Promise<string> {
    const res = await fetch("/api/tryon", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const info = (await res.json().catch(() => null)) as {
      image?: string;
      error?: string;
    } | null;
    if (!res.ok || !info?.image) {
      throw new Error(info?.error ?? "tryon failed");
    }
    return info.image;
  }

  async function generate() {
    if (!canRun) {
      return;
    }
    setPhase("generating");
    setProgress(0);
    setError(null);
    setFrames([]);
    const garmentImageUrls = selectedItems
      .map((i) => i.imageUrl)
      .filter((u): u is string => Boolean(u));
    try {
      const front = await callTryon({
        garmentImageUrls,
        modelImageBase64: modelMode === "upload" ? modelData : undefined,
        modelImageUrl: modelMode === "default" ? modelUrl : undefined,
        angle: "front",
      });
      setProgress(1);
      const ref = await downscaleDataUrl(front, 768);
      const others = await Promise.all(
        (["right", "back", "left"] as const).map(async (angle) => {
          try {
            const img = await callTryon({ referenceImageBase64: ref, angle });
            setProgress((p) => p + 1);
            return img;
          } catch {
            setProgress((p) => p + 1);
            return null;
          }
        }),
      );
      const fr = [front, ...others.filter((x): x is string => Boolean(x))];
      setFrames(fr);
      setPhase("result");
    } catch (err) {
      const m = err instanceof Error ? err.message : "";
      setError(m && m !== "tryon failed" ? `${t("error")} — ${m}` : t("error"));
      setPhase("setup");
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

  if (phase === "generating") {
    return (
      <div className="flex flex-col items-center justify-center gap-5 rounded-2xl border border-border bg-card py-20">
        <div className="h-10 w-10 animate-spin rounded-full border-2 border-primary border-t-transparent" />
        <p className="text-sm font-medium text-foreground">
          {t("generating3d", { done: progress, total: 4 })}
        </p>
        <div className="h-1.5 w-48 overflow-hidden rounded-full bg-muted">
          <div
            className="fc-gradient h-full rounded-full transition-all duration-500"
            style={{ width: `${(progress / 4) * 100}%` }}
          />
        </div>
      </div>
    );
  }

  if (phase === "result" && frames.length > 0) {
    return (
      <div className="flex flex-col gap-5">
        <h2 className="text-sm font-semibold">{t("result")}</h2>
        <Turntable frames={frames} />
        <div className="flex justify-center gap-3">
          <button
            type="button"
            onClick={() => {
              setFrames([]);
              setPhase("setup");
            }}
            className="h-11 rounded-xl border border-border px-5 text-sm font-semibold text-foreground transition hover:bg-muted"
          >
            {t("tryAnother")}
          </button>
          <a
            href={frames[0]}
            download="fitcheck-tryon.png"
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
        <div className="mb-3 flex items-baseline justify-between">
          <p className="text-sm font-semibold">{t("pickGarment")}</p>
          {selected.length > 0 && (
            <span className="text-xs font-medium text-primary">
              {t("selectedCount", { count: selected.length })}
            </span>
          )}
        </div>
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-4 md:grid-cols-5">
          {garmentItems.map((it) => {
            const on = selected.includes(it.id);
            return (
              <button
                key={it.id}
                type="button"
                onClick={() => toggle(it.id)}
                className={
                  on
                    ? "relative overflow-hidden rounded-xl border-2 border-primary"
                    : "relative overflow-hidden rounded-xl border border-border transition hover:border-primary/40"
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
                {on && (
                  <span className="fc-gradient absolute right-1.5 top-1.5 flex h-5 w-5 items-center justify-center rounded-full text-[11px] font-bold text-white">
                    ✓
                  </span>
                )}
              </button>
            );
          })}
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
          modelData ? (
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
          )
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
                  <img src={m.url} alt="Model" className="h-40 w-28 bg-muted object-cover" />
                </button>
              ))}
            </div>
            <p className="mt-2 text-xs text-muted-foreground">{t("defaultNote")}</p>
          </div>
        )}
      </section>

      {error && (
        <p className="text-sm text-red-400" role="alert">
          {error}
        </p>
      )}

      <button
        type="button"
        onClick={generate}
        disabled={!canRun}
        className="fc-gradient flex h-12 items-center justify-center rounded-xl text-sm font-semibold text-white transition active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-50"
      >
        {t("run")}
      </button>
    </div>
  );
}
