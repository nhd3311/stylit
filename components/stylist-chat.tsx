"use client";

import { useTranslations } from "next-intl";
import { useEffect, useRef, useState } from "react";

type Msg = { role: "user" | "assistant"; content: string };

export function StylistChat() {
  const t = useTranslations("stylist");
  const [messages, setMessages] = useState<Msg[]>([
    { role: "assistant", content: t("greeting") },
  ]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const endRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, loading]);

  async function send() {
    const text = input.trim();
    if (!text || loading) {
      return;
    }
    const next: Msg[] = [...messages, { role: "user", content: text }];
    setMessages(next);
    setInput("");
    setLoading(true);
    try {
      const res = await fetch("/api/stylist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: next }),
      });
      if (!res.ok) {
        throw new Error("stylist failed");
      }
      const data = (await res.json()) as { reply?: string };
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: data.reply?.trim() || t("error") },
      ]);
    } catch {
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: t("error") },
      ]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <div className="flex flex-col gap-3">
        {messages.map((m, i) =>
          m.role === "assistant" ? (
            <div
              key={i}
              className="max-w-[85%] self-start rounded-2xl rounded-tl-sm border border-border bg-card px-4 py-3 text-sm text-foreground"
            >
              {m.content}
            </div>
          ) : (
            <div
              key={i}
              className="fc-gradient max-w-[85%] self-end rounded-2xl rounded-tr-sm px-4 py-3 text-sm text-white"
            >
              {m.content}
            </div>
          ),
        )}
        {loading && (
          <div className="flex max-w-[85%] items-center gap-2 self-start rounded-2xl rounded-tl-sm border border-border bg-card px-4 py-3 text-sm text-muted-foreground">
            <span className="h-2 w-2 animate-bounce rounded-full bg-primary [animation-delay:-0.2s]" />
            <span className="h-2 w-2 animate-bounce rounded-full bg-primary [animation-delay:-0.1s]" />
            <span className="h-2 w-2 animate-bounce rounded-full bg-primary" />
          </div>
        )}
        <div ref={endRef} />
      </div>

      <div className="fixed inset-x-0 z-30 px-5 bottom-[calc(env(safe-area-inset-bottom)+62px)] md:bottom-5">
        <div className="mx-auto flex w-full max-w-3xl items-center gap-2 rounded-2xl border border-border bg-card p-2 shadow-lg shadow-violet-500/10">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                void send();
              }
            }}
            placeholder={t("placeholder")}
            disabled={loading}
            className="h-10 flex-1 rounded-xl bg-transparent px-3 text-sm text-foreground placeholder:text-muted-foreground outline-none"
          />
          <button
            type="button"
            onClick={() => void send()}
            disabled={loading || !input.trim()}
            aria-label={t("send")}
            className="fc-gradient flex h-10 w-10 items-center justify-center rounded-xl text-white transition active:scale-95 disabled:opacity-50"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5" aria-hidden="true">
              <path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z" />
            </svg>
          </button>
        </div>
      </div>
    </>
  );
}
