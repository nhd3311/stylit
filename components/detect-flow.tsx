"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { ChangeEvent, useEffect, useMemo, useRef, useState } from "react";
import { createClient } from "@/lib/supabase-client";
import { CATEGORIES, WARDROBE_BUCKET } from "@/lib/wardrobe";

type DetItem = {
  id: string;
  name: string;
  category: string;
  color: string;
  thumb: string;
  include: boolean;
};

const MAX_DIM = 1024;

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("image load failed"));
    img.src = src;
  });
}

function drawScaled(
  source: CanvasImageSource,
  sw: number,
  sh: number,
  maxDim: number,
) {
  const scale = Math.min(1, maxDim / Math.max(sw, sh));
  const w = Math.max(1, Math.round(sw * scale));
  const h = Math.max(1, Math.round(sh * scale));
  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  canvas.getContext("2d")?.drawImage(source, 0, 0, w, h);
  return canvas.toDataURL("image/jpeg", 0.85);
}

async function fileToImage(file: File) {
  const url = URL.createObjectURL(file);
  const original = await loadImage(url);
  const dataUrl = drawScaled(original, original.width, original.height, MAX_DIM);
  URL.revokeObjectURL(url);
  const img = await loadImage(dataUrl);
  return { img, base64: dataUrl.split(",")[1] ?? "" };
}

async function videoToImage(video: HTMLVideoElement) {
  const dataUrl = drawScaled(video, video.videoWidth, video.videoHeight, MAX_DIM);
  const img = await loadImage(dataUrl);
  return { img, base64: dataUrl.split(",")[1] ?? "" };
}

function cropToDataUrl(img: HTMLImageElement, box2d: number[]): string {
  const [ymin, xmin, ymax, xmax] = box2d;
  const x = (xmin / 1000) * img.width;
  const y = (ymin / 1000) * img.height;
  const w = Math.max(1, ((xmax - xmin) / 1000) * img.width);
  const h = Math.max(1, ((ymax - ymin) / 1000) * img.height);
  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  canvas.getContext("2d")?.drawImage(img, x, y, w, h, 0, 0, w, h);
  return canvas.toDataURL("image/jpeg", 0.85);
}

async function dataUrlToBlob(dataUrl: string): Promise<Blob> {
  const res = await fetch(dataUrl);
  return res.blob();
}

function attachStream(video: HTMLVideoElement, stream: MediaStream) {
  video.srcObject = stream;
}

function stopStream(stream: MediaStream | null) {
  stream?.getTracks().forEach((track) => track.stop());
}

export function DetectFlow({ userId }: { userId: string }) {
  const t = useTranslations("detect");
  const tc = useTranslations("categories");
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);

  const [step, setStep] = useState<"capture" | "detecting" | "results">(
    "capture",
  );
  const [cameraOn, setCameraOn] = useState(false);
  const [image, setImage] = useState<HTMLImageElement | null>(null);
  const [items, setItems] = useState<DetItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);

  useEffect(() => () => stopStream(streamRef.current), []);

  async function startCamera() {
    setError(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment" },
      });
      streamRef.current = stream;
      if (videoRef.current) {
        attachStream(videoRef.current, stream);
        await videoRef.current.play();
      }
      setCameraOn(true);
    } catch {
      setError(t("cameraError"));
    }
  }

  function stopCamera() {
    stopStream(streamRef.current);
    streamRef.current = null;
    setCameraOn(false);
  }

  async function runDetect(base64: string, img: HTMLImageElement) {
    setImage(img);
    setStep("detecting");
    setError(null);
    try {
      const res = await fetch("/api/detect", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ imageBase64: base64, mimeType: "image/jpeg" }),
      });
      if (!res.ok) {
        throw new Error("detect failed");
      }
      const data = (await res.json()) as {
        items: { name: string; category: string; color: string; box2d: number[] }[];
      };
      setItems(
        data.items.map((it, index) => ({
          id: String(index),
          name: it.name,
          category: it.category,
          color: it.color,
          thumb: cropToDataUrl(img, it.box2d),
          include: true,
        })),
      );
      setStep("results");
    } catch {
      setError(t("detectError"));
      setStep("capture");
    }
  }

  async function captureFromCamera() {
    if (!videoRef.current) {
      return;
    }
    const { img, base64 } = await videoToImage(videoRef.current);
    stopCamera();
    await runDetect(base64, img);
  }

  async function handleFile(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) {
      return;
    }
    const { img, base64 } = await fileToImage(file);
    await runDetect(base64, img);
  }

  function reset() {
    setItems([]);
    setImage(null);
    setError(null);
    setStep("capture");
  }

  async function addSelected() {
    const selected = items.filter((it) => it.include);
    if (selected.length === 0) {
      return;
    }
    setAdding(true);
    setError(null);
    try {
      for (const it of selected) {
        const blob = await dataUrlToBlob(it.thumb);
        const path = `${userId}/${crypto.randomUUID()}.jpg`;
        const { error: upErr } = await supabase.storage
          .from(WARDROBE_BUCKET)
          .upload(path, blob, { contentType: "image/jpeg" });
        if (upErr) {
          throw upErr;
        }
        const { error: insErr } = await supabase.from("wardrobe_items").insert({
          user_id: userId,
          name: it.name.trim() || "Item",
          category: it.category,
          image_path: path,
        });
        if (insErr) {
          throw insErr;
        }
      }
      router.push("/dashboard");
      router.refresh();
    } catch {
      setError(t("addError"));
      setAdding(false);
    }
  }

  const selectedCount = items.filter((it) => it.include).length;
  void image;

  return (
    <div className="flex flex-col gap-6">
      {step === "capture" && (
        <div className="flex flex-col gap-4">
          {cameraOn ? (
            <div className="flex flex-col gap-3">
              <video
                ref={videoRef}
                autoPlay
                playsInline
                muted
                className="aspect-video w-full rounded-2xl border border-border bg-black object-cover"
              />
              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={stopCamera}
                  className="h-12 flex-1 rounded-xl border border-border text-sm font-semibold text-foreground transition hover:bg-muted"
                >
                  {t("back")}
                </button>
                <button
                  type="button"
                  onClick={captureFromCamera}
                  className="h-12 flex-1 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500"
                >
                  {t("capture")}
                </button>
              </div>
            </div>
          ) : (
            <div className="flex flex-col gap-3 sm:flex-row">
              <button
                type="button"
                onClick={startCamera}
                className="flex h-12 flex-1 items-center justify-center gap-2 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500"
              >
                <CameraIcon />
                {t("useCamera")}
              </button>
              <label className="flex h-12 flex-1 cursor-pointer items-center justify-center gap-2 rounded-xl border border-border bg-card text-sm font-semibold text-foreground transition hover:bg-muted">
                <UploadIcon />
                {t("upload")}
                <input
                  type="file"
                  accept="image/*"
                  onChange={handleFile}
                  className="hidden"
                />
              </label>
            </div>
          )}
          {error && (
            <p className="text-sm text-red-400" role="alert">
              {error}
            </p>
          )}
        </div>
      )}

      {step === "detecting" && (
        <div className="flex flex-col items-center justify-center gap-4 rounded-2xl border border-border bg-card py-20">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-violet-500 border-t-transparent" />
          <p className="text-sm text-muted-foreground">{t("detecting")}</p>
        </div>
      )}

      {step === "results" && (
        <div className="flex flex-col gap-5">
          {items.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-border py-16 text-center text-sm text-muted-foreground">
              {t("noItems")}
            </div>
          ) : (
            <>
              <p className="text-sm text-muted-foreground">
                {t("found", { count: items.length })}
              </p>
              <div className="flex flex-col gap-3">
                {items.map((item, index) => (
                  <div
                    key={item.id}
                    className="flex items-center gap-3 rounded-2xl border border-border bg-card p-3"
                  >
                    <label className="flex shrink-0 items-center">
                      <input
                        type="checkbox"
                        checked={item.include}
                        onChange={(e) =>
                          setItems((prev) =>
                            prev.map((entry, i) =>
                              i === index
                                ? { ...entry, include: e.target.checked }
                                : entry,
                            ),
                          )
                        }
                        className="h-5 w-5 accent-violet-500"
                      />
                    </label>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={item.thumb}
                      alt={item.name}
                      className="h-16 w-16 shrink-0 rounded-lg border border-border object-cover"
                    />
                    <div className="flex flex-1 flex-col gap-2">
                      <input
                        type="text"
                        value={item.name}
                        onChange={(e) =>
                          setItems((prev) =>
                            prev.map((entry, i) =>
                              i === index
                                ? { ...entry, name: e.target.value }
                                : entry,
                            ),
                          )
                        }
                        className="h-9 w-full rounded-lg border border-border bg-input px-3 text-sm text-foreground outline-none transition focus:border-violet-500"
                      />
                      <select
                        value={item.category}
                        onChange={(e) =>
                          setItems((prev) =>
                            prev.map((entry, i) =>
                              i === index
                                ? { ...entry, category: e.target.value }
                                : entry,
                            ),
                          )
                        }
                        className="h-9 w-full rounded-lg border border-border bg-input px-3 text-sm text-foreground outline-none transition focus:border-violet-500"
                      >
                        {CATEGORIES.map((c) => (
                          <option key={c} value={c}>
                            {tc(c)}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}

          {error && (
            <p className="text-sm text-red-400" role="alert">
              {error}
            </p>
          )}

          <div className="flex gap-3">
            <button
              type="button"
              onClick={reset}
              disabled={adding}
              className="h-12 flex-1 rounded-xl border border-border text-sm font-semibold text-foreground transition hover:bg-muted disabled:opacity-50"
            >
              {t("scan")}
            </button>
            {items.length > 0 && (
              <button
                type="button"
                onClick={addSelected}
                disabled={adding || selectedCount === 0}
                className="h-12 flex-1 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {adding ? t("adding") : t("addSelected", { count: selectedCount })}
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function CameraIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5" aria-hidden>
      <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" />
      <circle cx="12" cy="13" r="4" />
    </svg>
  );
}

function UploadIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5" aria-hidden>
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12" />
    </svg>
  );
}
