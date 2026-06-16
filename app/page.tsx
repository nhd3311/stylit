import Link from "next/link";
import { WaitlistForm } from "@/components/waitlist-form";

const features = [
  {
    title: "Online Wardrobe",
    description:
      "Capture and store all your clothes in one place, clean and always in your pocket.",
    icon: <path d="M3 7l9-4 9 4-9 4-9-4zm0 5l9 4 9-4M3 17l9 4 9-4" />,
  },
  {
    title: "AI Virtual Try-On",
    description:
      "Try on any outfit on your body using AI - no need to try on clothes in real life.",
    icon: (
      <path d="M12 3l1.9 4.6L18.5 9l-3.5 3 1 5-4-2.6L8 17l1-5L5.5 9l4.6-1.4L12 3z" />
    ),
  },
  {
    title: "Outfit Suggestion",
    description:
      "AI outfit suggestion based on weather, occasion and your style in seconds.",
    icon: (
      <path d="M5 3v4M3 5h4M6 17v4M4 19h4M13 3l3 7 5 2-5 2-3 7-3-7-5-2 5-2 3-7z" />
    ),
  },
];

export default function Home() {
  return (
    <div className="relative flex min-h-full flex-1 flex-col bg-zinc-950 text-white">
      <header className="sticky top-0 z-30 border-b border-white/5 bg-zinc-950/70 backdrop-blur">
        <nav className="mx-auto flex w-full max-w-6xl items-center justify-between px-6 py-4 sm:px-8">
          <Link
            href="/"
            className="bg-linear-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-lg font-bold tracking-tight text-transparent"
          >
            Fitcheck
          </Link>
          <div className="flex items-center gap-2 sm:gap-3">
            <Link
              href="/login"
              className="rounded-lg px-3 py-2 text-sm font-medium text-zinc-300 transition hover:text-white sm:px-4"
            >
              Login
            </Link>
            <Link
              href="/signup"
              className="rounded-lg bg-linear-to-r from-violet-600 to-fuchsia-600 px-4 py-2 text-sm font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500"
            >
              Sign up
            </Link>
          </div>
        </nav>
      </header>

      <main className="relative z-10 flex-1">
        <section className="relative overflow-hidden">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_-20%,rgba(168,85,247,0.25),transparent)]"
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
            <p className="mb-6 text-sm font-medium tracking-widest text-violet-400 uppercase">
              Coming soon
            </p>

            <h1 className="text-4xl font-bold tracking-tight text-balance sm:text-5xl sm:leading-tight lg:text-6xl">
              Fitcheck —{" "}
              <span className="bg-linear-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-transparent">
                Your smart wardrobe
              </span>
            </h1>

            <p className="mt-6 max-w-lg text-lg leading-relaxed text-zinc-400 sm:text-xl">
              Smart outfit suggestion from your wardrobe, perfect for any occasion.
            </p>

            <div className="mt-10 flex flex-col gap-3 sm:flex-row">
              <Link
                href="/signup"
                className="flex h-12 items-center justify-center rounded-xl bg-linear-to-r from-violet-600 to-fuchsia-600 px-7 text-base font-semibold text-white transition hover:from-violet-500 hover:to-fuchsia-500 active:scale-[0.98]"
              >
                Sign up for free
              </Link>
              <Link
                href="/login"
                className="flex h-12 items-center justify-center rounded-xl border border-zinc-800 bg-zinc-900/60 px-7 text-base font-semibold text-zinc-200 transition hover:border-zinc-700 hover:text-white"
              >
                Login
              </Link>
            </div>

            <p className="mt-6 text-xs text-zinc-600 sm:text-sm">
              Free · No spam · For Gen Z
            </p>
          </div>
        </section>

        <section className="mx-auto w-full max-w-6xl px-6 py-16 sm:px-8 sm:py-20">
          <h2 className="text-2xl font-bold tracking-tight sm:text-3xl">
            Everything you need to outfit yourself
          </h2>
          <p className="mt-3 max-w-lg text-zinc-400">
            From wardrobe management to virtual try-on and outfit suggestion - all in one app.
          </p>

          <div className="mt-10 grid gap-5 sm:grid-cols-3">
            {features.map((feature) => (
              <div
                key={feature.title}
                className="rounded-2xl border border-zinc-800 bg-zinc-900/40 p-6 transition hover:border-violet-500/40"
              >
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-violet-500/10 text-violet-400">
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
                <p className="mt-2 text-sm leading-relaxed text-zinc-400">
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </section>

        <section className="mx-auto w-full max-w-6xl px-6 pb-20 sm:px-8">
          <div className="rounded-3xl border border-zinc-800 bg-zinc-900/40 p-8 sm:p-12">
            <h2 className="text-xl font-bold tracking-tight sm:text-2xl">
              Not ready to sign up?
            </h2>
            <p className="mt-2 max-w-lg text-sm text-zinc-400 sm:text-base">
            Leave your email to get notified when Fitcheck launches new features.            
            </p>
            <div className="mt-6 w-full max-w-md">
              <WaitlistForm />
            </div>
          </div>
        </section>
      </main>

      <footer className="relative z-10 border-t border-white/5 px-6 py-6 text-center text-xs text-zinc-600 sm:px-8">
        © {new Date().getFullYear()} Fitcheck
      </footer>
    </div>
  );
}
