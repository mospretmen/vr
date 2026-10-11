import type { ReactNode } from "react";
import { FretboardExplorer } from "./components/FretboardExplorer";
import { HarmonyCompass } from "./components/HarmonyCompass";
import {
  PricingSection,
  VisionProSection,
  WaitlistSection,
} from "./components/VisionShowcase";
import { PracticeStats } from "./components/PracticeStats";
import { TrackLibrary } from "./components/TrackLibrary";

const NAV_LINKS = [
  { label: "Compass", href: "#compass" },
  { label: "Vision Pro", href: "#visionpro" },
  { label: "Explorer", href: "#explorer" },
  { label: "Pricing", href: "#pricing" },
  { label: "Waitlist", href: "#waitlist" },
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

function ThemeToggle() {
  const toggle = () => {
    const el = document.documentElement;
    const systemDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    const current =
      el.dataset.theme ?? (systemDark ? "dark" : "light");
    const next = current === "dark" ? "light" : "dark";
    el.dataset.theme = next;
    try {
      localStorage.setItem("theme", next);
    } catch {
      /* private mode */
    }
  };
  return (
    <button
      onClick={toggle}
      aria-label="Toggle light or dark mode"
      className="rounded-lg border border-line px-2.5 py-1.5 text-sm text-ink-dim transition-colors hover:bg-fill-soft hover:text-ink"
    >
      ◐
    </button>
  );
}

function Nav() {
  return (
    <header className="sticky top-0 z-40 border-b border-line bg-base/70 backdrop-blur-xl">
      <nav className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Wordmark />
        <div className="no-scrollbar flex items-center gap-1 overflow-x-auto sm:gap-2">
          {NAV_LINKS.map(({ label, href }) => (
            <a
              key={href}
              href={href}
              className="rounded-lg px-2.5 py-1.5 text-sm font-medium text-ink-dim transition-colors hover:bg-fill-soft hover:text-ink sm:px-3"
            >
              {label}
            </a>
          ))}
          <ThemeToggle />
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
            Apple Vision Pro · iOS · Web — one theory engine
          </p>
          <h1 className="rise-in rise-in-1 mt-6 font-display text-5xl font-bold tracking-[-0.03em] text-balance sm:text-7xl">
            The map of harmony.
            <br />
            <span className="bg-gradient-to-br from-accent via-accent-strong to-accent/60 bg-clip-text text-transparent">
              In your hands.
            </span>
          </h1>
          <p className="rise-in rise-in-2 mx-auto mt-6 max-w-xl text-base text-pretty text-ink-dim sm:text-lg">
            The Harmony Compass is a navigable map of functional harmony —
            every key, its relative minor, the dominants and diminisheds that
            bind them, and every legal move between. Tap a chord below: hear
            it, and see where music can go.
          </p>
        </div>

        <div id="compass" className="stage-panel rise-in rise-in-3 mx-auto mt-14 max-w-5xl scroll-mt-24 rounded-3xl border border-line p-4 sm:p-6">
          <p className="mb-3 text-center text-[11px] font-medium uppercase tracking-[0.18em] text-ink-mute">
            Live demo — the same graph that drives the Vision Pro app, note for note
          </p>
          <HarmonyCompass />
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
    <div className="group rounded-2xl border border-line bg-raise p-6 transition-colors duration-300 hover:border-accent/30">
      <div className="flex size-10 items-center justify-center rounded-xl border border-line bg-raise-2 text-accent transition-colors duration-300 group-hover:border-accent/30">
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
    title: "The Harmony Compass",
    description:
      "Keys, relative minors, dominants, and diminished families on one wheel — ii–V–I, tritone subs, the dominant chain, passing dims: every pathway drawn, explained, and playable.",
    icon: (
      <svg {...ICON_PROPS}>
        <circle cx="12" cy="12" r="8.5" />
        <circle cx="12" cy="12" r="4.5" opacity="0.5" />
        <path d="M12 3.5v4M12 16.5v4M3.5 12h4M16.5 12h4" opacity="0.6" />
      </svg>
    ),
  },
  {
    title: "Grips as charts print them",
    description:
      "Voicings come from a curated dictionary of published shapes — open classics, barres, shells, drop-2, triads in every inversion — never a shape no hand plays.",
    icon: (
      <svg {...ICON_PROPS}>
        <path d="M4 5v14M9 5v14M14 5v14M19 5v14" opacity="0.4" />
        <circle cx="9" cy="9" r="2.2" fill="currentColor" stroke="none" />
        <circle cx="14" cy="13" r="2.2" fill="currentColor" stroke="none" />
        <circle cx="19" cy="9" r="2.2" fill="currentColor" stroke="none" />
      </svg>
    ),
  },
  {
    title: "Voice leading you can see",
    description:
      "Tap a resolution and watch the voices travel — half-step pulls in green, common tones held — on a staff, with the sound of the move a beat behind your finger.",
    icon: (
      <svg {...ICON_PROPS}>
        <path d="M3 7h18M3 12h18M3 17h18" opacity="0.4" />
        <circle cx="7" cy="12" r="2.2" fill="currentColor" stroke="none" />
        <circle cx="17" cy="7" r="2.2" fill="currentColor" stroke="none" />
        <path d="M9 11l6-3.5" />
      </svg>
    ),
  },
  {
    title: "Scales, modes & alterations",
    description:
      "Twenty scales from Ionian to the altered and symmetric colors, chord-matched and spelled correctly — plus every tension a chord carries, with the sound that covers it.",
    icon: (
      <svg {...ICON_PROPS}>
        <path d="M4 17c2.5-6 5-9 8-9s5.5 3 8 9" />
        <circle cx="12" cy="8" r="1.6" fill="currentColor" stroke="none" />
      </svg>
    ),
  },
];

function Features() {
  return (
    <section className="mx-auto max-w-6xl px-4 py-20 sm:px-6 sm:py-24">
      <div className="max-w-2xl">
        <h2 className="font-display text-3xl font-bold tracking-tight sm:text-4xl">
          A reference that plays back.
        </h2>
        <p className="mt-3 text-base text-ink-dim">
          Every fact is tested, every pathway sounds, every shape comes from
          how guitarists actually play — one engine across Vision Pro, iOS,
          and the web.
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
    <section id={id} className="scroll-mt-20 border-t border-line">
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
    <footer className="border-t border-line">
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
        <VisionProSection />
        <Section
          id="explorer"
          title="Fretboard Explorer"
          description="Scales, modes, and triads rendered on a live fretboard — the web face of the same tested engine."
        >
          <div className="stage-panel rounded-3xl border border-line p-3 sm:p-5">
            <FretboardExplorer />
          </div>
        </Section>
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
        <PricingSection />
        <WaitlistSection />
      </main>
      <Footer />
    </div>
  );
}
