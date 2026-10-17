import { useEffect, useState, type ReactNode } from "react";
import { FretboardExplorer } from "./components/FretboardExplorer";
import { HarmonyCompass } from "./components/HarmonyCompass";
import { ClassicsBrowser, ClassicsShowcase } from "./components/ClassicsShowcase";
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
  { label: "Classics", href: "#classics" },
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

const APP_VIEWS = [
  { hash: "#/compass", label: "Compass" },
  { hash: "#/fretboard", label: "Fretboard" },
  { hash: "#/phrases", label: "Phrases" },
] as const;

function useHashRoute(): string {
  const [hash, setHash] = useState(() => window.location.hash);
  useEffect(() => {
    const onChange = () => setHash(window.location.hash);
    window.addEventListener("hashchange", onChange);
    return () => window.removeEventListener("hashchange", onChange);
  }, []);
  return hash;
}

/** Full-screen app shell v2 — one dark instrument environment, the VR
 *  room translated: integrated top chrome, features filling the viewport. */
function AppShell({ route }: { route: string }) {
  return (
    <div className="stage-panel app-ambient flex h-screen flex-col overflow-hidden">
      <header className="flex h-14 shrink-0 items-center justify-between gap-3 px-4 sm:px-6">
        <a href="#top" onClick={() => { window.location.hash = ""; }}
           className="font-display text-base font-bold tracking-tight text-ink">
          Fret<span className="text-accent">space</span>
        </a>
        <nav className="flex items-center gap-6">
          {APP_VIEWS.map((view) => (
            <a key={view.hash} href={view.hash}
               className={`relative py-1.5 text-sm font-medium transition-colors duration-200 ${
                 route === view.hash ? "text-ink" : "text-ink-mute hover:text-ink-dim"
               }`}>
              {view.label}
              {route === view.hash && (
                <span className="absolute -bottom-0.5 left-0 right-0 mx-auto h-[2px] w-5 rounded-full bg-accent" />
              )}
            </a>
          ))}
        </nav>
        <a href="#waitlist" onClick={() => { window.location.hash = ""; }}
           className="hidden items-center gap-1.5 text-xs text-ink-mute transition-colors hover:text-ink sm:flex">
          <svg width="18" height="12" viewBox="0 0 24 14" fill="none"
               stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
            <path d="M5.5 1.5h13A4 4 0 0 1 22.5 5.5v2a4.5 4.5 0 0 1-4.5 4.5c-2 0-2.8-1-4.2-2.3-.9-.85-2.7-.85-3.6 0C8.8 11 8 12 6 12a4.5 4.5 0 0 1-4.5-4.5v-2a4 4 0 0 1 4-4Z" />
          </svg>
          Get it on Vision&nbsp;Pro
        </a>
      </header>
      <main className="min-h-0 flex-1 overflow-y-auto px-3 pb-3 sm:px-5 sm:pb-5">
        {route === "#/compass" && <HarmonyCompass fill />}
        {route === "#/fretboard" && (
          <div className="h-full overflow-auto pt-2">
            <FretboardExplorer bare />
          </div>
        )}
        {route === "#/phrases" && (
          <div className="h-full overflow-hidden pt-2">
            <ClassicsBrowser fill />
          </div>
        )}
      </main>
    </div>
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

function useActiveSection(ids: string[]): string | null {
  const [active, setActive] = useState<string | null>(null);
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
        if (visible) setActive(visible.target.id);
      },
      { rootMargin: "-20% 0px -60% 0px", threshold: [0, 0.2, 0.5] },
    );
    for (const id of ids) {
      const el = document.getElementById(id);
      if (el) observer.observe(el);
    }
    return () => observer.disconnect();
  }, [ids]);
  return active;
}

function Nav() {
  const active = useActiveSection(NAV_LINKS.map((l) => l.href.slice(1)));
  return (
    <header className="sticky top-0 z-40 bg-base/70 backdrop-blur-xl">
      <nav className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Wordmark />
        <div className="no-scrollbar flex items-center gap-1 overflow-x-auto sm:gap-2">
          {NAV_LINKS.map(({ label, href }) => (
            <a
              key={href}
              href={href}
              className={`rounded-lg px-2.5 py-1.5 text-sm font-medium transition-colors hover:bg-fill-soft hover:text-ink sm:px-3 ${
                active === href.slice(1)
                  ? "bg-fill-soft text-accent"
                  : "text-ink-dim"
              }`}
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

        <div className="rise-in rise-in-2 mt-8 flex flex-wrap items-center justify-center gap-3">
          <a href="#/compass"
             className="rounded-xl bg-accent px-6 py-3 text-sm font-semibold text-accent-deep transition-opacity hover:opacity-90">
            Launch the Compass — free
          </a>
          <a href="#/fretboard"
             className="rounded-xl border border-line px-6 py-3 text-sm font-medium text-ink transition-colors hover:bg-fill-soft">
            Fretboard
          </a>
          <a href="#/phrases"
             className="rounded-xl border border-line px-6 py-3 text-sm font-medium text-ink transition-colors hover:bg-fill-soft">
            Phrases
          </a>
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

function VideoSection() {
  return (
    <section className="border-t border-line">
      <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <h2 className="font-display text-2xl font-bold tracking-tight sm:text-3xl">
          Watch it move.
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-ink-dim sm:text-base">
          Straight screen capture from the visionOS build — the compass and
          its windows opening in the room.
        </p>
        <video
          className="mt-8 w-full rounded-2xl border border-line"
          src="/media/tour.mp4"
          poster="/media/shot-compass.jpg"
          controls
          muted
          playsInline
          preload="metadata"
        />
      </div>
    </section>
  );
}

const SHOTS = [
  {
    src: "/media/shot-compass.jpg",
    alt: "The Harmony Compass floating in a living room through Apple Vision Pro",
    caption: "The compass in the room — C selected, its pathways blazing, the rest a whisper.",
  },
  {
    src: "/media/shot-windows.jpg",
    alt: "Scale and chord windows open beside the compass in Apple Vision Pro",
    caption: "Tap a scale or a grip and it opens beside the wheel — staff, degrees, rosewood neck.",
  },
  {
    src: "/media/shot-3d.jpg",
    alt: "The volumetric 3D compass next to the 2D wheel in Apple Vision Pro",
    caption: "The volumetric compass: keys nearest, dominants behind, diminisheds deepest.",
  },
];

function GallerySection() {
  const [expanded, setExpanded] = useState<string | null>(null);
  return (
    <section id="gallery" className="scroll-mt-20 border-t border-line">
      <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <h2 className="font-display text-2xl font-bold tracking-tight sm:text-3xl">
          Seen through the headset.
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-ink-dim sm:text-base">
          Straight captures from the visionOS build — no mockups.
        </p>
        <div className="mt-8 grid gap-4 lg:grid-cols-3">
          {SHOTS.map((shot) => (
            <figure
              key={shot.src}
              className="overflow-hidden rounded-2xl border border-line bg-raise"
            >
              <button
                onClick={() => setExpanded(shot.src)}
                className="block w-full cursor-zoom-in"
                aria-label={`Expand: ${shot.alt}`}
              >
                <img
                  src={shot.src}
                  alt={shot.alt}
                  loading="lazy"
                  className="aspect-video w-full object-cover"
                />
              </button>
              <figcaption className="p-4 text-xs leading-relaxed text-ink-dim">
                {shot.caption}
              </figcaption>
            </figure>
          ))}
        </div>
        {expanded && (
          <button
            className="fixed inset-0 z-50 flex cursor-zoom-out items-center justify-center bg-black/85 p-4 sm:p-10"
            onClick={() => setExpanded(null)}
            aria-label="Close expanded screenshot"
          >
            <img
              src={expanded}
              alt="Expanded screenshot"
              className="max-h-full max-w-full rounded-xl shadow-2xl"
            />
          </button>
        )}
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
  const route = useHashRoute();
  if (APP_VIEWS.some((v) => v.hash === route)) {
    return <AppShell route={route} />;
  }
  return (
    <div id="top" className="min-h-screen">
      <Nav />
      <main>
        <Hero />
        <Features />
        <VisionProSection />
        <ClassicsShowcase />
        <VideoSection />
        <GallerySection />
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
