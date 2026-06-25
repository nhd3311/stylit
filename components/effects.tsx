export function AuroraBackground({ className }: { className?: string }) {
  return (
    <div
      aria-hidden
      className={`pointer-events-none absolute inset-0 overflow-hidden ${className ?? ""}`}
    >
      <div
        className="fc-aurora-blob"
        style={{
          top: "-15%",
          left: "5%",
          width: "45%",
          height: "65%",
          background: "radial-gradient(circle, rgba(124,58,237,0.45), transparent 70%)",
          animation: "fc-aurora-1 15s ease-in-out infinite",
        }}
      />
      <div
        className="fc-aurora-blob"
        style={{
          top: "10%",
          right: "0%",
          width: "42%",
          height: "60%",
          background: "radial-gradient(circle, rgba(217,70,239,0.40), transparent 70%)",
          animation: "fc-aurora-2 18s ease-in-out infinite",
        }}
      />
      <div
        className="fc-aurora-blob"
        style={{
          bottom: "-20%",
          left: "28%",
          width: "48%",
          height: "60%",
          background: "radial-gradient(circle, rgba(167,139,250,0.38), transparent 70%)",
          animation: "fc-aurora-1 21s ease-in-out infinite",
        }}
      />
    </div>
  );
}

const MARQUEE_DEFAULT = [
  "Fitcheck",
  "Smart wardrobe",
  "AI Stylist",
  "Virtual try-on",
  "Outfit ideas",
  "Mặc đẹp mỗi ngày",
];

export function Marquee({ items = MARQUEE_DEFAULT }: { items?: string[] }) {
  const row = [...items, ...items];
  return (
    <div className="fc-marquee-mask relative overflow-hidden border-y border-border py-3">
      <div className="fc-marquee-track">
        {row.map((word, i) => (
          <span
            key={i}
            className="flex items-center text-sm font-semibold tracking-wider text-muted-foreground uppercase"
          >
            <span className="px-6">{word}</span>
            <span className="text-primary">✦</span>
          </span>
        ))}
      </div>
    </div>
  );
}
