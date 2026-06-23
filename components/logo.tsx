export function FitcheckMark({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 120 120" className={className} aria-hidden="true">
      <defs>
        <linearGradient id="fc-mark" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#6D28D9" />
          <stop offset="1" stopColor="#D946EF" />
        </linearGradient>
      </defs>
      <rect x="4" y="4" width="112" height="112" rx="30" fill="url(#fc-mark)" />
      <g fill="#ffffff">
        <polygon points="50,84 31,57 41,55 52,76" />
        <polygon points="50,84 82,36 90,43 56,76" />
      </g>
    </svg>
  );
}

export function FitcheckLogo({ className }: { className?: string }) {
  return (
    <span className={`flex items-center gap-2 ${className ?? ""}`}>
      <FitcheckMark className="h-7 w-7" />
      <span className="fc-gradient-text text-lg font-extrabold tracking-tight">
        Fitcheck
      </span>
    </span>
  );
}
