import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { BottomNav } from "@/components/bottom-nav";
import { AuroraBackground } from "@/components/effects";
import { FitcheckMark } from "@/components/logo";
import { TiltCard } from "@/components/tilt-card";
import { TopBar } from "@/components/top-bar";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "Trang chủ — Fitcheck",
};

export default async function HomePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/login");
  }

  const t = await getTranslations("homePage");
  const tt = await getTranslations("tabs");

  const features = [
    { href: "/dashboard", title: tt("wardrobe"), desc: t("fWardrobe") },
    { href: "/detect", title: t("fDetectTitle"), desc: t("fDetect") },
    { href: "/outfit", title: tt("outfit"), desc: t("fOutfit") },
    { href: "/tryon", title: t("fTryonTitle"), desc: t("fTryon") },
    { href: "/stylist", title: tt("stylist"), desc: t("fStylist") },
    { href: "/profile", title: tt("profile"), desc: t("fProfile") },
  ];

  const steps = [
    { t: t("p1t"), d: t("p1d") },
    { t: t("p2t"), d: t("p2d") },
    { t: t("p3t"), d: t("p3d") },
    { t: t("p4t"), d: t("p4d") },
    { t: t("p5t"), d: t("p5d") },
  ];

  const docs = [
    { t: t("d1t"), d: t("d1d") },
    { t: t("d2t"), d: t("d2d") },
    { t: t("d3t"), d: t("d3d") },
  ];

  return (
    <div className="flex min-h-full flex-1 flex-col bg-background pb-24 text-foreground md:pb-10">
      <TopBar />
      <main className="mx-auto w-full max-w-5xl flex-1 px-5 py-8 md:px-8">
        <section className="relative overflow-hidden rounded-3xl border border-border bg-card px-6 py-12 text-center sm:px-10 sm:py-16">
          <AuroraBackground />
          <div className="relative flex flex-col items-center">
            <FitcheckMark className="mb-5 h-16 w-16" />
            <h1 className="fc-shine-text text-3xl font-bold tracking-tight sm:text-4xl">
              {t("heroTitle")}
            </h1>
            <p className="mt-3 max-w-xl text-base text-muted-foreground sm:text-lg">
              {t("heroTag")}
            </p>
            <Link
              href="/dashboard"
              className="fc-gradient mt-7 inline-flex h-12 items-center justify-center rounded-xl px-7 text-base font-semibold text-white transition active:scale-[0.98]"
            >
              {t("heroCta")}
            </Link>
          </div>
        </section>

        <section className="mt-14">
          <h2 className="text-xl font-bold tracking-tight">{t("aboutTitle")}</h2>
          <p className="mt-3 max-w-2xl leading-relaxed text-muted-foreground">
            {t("aboutBody")}
          </p>
        </section>

        <section className="mt-14">
          <h2 className="text-xl font-bold tracking-tight">
            {t("featuresTitle")}
          </h2>
          <div className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {features.map((f) => (
              <TiltCard key={f.href}>
              <Link
                href={f.href}
                className="group block h-full rounded-2xl border border-border bg-card p-5 transition hover:border-primary/40"
              >
                <h3 className="text-base font-semibold transition group-hover:text-primary">
                  {f.title}
                </h3>
                <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                  {f.desc}
                </p>
                <span className="mt-3 inline-flex items-center gap-1 text-sm font-medium text-primary">
                  {t("openFeature")}
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4" aria-hidden="true">
                    <path d="M5 12h14M13 6l6 6-6 6" />
                  </svg>
                </span>
              </Link>
              </TiltCard>
            ))}
          </div>
        </section>

        <section className="mt-14">
          <h2 className="text-xl font-bold tracking-tight">
            {t("processTitle")}
          </h2>
          <ol className="relative mt-6 ml-3 border-l border-border">
            {steps.map((s, i) => (
              <li key={i} className="mb-7 ml-7 last:mb-0">
                <span className="fc-gradient absolute -left-3.5 flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold text-white">
                  {i + 1}
                </span>
                <h3 className="font-semibold">{s.t}</h3>
                <p className="mt-0.5 text-sm leading-relaxed text-muted-foreground">
                  {s.d}
                </p>
              </li>
            ))}
          </ol>
        </section>

        <section className="mt-14">
          <h2 className="text-xl font-bold tracking-tight">{t("teamTitle")}</h2>
          <div className="mt-5 flex max-w-md items-center gap-4 rounded-2xl border border-border bg-card p-5">
            <div className="fc-gradient flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl text-2xl font-extrabold text-white">
              D
            </div>
            <div>
              <h3 className="text-lg font-bold">{t("teamName")}</h3>
              <p className="text-sm font-medium text-primary">{t("teamRole")}</p>
              <p className="mt-1 text-sm leading-relaxed text-muted-foreground">
                {t("teamBio")}
              </p>
            </div>
          </div>
        </section>

        <section className="mt-14">
          <h2 className="text-xl font-bold tracking-tight">{t("docsTitle")}</h2>
          <div className="mt-5 grid gap-4 sm:grid-cols-2">
            {docs.map((d) => (
              <div
                key={d.t}
                className="rounded-2xl border border-border bg-card p-5"
              >
                <h3 className="text-base font-semibold">{d.t}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                  {d.d}
                </p>
              </div>
            ))}
            <a
              href="/brand/fitcheck-brand-board.html"
              target="_blank"
              rel="noreferrer"
              className="group rounded-2xl border border-border bg-card p-5 transition hover:border-primary/40"
            >
              <h3 className="text-base font-semibold transition group-hover:text-primary">
                {t("brandTitle")}
              </h3>
              <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                {t("brandDesc")}
              </p>
              <span className="mt-3 inline-flex items-center gap-1 text-sm font-medium text-primary">
                {t("brandLink")}
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4" aria-hidden="true">
                  <path d="M7 17L17 7M9 7h8v8" />
                </svg>
              </span>
            </a>
          </div>
        </section>
      </main>
      <BottomNav />
    </div>
  );
}
