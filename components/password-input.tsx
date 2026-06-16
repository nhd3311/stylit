"use client";

import { useTranslations } from "next-intl";
import { ChangeEvent, useState } from "react";
import { authInputClassName } from "@/components/auth-shell";

export function PasswordInput({
  id,
  value,
  onChange,
  placeholder,
  autoComplete,
  disabled,
}: {
  id: string;
  value: string;
  onChange: (e: ChangeEvent<HTMLInputElement>) => void;
  placeholder?: string;
  autoComplete?: string;
  disabled?: boolean;
}) {
  const t = useTranslations("auth");
  const [show, setShow] = useState(false);

  return (
    <div className="relative">
      <input
        id={id}
        type={show ? "text" : "password"}
        value={value}
        onChange={onChange}
        placeholder={placeholder}
        autoComplete={autoComplete}
        disabled={disabled}
        className={`${authInputClassName} pr-12`}
      />
      <button
        type="button"
        onClick={() => setShow((prev) => !prev)}
        aria-label={show ? t("hidePassword") : t("showPassword")}
        tabIndex={-1}
        className="absolute inset-y-0 right-0 flex w-12 items-center justify-center text-muted-foreground transition hover:text-foreground"
      >
        {show ? <EyeOffIcon /> : <EyeIcon />}
      </button>
    </div>
  );
}

function EyeIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5" aria-hidden>
      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}

function EyeOffIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5" aria-hidden>
      <path d="M3 3l18 18" />
      <path d="M10.6 10.6a3 3 0 0 0 4.24 4.24" />
      <path d="M9.5 5.2A9.8 9.8 0 0 1 12 5c6.5 0 10 7 10 7a17.6 17.6 0 0 1-3.3 4" />
      <path d="M6.5 6.5A17.4 17.4 0 0 0 2 12s3.5 7 10 7a9.8 9.8 0 0 0 3-.5" />
    </svg>
  );
}
