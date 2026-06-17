"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState } from "react";
import {
  BODY_TYPES,
  COLOR_TONES,
  HEIGHT_RANGE,
  OCCASIONS,
  STYLES,
  WEIGHT_RANGE,
} from "@/lib/profile";
import { createClient } from "@/lib/supabase-client";

const TOTAL_STEPS = 4;

function toggleValue(list: string[], value: string): string[] {
  return list.includes(value)
    ? list.filter((item) => item !== value)
    : [...list, value];
}

function chipClass(active: boolean): string {
  return active
    ? "inline-flex items-center gap-2 rounded-full border border-violet-500 bg-violet-500/15 px-4 py-2 text-sm font-medium text-foreground"
    : "inline-flex items-center gap-2 rounded-full border border-border bg-card px-4 py-2 text-sm font-medium text-muted-foreground transition hover:text-foreground";
}

export function OnboardingWizard({ userId }: { userId: string }) {
  const t = useTranslations("onboarding");
  const to = useTranslations("profileOptions");
  const router = useRouter();

  const [step, setStep] = useState(0);
  const [height, setHeight] = useState(HEIGHT_RANGE.default);
  const [weight, setWeight] = useState(WEIGHT_RANGE.default);
  const [bodyType, setBodyType] = useState<string | null>(null);
  const [styles, setStyles] = useState<string[]>([]);
  const [colors, setColors] = useState<string[]>([]);
  const [occasions, setOccasions] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save() {
    setSaving(true);
    setError(null);
    const supabase = createClient();
    const { error: saveError } = await supabase.from("profiles").upsert(
      {
        user_id: userId,
        height_cm: height,
        weight_kg: weight,
        body_type: bodyType,
        styles,
        colors,
        occasions,
        onboarded: true,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" },
    );
    if (saveError) {
      setError(t("saveError"));
      setSaving(false);
      return;
    }
    router.push("/dashboard");
    router.refresh();
  }

  function handleNext() {
    if (step < TOTAL_STEPS - 1) {
      setStep((value) => value + 1);
    } else {
      save();
    }
  }

  return (
    <div className="flex flex-1 flex-col">
      <div>
        <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">
          {t("title")}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">{t("subtitle")}</p>
      </div>

      <div className="mt-6 flex items-center justify-between">
        <span className="text-sm text-muted-foreground">
          {t("stepOf", { current: step + 1, total: TOTAL_STEPS })}
        </span>
        <button
          type="button"
          onClick={save}
          disabled={saving}
          className="text-sm font-medium text-muted-foreground transition hover:text-foreground disabled:opacity-50"
        >
          {t("skip")}
        </button>
      </div>
      <div className="mt-3 h-1.5 w-full overflow-hidden rounded-full bg-muted">
        <div
          className="h-full rounded-full bg-linear-to-r from-violet-500 to-fuchsia-500 transition-all"
          style={{ width: `${((step + 1) / TOTAL_STEPS) * 100}%` }}
        />
      </div>

      <div className="mt-8 flex-1">
        {step === 0 && (
          <div className="flex flex-col gap-6">
            <div>
              <h2 className="text-xl font-bold">{t("stepBodyTitle")}</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                {t("stepBodyDesc")}
              </p>
            </div>
            <div>
              <div className="flex items-center justify-between">
                <label htmlFor="ob-height" className="text-sm font-medium">
                  {t("height")}
                </label>
                <span className="text-sm text-muted-foreground">
                  {height} cm
                </span>
              </div>
              <input
                id="ob-height"
                type="range"
                min={HEIGHT_RANGE.min}
                max={HEIGHT_RANGE.max}
                value={height}
                onChange={(e) => setHeight(Number(e.target.value))}
                className="mt-2 w-full accent-violet-500"
              />
            </div>
            <div>
              <div className="flex items-center justify-between">
                <label htmlFor="ob-weight" className="text-sm font-medium">
                  {t("weight")}
                </label>
                <span className="text-sm text-muted-foreground">
                  {weight} kg
                </span>
              </div>
              <input
                id="ob-weight"
                type="range"
                min={WEIGHT_RANGE.min}
                max={WEIGHT_RANGE.max}
                value={weight}
                onChange={(e) => setWeight(Number(e.target.value))}
                className="mt-2 w-full accent-violet-500"
              />
            </div>
            <div>
              <p className="mb-2 text-sm font-medium">{t("bodyType")}</p>
              <div className="flex flex-wrap gap-2">
                {BODY_TYPES.map((item) => (
                  <button
                    key={item.value}
                    type="button"
                    onClick={() =>
                      setBodyType(bodyType === item.value ? null : item.value)
                    }
                    className={chipClass(bodyType === item.value)}
                  >
                    {to(item.labelKey)}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {step === 1 && (
          <div className="flex flex-col gap-6">
            <div>
              <h2 className="text-xl font-bold">{t("stepStylesTitle")}</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                {t("stepStylesDesc")}
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              {STYLES.map((item) => (
                <button
                  key={item.value}
                  type="button"
                  onClick={() => setStyles(toggleValue(styles, item.value))}
                  className={chipClass(styles.includes(item.value))}
                >
                  {to(item.labelKey)}
                </button>
              ))}
            </div>
          </div>
        )}

        {step === 2 && (
          <div className="flex flex-col gap-6">
            <div>
              <h2 className="text-xl font-bold">{t("stepColorsTitle")}</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                {t("stepColorsDesc")}
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              {COLOR_TONES.map((item) => (
                <button
                  key={item.value}
                  type="button"
                  onClick={() => setColors(toggleValue(colors, item.value))}
                  className={chipClass(colors.includes(item.value))}
                >
                  <span
                    className="h-4 w-4 rounded-full ring-1 ring-black/10"
                    style={{ backgroundColor: item.swatch }}
                  />
                  {to(item.labelKey)}
                </button>
              ))}
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="flex flex-col gap-6">
            <div>
              <h2 className="text-xl font-bold">{t("stepOccasionsTitle")}</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                {t("stepOccasionsDesc")}
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              {OCCASIONS.map((item) => (
                <button
                  key={item.value}
                  type="button"
                  onClick={() =>
                    setOccasions(toggleValue(occasions, item.value))
                  }
                  className={chipClass(occasions.includes(item.value))}
                >
                  {to(item.labelKey)}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>

      {error && (
        <p className="mt-4 text-sm text-red-400" role="alert">
          {error}
        </p>
      )}

      <div className="mt-8 flex gap-3">
        {step > 0 && (
          <button
            type="button"
            onClick={() => setStep((value) => value - 1)}
            disabled={saving}
            className="h-12 flex-1 rounded-xl border border-border text-sm font-semibold text-foreground transition hover:bg-muted disabled:opacity-50"
          >
            {t("back")}
          </button>
        )}
        <button
          type="button"
          onClick={handleNext}
          disabled={saving}
          className="h-12 flex-1 rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 disabled:opacity-60"
        >
          {saving
            ? t("saving")
            : step < TOTAL_STEPS - 1
              ? t("next")
              : t("finish")}
        </button>
      </div>
    </div>
  );
}
