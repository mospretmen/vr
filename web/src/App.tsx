import type { ReactNode } from "react";
import { FretboardExplorer } from "./components/FretboardExplorer";
import { PracticeStats } from "./components/PracticeStats";
import { TrackLibrary } from "./components/TrackLibrary";

const NAV_LINKS = [
  { label: "Explorer", href: "#explorer" },
  { label: "Library", href: "#library" },
  { label: "Stats", href: "#stats" },
] as const;

function Wordmark() {
  return (
    <a
      href="#top"
      className="font-display text-lg font-bold tracking-tight text-ink"
    >
      Fret<span className="text-accent">space</span>
    </a>
  );
}

function Nav() {
  return (
    <header className="sticky top-0 z-40 border-b border-white/10 bg-base/70 backdrop-blur-xl">
      <nav className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Wordmark />
        <div className="flex items-center gap-1 sm:gap-2">
          {NAV_LINKS.map(({ label, href }) => (
            <a
              key={href}
              href={href}
              className="rounded-lg px-2.5 py-1.5 text-sm font-medium text-ink-dim transition-colors hover:bg-white/5 hover:text-ink sm:px-3"
            >
              {label}
            </a>
          ))}
        </div>
      </nav>
    </header>
  );
}

function Hero() {
  return (
    <section className="hero-field relative overflow-hidden">
      <div
        aria-hidden="true"
        className="hero-grid pointer-events-none absolute inset-0"
      />
      <div className="relative mx-auto max-w-6xl px-4 pt-20 pb-14 sm:px-6 sm:pt-28">
        <div className="mx-auto max-w-3xl text-center">
          <p className="rise-in inline-flex items-center gap-2 rounded-full border border-accent/25 bg-accent-strong/10 px-3.5 py-1.5 text-xs font-medium tracking-wide text-accent">
            <span
              aria-hidden="true"
              className="size-1.5 rounded-full bg-accent"
            />
            Coming to the App Store for Apple Vision Pro
          </p>
          <h1 className="rise-in rise-in-1 mt-6 font-display text-5xl font-bold tracking-[-0.03em] text-balance sm:text-7xl">
            See the fretboard.
            <br />
            <span className="bg-gradient-to-br from-accent via-accent-strong to-accent/60 bg-clip-text text-transparent">
              In the room.
            </span>
          </h1>
          <p className="rise-in rise-in-2 mx-auto mt-6 max-w-xl text-base text-pretty text-ink-dim sm:text-lg">
            Fretspace locks scales, modes, and triads onto your real guitar
            through Apple Vision Pro — every note of the shape glowing on the
            neck in your hands, not on a screen across the room.
          </p>
        </div>

        <div id="explorer" className="rise-in rise-in-3 mx-auto mt-14 max-w-5xl scroll-mt-24">
          <p className="mb-3 text-center text-[11px] font-medium uppercase tracking-[0.18em] text-ink-mute">
            Live demo — the same engine that drives the headset overlay
          </p>
          <FretboardExplorer />
        </div>
      </div>
    </section>
  );
}

interface FeatureProps {
  title: string;
  description: string;
  icon: ReactNode;
}

function FeatureCard({ title, description, icon }: FeatureProps) {
  return (
    <div className="group rounded-2xl border border-white/10 bg-raise p-6 transition-colors duration-300 hover:border-accent/30">
      <div className="flex size-10 items-center justify-center rounded-xl border border-white/10 bg-raise-2 text-accent transition-colors duration-300 group-hover:border-accent/30">
        {icon}
      </div>
      <h3 className="mt-4 font-display text-base font-semibold text-ink">
        {title}
      </h3>
      <p className="mt-2 text-sm leading-relaxed text-ink-dim">{description}</p>
    </div>
  );
}

const ICON_PROPS = {
  width: 20,
  height: 20,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.6,
  strokeLinecap: "round",
  strokeLinejoin: "round",
  "aria-hidden": true,
} as const;

const FEATURES: FeatureProps[] = [
  {
    title: "Overlay on your real guitar",
    description:
      "Two pinches — nut, then 12th fret — and the shape is locked to your actual neck in about 30 seconds. Any guitar, any scale length.",
    icon: (
      <svg {...ICON_PROPS}>
        <circle cx="12" cy="12" r="7.5" />
        <circle cx="12" cy="12" r="1.4" fill="currentColor" stroke="none" />
        <path d="M12 1.5v4M12 18.5v4M1.5 12h4M18.5 12h4" />
      </svg>
    ),
  },
  {
    title: "Scales, modes, triads & inversions",
    description:
      "Twelve scales and modes, triads in every quality and inversion — roles color-coded on the neck so your eyes learn the shapes, not the diagrams.",
    icon: (
      <svg {...ICON_PROPS}>
        <path d="M3 7h18M3 12h18M3 17h18" opacity="0.45" />
        <circle cx="7" cy="7" r="2.4" fill="currentColor" stroke="none" />
        <circle cx="13" cy="12" r="2.4" fill="currentColor" stroke="none" />
        <circle cx="17" cy="17" r="2.4" fill="currentColor" stroke="none" />
      </svg>
    ),
  },
  {
    title: "Drills that hear you play",
    description:
      "The headset listens as you practice, matching what you fret against the target chord in real time — no cable, no pedal, no interface.",
    icon: (
      <svg {...ICON_PROPS}>
        <path d="M4 10v4M8 7v10M12 4v16M16 8v8M20 10.5v3" />
      </svg>
    ),
  },
  {
    title: "Backing progressions",
    description:
      "Play over a chord timeline that drives the overlay: as the progression moves, the highlighted shape moves with it, a beat ahead of the change.",
    icon: (
      <svg {...ICON_PROPS}>
        <rect x="3" y="9" width="6.5" height="6" rx="1.6" />
        <rect x="11" y="9" width="4.5" height="6" rx="1.6" />
        <rect x="17" y="9" width="4" height="6" rx="1.6" />
        <path d="M3 4.5h18M3 19.5h18" opacity="0.35" />
      </svg>
    ),
  },
];

function Features() {
  return (
    <section className="mx-auto max-w-6xl px-4 py-20 sm:px-6 sm:py-24">
      <div className="max-w-2xl">
        <h2 className="font-display text-3xl font-bold tracking-tight sm:text-4xl">
          Practice in the space the music happens.
        </h2>
        <p className="mt-3 text-base text-ink-dim">
          Not another fretboard app behind glass. Fretspace puts the theory on
          the instrument itself.
        </p>
      </div>
      <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {FEATURES.map((feature) => (
          <FeatureCard key={feature.title} {...feature} />
        ))}
      </div>
    </section>
  );
}

interface SectionHeadingProps {
  id: string;
  title: string;
  description: string;
  children: ReactNode;
}

function Section({ id, title, description, children }: SectionHeadingProps) {
  return (
    <section id={id} className="scroll-mt-20 border-t border-white/10">
      <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <h2 className="font-display text-2xl font-bold tracking-tight sm:text-3xl">
          {title}
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-ink-dim sm:text-base">
          {description}
        </p>
        <div className="mt-8">{children}</div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="border-t border-white/10">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-4 py-8 sm:px-6">
        <Wordmark />
        <p className="text-xs text-ink-mute">© 2026 Fretspace</p>
      </div>
    </footer>
  );
}

export default function App() {
  return (
    <div id="top" className="min-h-screen">
      <Nav />
      <main>
        <Hero />
        <Features />
        <Section
          id="library"
          title="Track Library"
          description="Backing tracks with chord timelines, synced to the in-headset overlay. Expand a track to read its progression."
        >
          <div className="max-w-3xl">
            <TrackLibrary />
          </div>
        </Section>
        <Section
          id="stats"
          title="Practice Stats"
          description="Your Vision Pro logs every session under an anonymous device ID. Paste it here to see streaks and time on the fretboard."
        >
          <div className="max-w-xl">
            <PracticeStats />
          </div>
        </Section>
      </main>
      <Footer />
    </div>
  );
}
