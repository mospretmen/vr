// The chord dictionary: build the chord (root → family → color chips),
// then walk ONE board through every real voicing it has, sorted up the
// neck — the caption says what each voicing is; you never pick systems.
import { useCallback, useEffect, useMemo, useState } from "react";
import { strum } from "../audio";
import { allQualityFamilies, voicingWalk, type Grip } from "../demoVoicings";

const ROOTS = ["C", "C♯/D♭", "D", "D♯/E♭", "E", "F", "F♯/G♭", "G", "G♯/A♭", "A", "A♯/B♭", "B"];
const OPEN_MIDI = [40, 45, 50, 55, 59, 64];

function gripMidis(frets: (number | null)[]): number[] {
  return frets.flatMap((f, s) => (f === null ? [] : [OPEN_MIDI[s] + f]));
}

/** Exact interval figure, chord-aware (♯9 when a major 3rd is present). */
export function figure(semis: number, intervals: number[] | null): string {
  const has = (x: number) => intervals?.includes(x) ?? false;
  switch (semis) {
    case 0: return "R";
    case 1: return "♭9";
    case 2: return "9";
    case 3: return has(4) ? "♯9" : "♭3";
    case 4: return "3";
    case 5: return has(4) || has(3) ? "11" : "4";
    case 6: return has(7) ? "♯11" : "♭5";
    case 7: return "5";
    case 8: return has(7) ? "♭13" : "♯5";
    case 9: return has(10) ? "13" : "6";
    case 10: return "♭7";
    default: return "7";
  }
}

export function figureColor(semis: number): string {
  if (semis === 0) return "var(--color-accent-strong)";
  if (semis === 3 || semis === 4) return "#22d3ee";
  if (semis >= 5 && semis <= 8) return "#4ade80";
  return "#c084fc";
}

/** The one big board. Same furniture as every board in the app. */
function BigBoard({ root, grip, intervals }: {
  root: number; grip: Grip; intervals: number[] | null;
}) {
  const sounded = grip.frets
    .map((f, s) => (f === null ? null : { s, f }))
    .filter((x): x is { s: number; f: number } => x !== null);
  const fretted = sounded.map(({ f }) => f).filter((f) => f > 0);
  const low = fretted.length ? Math.min(...fretted) : 1;
  const start = Math.max(1, Math.min(low, 11));
  const W = 640;
  const H = 230;
  const left = 46;
  const gap = (W - left - 16) / 5;
  const stringY = (s: number) => 24 + (5 - s) * ((H - 72) / 5);
  const fretX = (f: number) => left + (f - start + 1) * gap;
  const noteX = (f: number) => (f === 0 ? left - 22 : fretX(f) - gap / 2);
  const INLAYS = new Set([3, 5, 7, 9, 15, 17, 19, 21]);
  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full select-none">
      <defs>
        <linearGradient id="bb-wood" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#422617" />
          <stop offset="0.5" stopColor="#5c3821" />
          <stop offset="1" stopColor="#4d2e1c" />
        </linearGradient>
      </defs>
      <rect x={left} y={10} width={W - left - 10} height={H - 48} rx={8}
        fill="url(#bb-wood)" stroke="rgba(0,0,0,0.4)" />
      {start === 1 && (
        <rect x={left - 7} y={10} width={8} height={H - 48} rx={3} fill="#ded9cc" />
      )}
      {[0, 1, 2, 3, 4, 5].map((i) => (
        <line key={i} x1={fretX(start + i)} y1={12} x2={fretX(start + i)}
          y2={H - 40} stroke="rgba(210,210,214,0.7)" strokeWidth={2.4} />
      ))}
      {[0, 1, 2, 3, 4].map((i) => {
        const f = start + i;
        if (!INLAYS.has(f) && f !== 12) return null;
        const cx = fretX(f) - gap / 2;
        const cy = (10 + H - 38) / 2;
        return f === 12 ? (
          <g key={f}>
            <circle cx={cx} cy={cy - 26} r={5} fill="rgba(250,250,250,0.25)" />
            <circle cx={cx} cy={cy + 26} r={5} fill="rgba(250,250,250,0.25)" />
          </g>
        ) : (
          <circle key={f} cx={cx} cy={cy} r={5} fill="rgba(250,250,250,0.25)" />
        );
      })}
      {[0, 1, 2, 3, 4, 5].map((s) => (
        <line key={s} x1={left - 7} y1={stringY(s)} x2={W - 12} y2={stringY(s)}
          stroke={s < 3 ? "#9d9588" : "#c9c7bd"} strokeWidth={3.6 - s * 0.42}
          opacity={0.85} />
      ))}
      {grip.frets.map((f, s) =>
        f === null ? (
          <text key={s} x={left - 24} y={stringY(s) + 5} fontSize={15}
            fill="var(--color-ink-mute)" textAnchor="middle">×</text>
        ) : null)}
      {sounded.map(({ s, f }) => {
        const semis = ((OPEN_MIDI[s] + f) % 12 - root + 12) % 12;
        return (
          <g key={s}>
            <circle cx={noteX(f)} cy={stringY(s)} r={14.5}
              fill={figureColor(semis)} />
            <text x={noteX(f)} y={stringY(s) + 4.6} textAnchor="middle"
              fontSize={11.5} fontWeight={700} fill="#1a1208">
              {figure(semis, intervals)}
            </text>
          </g>
        );
      })}
      {[0, 1, 2, 3, 4].map((i) => (
        <text key={i} x={fretX(start + i) - gap / 2} y={H - 16}
          textAnchor="middle" fontSize={13} fill="var(--color-ink-mute)"
          className="tabular-nums">
          {start + i}
        </text>
      ))}
    </svg>
  );
}

// ---- The builder: family + extension chips → chord suffix ----

type BuilderFamily = "Major" | "Minor" | "Dominant" | "Diminished";

const FAMILY_CHIPS: Record<BuilderFamily, string[]> = {
  Major: ["6", "maj7", "9", "13", "♯11", "♯5", "sus2", "sus4"],
  Minor: ["6", "7", "maj7", "9", "11", "13"],
  Dominant: ["9", "13", "♭9", "♯9", "♭5", "♯5", "sus4"],
  Diminished: ["half-dim ♭7"],
};
const COMBOS: Record<BuilderFamily, Record<string, string>> = {
  Major: {
    "": "", "6": "6", "6+9": "6/9", "maj7": "maj7", "9+maj7": "maj9",
    "13+maj7": "maj13", "maj7+♯11": "maj7♯11", "maj7+♯5": "maj7♯5",
    "9": "add9", "sus2": "sus2", "sus4": "sus4",
  },
  Minor: {
    "": "m", "7": "m7", "7+9": "m9", "11+7": "m11", "13+7": "m13",
    "6": "m6", "6+9": "m6/9", "maj7": "m(maj7)", "9+maj7": "m(maj9)",
    "9": "m(add9)",
  },
  Dominant: {
    "": "7", "9": "9", "13": "13", "♭9": "7♭9", "♯9": "7♯9",
    "♭5": "7♭5", "♯5": "7♯5", "9+♭5": "9♭5", "9+♯5": "9♯5",
    "13+♭9": "13♭9", "♭5+♭9": "7♭5♭9", "♭5+♯9": "7♭5♯9",
    "♭9+♯5": "7♯5♭9", "♯5+♯9": "7♯5♯9", "sus4": "7sus4",
    "9+sus4": "9sus4", "13+sus4": "13sus4",
  },
  Diminished: { "": "°7", "half-dim ♭7": "ø7" },
};
function resolveSuffix(family: BuilderFamily, chips: Set<string>): string | null {
  return COMBOS[family][[...chips].sort().join("+")] ?? null;
}

export function ChordDictionary() {
  const [root, setRoot] = useState(0);
  const [builderFamily, setBuilderFamily] = useState<BuilderFamily>("Major");
  const [chips, setChips] = useState<Set<string>>(() => new Set(["maj7"]));
  const [idx, setIdx] = useState(0);

  const families = useMemo(() => allQualityFamilies(root), [root]);
  const suffix = resolveSuffix(builderFamily, chips) ?? "";
  const family = families.find((f) => f.suffix === suffix) ?? families[0];
  const rootName = ROOTS[root].split("/")[0];
  const symbol = `${rootName}${family.suffix}`;

  const toggleChip = (chip: string) => {
    setChips((prev) => {
      const next = new Set(prev);
      if (next.has(chip)) next.delete(chip);
      else next.add(chip);
      return resolveSuffix(builderFamily, next) !== null ? next : prev;
    });
    setIdx(0);
  };
  const chipPossible = (chip: string): boolean => {
    const next = new Set(chips);
    if (next.has(chip)) next.delete(chip);
    else next.add(chip);
    return resolveSuffix(builderFamily, next) !== null;
  };

  const walk = useMemo(
    () => voicingWalk(root, family.seventhIntervals, family.grips),
    [root, family]);
  const bounded = Math.min(idx, Math.max(0, walk.length - 1));
  const current = walk[bounded] ?? null;

  const play = useCallback((g: Grip | null) => {
    if (g) strum(gripMidis(g.frets));
  }, []);

  const step = useCallback((dir: 1 | -1) => {
    if (walk.length === 0) return;
    const next = (bounded + dir + walk.length) % walk.length;
    setIdx(next);
    play(walk[next].grip);
  }, [walk, bounded, play]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLSelectElement) return;
      if (e.key === "ArrowRight") { e.preventDefault(); step(1); }
      if (e.key === "ArrowLeft") { e.preventDefault(); step(-1); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [step]);

  return (
    <div className="mx-auto flex h-full w-full max-w-4xl flex-col">
      <div className="no-scrollbar min-w-0 flex-1 overflow-y-auto pb-8">
        {/* Root pills */}
        <div className="flex flex-wrap items-center gap-1 pt-1">
          {ROOTS.map((name, pc) => (
            <button key={pc} onClick={() => { setRoot(pc); setIdx(0); }}
              className={`rounded-md px-2 py-1 text-sm font-medium transition-colors ${
                root === pc ? "bg-accent text-accent-deep" : "text-ink-mute hover:text-ink"
              }`}>
              {name}
            </button>
          ))}
        </div>

        {/* Family, then the colors that exist for it */}
        <div className="mt-3 flex flex-wrap items-center gap-1.5">
          {(Object.keys(FAMILY_CHIPS) as BuilderFamily[]).map((fam) => (
            <button key={fam}
              onClick={() => {
                setBuilderFamily(fam);
                setChips(new Set());
                setIdx(0);
              }}
              className={`rounded-lg px-3.5 py-1.5 text-sm font-medium transition-colors ${
                builderFamily === fam ? "bg-fill text-ink" : "text-ink-mute hover:text-ink-dim"
              }`}>
              {fam}
            </button>
          ))}
        </div>
        <div className="mt-2 flex flex-wrap items-center gap-1.5">
          <span className="mr-1 text-[11px] font-medium uppercase tracking-[0.14em] text-ink-mute">
            Color it
          </span>
          {FAMILY_CHIPS[builderFamily].map((chip) => {
            const active = chips.has(chip);
            const possible = chipPossible(chip);
            return (
              <button key={chip}
                onClick={() => toggleChip(chip)}
                disabled={!possible}
                className={`rounded-full px-3 py-1 text-xs transition-colors ${
                  active ? "bg-accent text-accent-deep"
                    : possible ? "bg-fill-soft text-ink-dim hover:text-ink"
                    : "bg-fill-soft/40 text-ink-mute/40"
                }`}>
                {chip}
              </button>
            );
          })}
        </div>

        <div className="mt-3 flex flex-wrap items-baseline gap-3">
          <h2 className="font-display text-3xl font-semibold text-ink">{symbol}</h2>
          <span className="text-sm text-ink-dim">{current?.kind ?? ""}</span>
          <span className="text-xs tabular-nums text-ink-mute">
            {walk.length > 0 ? `${bounded + 1} / ${walk.length} voicings` : ""}
          </span>
          {family.rootless && (
            <span className="rounded-full bg-fill-soft px-2.5 py-0.5 text-[11px] text-ink-mute">
              rootless — as played
            </span>
          )}
        </div>

        {/* THE board */}
        <div className="mt-2 flex items-center gap-2">
          <button onClick={() => step(-1)} aria-label="Previous voicing"
                  className="shrink-0 rounded-full bg-fill-soft px-3 py-6 text-lg text-ink-dim hover:text-ink">‹</button>
          <button onClick={() => play(current?.grip ?? null)} className="min-w-0 flex-1"
                  aria-label="Play voicing">
            {current && (
              <BigBoard root={root} grip={current.grip}
                        intervals={family.seventhIntervals} />
            )}
          </button>
          <button onClick={() => step(1)} aria-label="Next voicing"
                  className="shrink-0 rounded-full bg-fill-soft px-3 py-6 text-lg text-ink-dim hover:text-ink">›</button>
        </div>
        <p className="mt-1 text-center text-[11px] text-ink-mute">
          Tap the board to hear it · ‹ › or arrow keys walk the neck, voicing by voicing
        </p>

        {/* Position dots: where you are on the walk */}
        <div className="mt-3 flex flex-wrap justify-center gap-1">
          {walk.map((it, i) => {
            const fretted = it.grip.frets.filter((f): f is number => f !== null && f > 0);
            const pos = fretted.length ? Math.min(...fretted) : 0;
            return (
              <button key={i} onClick={() => { setIdx(i); play(it.grip); }}
                title={`${it.kind} · fret ${pos}`}
                aria-label={`Voicing ${i + 1}`}
                className={`h-2.5 rounded-full transition-all ${
                  i === bounded ? "w-6 bg-accent" : "w-2.5 bg-fill-soft hover:bg-fill"
                }`} />
            );
          })}
        </div>
      </div>
    </div>
  );
}
