"use client";

import { useTranslations } from "next-intl";
import { FormEvent, useState } from "react";
import { authButtonClassName } from "@/components/auth-shell";
import {
  BODY_TYPES,
  COLOR_TONES,
  HEIGHT_RANGE,
  OCCASIONS,
  STYLES,
  WEIGHT_RANGE,
  type Profile,
} from "@/lib/profile";
import { createClient } from "@/lib/supabase-client";

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

export function StyleProfileForm({
  userId,
  initial,
}: {
  userId: string;
  initial: Profile;
}) {
  const ts = useTranslations("settings");
  const tob = useTranslations("onboarding");
  const to = useTranslations("profileOptions");

  const [height, setHeight] = useState(initial.heightCm ?? HEIGHT_RANGE.default);
  const [weight, setWeight] = useState(initial.weightKg ?? WEIGHT_RANGE.default);
  const [bodyType, setBodyType] = useState<string | null>(initial.bodyType);
  const [styles, setStyles] = useState<string[]>(initial.styles);
  const [colors, setColors] = useState<string[]>(initial.colors);
  const [occasions, setOccasions] = useState<string[]>(initial.occasions);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setSaving(true);
    setSaved(false);
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
    setSaving(false);
    if (saveError) {
      setError(ts("profileSaveError"));
      return;
    }
    setSaved(true);
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-6">
      <div>
        <p className="mb-3 text-sm font-medium">{ts("body")}</p>
        <div className="flex flex-col gap-4">
          <div>
            <div className="flex items-center justify-between">
              <label htmlFor="sp-height" className="text-sm text-muted-foreground">
                {tob("height")}
              </label>
              <span className="text-sm text-muted-foreground">{height} cm</span>
            </div>
            <input
              id="sp-height"
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
              <label htmlFor="sp-weight" className="text-sm text-muted-foreground">
                {tob("weight")}
              </label>
              <span className="text-sm text-muted-foreground">{weight} kg</span>
            </div>
            <input
              id="sp-weight"
              type="range"
              min={WEIGHT_RANGE.min}
              max={WEIGHT_RANGE.max}
              value={weight}
              onChange={(e) => setWeight(Number(e.target.value))}
              className="mt-2 w-full accent-violet-500"
            />
          </div>
          <div>
            <p className="mb-2 text-sm text-muted-foreground">{tob("bodyType")}</p>
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
      </div>

      <div>
        <p className="mb-2 text-sm font-medium">{ts("styles")}</p>
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

      <div>
        <p className="mb-2 text-sm font-medium">{ts("colors")}</p>
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

      <div>
        <p className="mb-2 text-sm font-medium">{ts("occasions")}</p>
        <div className="flex flex-wrap gap-2">
          {OCCASIONS.map((item) => (
            <button
              key={item.value}
              type="button"
              onClick={() => setOccasions(toggleValue(occasions, item.value))}
              className={chipClass(occasions.includes(item.value))}
            >
              {to(item.labelKey)}
            </button>
          ))}
        </div>
      </div>

      {error && (
        <p className="text-sm text-red-400" role="alert">
          {error}
        </p>
      )}
      {saved && <p className="text-sm text-emerald-400">{ts("profileSaved")}</p>}

      <button
        type="submit"
        disabled={saving}
        className={`${authButtonClassName} sm:max-w-xs`}
      >
        {saving ? ts("savingProfile") : ts("saveProfile")}
      </button>
    </form>
  );
}
