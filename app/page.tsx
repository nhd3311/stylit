import { WaitlistForm } from "@/components/waitlist-form";

export default function Home() {
  return (
    <div className="relative flex min-h-full flex-1 flex-col overflow-hidden bg-zinc-950 text-white">
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
        className="pointer-events-none absolute -left-32 bottom-1/4 h-64 w-64 rounded-full bg-violet-500/10 blur-3xl sm:h-96 sm:w-96"
      />

      <main className="relative z-10 mx-auto flex w-full max-w-2xl flex-1 flex-col justify-center px-6 py-16 sm:px-8 sm:py-24">
        <p className="mb-6 text-sm font-medium tracking-widest text-violet-400 uppercase">
          Sắp ra mắt
        </p>

        <h1 className="text-4xl font-bold tracking-tight text-balance sm:text-5xl sm:leading-tight lg:text-6xl">
          Fitcheck —{" "}
          <span className="bg-linear-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-transparent">
            Tủ đồ thông minh của bạn
          </span>
        </h1>

        <p className="mt-6 max-w-lg text-lg leading-relaxed text-zinc-400 sm:text-xl">
          Phối đồ thông minh từ tủ đồ của bạn, gợi ý outfit phù hợp cho mọi
          tình huống
        </p>

        <div className="mt-10 w-full max-w-md">
          <WaitlistForm />
        </div>

        <p className="mt-8 text-xs text-zinc-600 sm:text-sm">
          Miễn phí · Không spam · Dành cho Gen Z Việt Nam
        </p>
      </main>

      <footer className="relative z-10 px-6 py-6 text-center text-xs text-zinc-600 sm:px-8">
        © {new Date().getFullYear()} Fitcheck
      </footer>
    </div>
  );
}
