import Link from "next/link";
import { useTranslations } from "next-intl";
import { LanguageToggle } from "@/components/language-toggle";
import { FitcheckLogo, FitcheckMark } from "@/components/logo";
import { ThemeToggle } from "@/components/theme-toggle";
import { WaitlistForm } from "@/components/waitlist-form";

export default function Home() {
  const t = useTranslations();

  const features = [
    {
      title: t("features.wardrobeTitle"),
      description: t("features.wardrobeDesc"),
      icon: <path d="M3 7l9-4 9 4-9 4-9-4zm0 5l9 4 9-4M3 17l9 4 9-4" />,
    },
    {
      title: t("features.tryonTitle"),
      description: t("features.tryonDesc"),
      icon: (
        <path d="M12 3l1.9 4.6L18.5 9l-3.5 3 1 5-4-2.6L8 17l1-5L5.5 9l4.6-1.4L12 3z" />
      ),
    },
    {
      title: t("features.suggestTitle"),
      description: t("features.suggestDesc"),
      icon: (
        <path d="M5 3v4M3 5h4M6 17v4M4 19h4M13 3l3 7 5 2-5 2-3 7-3-7-5-2 5-2 3-7z" />
      ),
    },
  ];

  return (
    <div className="relative flex min-h-full flex-1 flex-col bg-background text-foreground">
      <header className="sticky top-0 z-30 border-b border-border bg-background/70 backdrop-blur">
        <nav className="mx-auto flex w-full max-w-6xl items-center justify-between px-6 py-4 sm:px-8">
          <Link href="/" aria-label="Fitcheck">
            <FitcheckLogo />
          </Link>
          <div className="flex items-center gap-2 sm:gap-3">
            <LanguageToggle />
            <ThemeToggle />
            <Link
              href="/login"
              className="rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground transition hover:text-foreground sm:px-4"
            >
              {t("nav.login")}
            </Link>
            <Link
              href="/signup"
              className="fc-gradient rounded-lg px-4 py-2 text-sm font-semibold text-white transition active:scale-[0.98]"
            >
              {t("nav.signup")}
            </Link>
          </div>
        </nav>
      </header>

      <main className="relative z-10 flex-1">
        <section className="relative overflow-hidden">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_-20%,rgba(124,58,237,0.22),transparent)]"
          />
          <div
            aria-hidden
            className="pointer-events-none absolute -right-32 top-1/3 h-64 w-64 rounded-full bg-fuchsia-500/10 blur-3xl sm:h-96 sm:w-96"
          />
          <div
            aria-hidden
            className="pointer-events-none absolute -left-32 bottom-0 h-64 w-64 rounded-full bg-violet-500/10 blur-3xl sm:h-96 sm:w-96"
          />

          <div className="relative mx-auto flex w-full max-w-2xl flex-col items-start px-6 py-20 sm:px-8 sm:py-28">
            <FitcheckMark className="mb-6 h-14 w-14" />
            <p className="mb-5 text-sm font-medium tracking-widest text-primary uppercase">
              {t("home.comingSoon")}
            </p>

            <h1 className="text-4xl font-bold tracking-tight text-balance sm:text-5xl sm:leading-tight lg:text-6xl">
              Fitcheck —{" "}
              <span className="fc-gradient-text">{t("home.headlineAccent")}</span>
            </h1>

            <p className="mt-6 max-w-lg text-lg leading-relaxed text-muted-foreground sm:text-xl">
              {t("home.tagline")}
            </p>

            <div className="mt-10 flex flex-col gap-3 sm:flex-row">
              <Link
                href="/signup"
                className="fc-gradient flex h-12 items-center justify-center rounded-xl px-7 text-base font-semibold text-white transition active:scale-[0.98]"
              >
                {t("home.ctaSignup")}
              </Link>
              <Link
                href="/login"
                className="flex h-12 items-center justify-center rounded-xl border border-border bg-card px-7 text-base font-semibold text-foreground transition hover:bg-muted"
              >
                {t("home.ctaLogin")}
              </Link>
            </div>

            <p className="mt-6 text-xs text-muted-foreground sm:text-sm">
              {t("home.freeNote")}
            </p>
          </div>
        </section>

        <section className="mx-auto w-full max-w-6xl px-6 py-16 sm:px-8 sm:py-20">
          <h2 className="text-2xl font-bold tracking-tight sm:text-3xl">
            {t("home.featuresTitle")}
          </h2>
          <p className="mt-3 max-w-lg text-muted-foreground">
            {t("home.featuresSubtitle")}
          </p>

          <div className="mt-10 grid gap-5 sm:grid-cols-3">
            {features.map((feature) => (
              <div
                key={feature.title}
                className="rounded-2xl border border-border bg-card p-6 transition hover:border-primary/40"
              >
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-primary/10 text-primary">
                  <svg
                    aria-hidden
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.6}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    className="h-6 w-6"
                  >
                    {feature.icon}
                  </svg>
                </div>
                <h3 className="mt-5 text-lg font-semibold">{feature.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </section>

        <section className="mx-auto w-full max-w-6xl px-6 pb-20 sm:px-8">
          <div className="rounded-3xl border border-border bg-card p-8 sm:p-12">
            <h2 className="text-xl font-bold tracking-tight sm:text-2xl">
              {t("home.waitlistTitle")}
            </h2>
            <p className="mt-2 max-w-lg text-sm text-muted-foreground sm:text-base">
              {t("home.waitlistSubtitle")}
            </p>
            <div className="mt-6 w-full max-w-md">
              <WaitlistForm />
            </div>
          </div>
        </section>
      </main>

      <footer className="relative z-10 border-t border-border px-6 py-6 text-center text-xs text-muted-foreground sm:px-8">
        © {new Date().getFullYear()} Fitcheck
      </footer>
    </div>
  );
}
