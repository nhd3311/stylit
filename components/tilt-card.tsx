"use client";

import { useState, type MouseEvent, type ReactNode } from "react";

export function TiltCard({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  const [tilt, setTilt] = useState({
    rx: 0,
    ry: 0,
    mx: 50,
    my: 50,
    active: false,
  });

  function handleMove(e: MouseEvent<HTMLDivElement>) {
    const rect = e.currentTarget.getBoundingClientRect();
    const px = (e.clientX - rect.left) / rect.width;
    const py = (e.clientY - rect.top) / rect.height;
    setTilt({
      rx: (0.5 - py) * 8,
      ry: (px - 0.5) * 10,
      mx: px * 100,
      my: py * 100,
      active: true,
    });
  }

  function handleLeave() {
    setTilt({ rx: 0, ry: 0, mx: 50, my: 50, active: false });
  }

  return (
    <div
      onMouseMove={handleMove}
      onMouseLeave={handleLeave}
      className={`relative ${className ?? ""}`}
      style={{
        transform: `perspective(900px) rotateX(${tilt.rx}deg) rotateY(${tilt.ry}deg)`,
        transition: tilt.active
          ? "transform 80ms ease-out"
          : "transform 300ms ease-out",
      }}
    >
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 z-10 rounded-2xl transition-opacity duration-300"
        style={{
          opacity: tilt.active ? 1 : 0,
          background: `radial-gradient(240px circle at ${tilt.mx}% ${tilt.my}%, rgba(217,70,239,0.18), transparent 70%)`,
        }}
      />
      {children}
    </div>
  );
}
