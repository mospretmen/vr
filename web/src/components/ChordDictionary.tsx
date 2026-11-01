// The chord dictionary: pick a root, pick a quality, see every shape the
// book knows — CAGED shapes up the neck, then drop-2 and drop-3 inversions
// on each string set, then guide-tone dyads. Every diagram is playable.
import { useMemo, useState } from "react";
import { strum } from "../audio";
import {
  allQualityFamilies, dropGrip, DROP3_SET_LABELS, DROP3_SETS,
  DYAD_KINDS, DYAD_PAIR_LABELS, DYAD_PAIRS, dyadGrips,
  INVERSION_LABELS, STRING_SET_LABELS, STRING_SETS,
  toneRole, type Grip,
} from "../demoVoicings";

const ROOTS = ["C", "C♯/D♭", "D", "D♯/E♭", "E", "F", "F♯/G♭", "G", "G♯/A♭", "A", "A♯/B♭", "B"];
const OPEN_MIDI = [40, 45, 50, 55, 59, 64];
const ROLE_COLOR = [
  "var(--color-accent-strong)", "#22d3ee", "#4ade80", "#c084fc",
];

function gripMidis(frets: (number | null)[]): number[] {
  return frets.flatMap((f, s) => (f === null ? [] : [OPEN_MIDI[s] + f]));
}

/** One compact diagram, same furniture as every other board in the app. */
function GripBoard({ root, grip, label }: { root: number; grip: Grip; label: string }) {
  const sounded = grip.frets
    .map((f, s) => (f === null ? null : { s, f }))
    .filter((x): x is { s: number; f: number } => x !== null);
  const fretted = sounded.map(({ f }) => f).filter((f) => f > 0);
  const low = fretted.length ? Math.min(...fretted) : 1;
  const start = Math.max(1, Math.min(low, 11));
  const W = 150;
  const H = 96;
  const left = 20;
  const gap = (W - left - 8) / 5;
  const stringY = (s: number) => 10 + (5 - s) * ((H - 32) / 5);
  const fretX = (f: number) => left + (f - start + 1) * gap;
  const noteX = (f: number) => (f === 0 ? left - 10 : fretX(f) - gap / 2);
  const INLAYS = new Set([3, 5, 7, 9, 15, 17, 19, 21]);
  return (
    <button
      onClick={() => strum(gripMidis(grip.frets))}
      className="group rounded-lg border border-line p-2 text-left transition-colors hover:border-accent/50"
    >
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full">
        <defs>
          <linearGradient id="gd-wood" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#422617" />
            <stop offset="0.5" stopColor="#5c3821" />
            <stop offset="1" stopColor="#4d2e1c" />
          </linearGradient>
        </defs>
        <rect x={left} y={4} width={W - left - 4} height={H - 20} rx={4}
          fill="url(#gd-wood)" stroke="rgba(0,0,0,0.4)" />
        {start === 1 && (
          <rect x={left - 3} y={4} width={5} height={H - 20} rx={2} fill="#ded9cc" />
        )}
        {[0, 1, 2, 3, 4, 5].map((i) => (
          <line key={i} x1={fretX(start + i)} y1={5} x2={fretX(start + i)}
            y2={H - 17} stroke="rgba(210,210,214,0.7)" strokeWidth={1.5} />
        ))}
        {[0, 1, 2, 3, 4].map((i) => {
          const f = start + i;
          if (!INLAYS.has(f) && f !== 12) return null;
          const cx = fretX(f) - gap / 2;
          const cy = (4 + H - 16) / 2;
          return f === 12 ? (
            <g key={f}>
              <circle cx={cx} cy={cy - 9} r={2.2} fill="rgba(250,250,250,0.25)" />
              <circle cx={cx} cy={cy + 9} r={2.2} fill="rgba(250,250,250,0.25)" />
            </g>
          ) : (
            <circle key={f} cx={cx} cy={cy} r={2.2} fill="rgba(250,250,250,0.25)" />
          );
        })}
        {[0, 1, 2, 3, 4, 5].map((s) => (
          <line key={s} x1={left - 3} y1={stringY(s)} x2={W - 6} y2={stringY(s)}
            stroke={s < 3 ? "#9d9588" : "#c9c7bd"} strokeWidth={1.9 - s * 0.22}
            opacity={0.85} />
        ))}
        {grip.frets.map((f, s) =>
          f === null ? (
            <text key={s} x={left - 11} y={stringY(s) + 2.6} fontSize={8}
              fill="var(--color-ink-mute)" textAnchor="middle">×</text>
          ) : null)}
        {sounded.map(({ s, f }) => {
          const role = toneRole({ root }, s, f);
          return (
            <g key={s}>
              <circle cx={noteX(f)} cy={stringY(s)} r={6.4} fill={ROLE_COLOR[role]} />
              <text x={noteX(f)} y={stringY(s) + 2.4} textAnchor="middle"
                fontSize={6.6} fontWeight={700} fill="#1a1208">
                {["R", "3", "5", "7"][role]}
              </text>
            </g>
          );
        })}
        <text x={fretX(start) - gap / 2} y={H - 3} textAnchor="middle"
          fontSize={8} fill="var(--color-ink-mute)">{start}</text>
      </svg>
      <div className="mt-1 truncate text-center text-[10px] text-ink-mute group-hover:text-ink-dim">
        {label}
      </div>
    </button>
  );
}

export function ChordDictionary() {
  const [root, setRoot] = useState(0);
  const [qualityIndex, setQualityIndex] = useState(0);
  const families = useMemo(() => allQualityFamilies(root), [root]);
  const family = families[Math.min(qualityIndex, families.length - 1)];
  const rootName = ROOTS[root].split("/")[0];
  const symbol = `${rootName}${family?.suffix ?? ""}`;

  const drop2 = useMemo(() => {
    if (!family?.seventhIntervals) return [];
    return STRING_SETS.map((set, si) =>
      INVERSION_LABELS.map((_, inv) =>
        dropGrip(root, family.seventhIntervals!, set, inv, 2))
        .map((g, inv) => ({ g, inv, si })));
  }, [family, root]);
  const drop3 = useMemo(() => {
    if (!family?.seventhIntervals) return [];
    return DROP3_SETS.map((set, si) =>
      INVERSION_LABELS.map((_, inv) =>
        dropGrip(root, family.seventhIntervals!, set, inv, 3))
        .map((g, inv) => ({ g, inv, si })));
  }, [family, root]);

  return (
    <div className="mx-auto flex h-full w-full max-w-6xl gap-5">
      {/* Quality rail */}
      <aside className="no-scrollbar hidden w-40 shrink-0 overflow-y-auto border-r border-line pr-2 lg:block">
        <div className="pb-1 pt-2 text-[10px] font-semibold uppercase tracking-[0.16em] text-ink-mute">
          Quality
        </div>
        {families.map((f, i) => (
          <button
            key={f.suffix || "major"}
            onClick={() => setQualityIndex(i)}
            className={`block w-full border-l-2 px-3 py-1.5 text-left text-sm transition-colors ${
              i === Math.min(qualityIndex, families.length - 1)
                ? "border-accent text-ink"
                : "border-transparent text-ink-mute hover:text-ink-dim"
            }`}
          >
            {rootName}{f.suffix}
          </button>
        ))}
      </aside>

      <div className="no-scrollbar min-w-0 flex-1 overflow-y-auto pb-8">
        {/* Root pills */}
        <div className="flex flex-wrap items-center gap-1 pt-1">
          <span className="mr-2 text-[11px] font-medium uppercase tracking-[0.14em] text-ink-mute">
            Root
          </span>
          {ROOTS.map((name, pc) => (
            <button
              key={pc}
              onClick={() => setRoot(pc)}
              className={`rounded-md px-2 py-1 text-sm font-medium transition-colors ${
                root === pc ? "bg-accent text-accent-deep" : "text-ink-mute hover:text-ink"
              }`}
            >
              {name}
            </button>
          ))}
        </div>
        {/* Mobile quality picker */}
        <select
          value={Math.min(qualityIndex, families.length - 1)}
          onChange={(e) => setQualityIndex(Number(e.target.value))}
          className="mt-3 rounded-md border border-line bg-transparent px-2 py-1.5 text-sm text-ink lg:hidden"
        >
          {families.map((f, i) => (
            <option key={f.suffix || "major"} value={i}>{rootName}{f.suffix}</option>
          ))}
        </select>

        <h2 className="mt-4 font-display text-2xl font-semibold text-ink">{symbol}</h2>
        <p className="mt-0.5 text-sm text-ink-dim">
          Every shape is playable — tap a diagram to hear it, low string to high.
        </p>

        {family && family.grips.length > 0 && (
          <>
            <h3 className="mt-6 text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-mute">
              Shapes up the neck
            </h3>
            <div className="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-4">
              {family.grips.map((g, i) => (
                <GripBoard key={i} root={root} grip={g} label={`${symbol} · ${g.positionLabel}`} />
              ))}
            </div>
          </>
        )}

        {family?.seventhIntervals && (
          <>
            <h3 className="mt-8 text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-mute">
              Drop-2 inversions — by string set
            </h3>
            {drop2.map((row, si) => (
              <div key={si} className="mt-3">
                <div className="text-xs text-ink-dim">strings {STRING_SET_LABELS[si]}</div>
                <div className="mt-1.5 grid grid-cols-2 gap-2 sm:grid-cols-4">
                  {row.map(({ g, inv }) =>
                    g ? (
                      <GripBoard key={inv} root={root} grip={g}
                        label={INVERSION_LABELS[inv]} />
                    ) : (
                      <div key={inv} className="rounded-lg border border-dashed border-line p-2 text-center text-[10px] text-ink-mute">
                        no one-position<br />{INVERSION_LABELS[inv]}
                      </div>
                    ))}
                </div>
              </div>
            ))}

            <h3 className="mt-8 text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-mute">
              Drop-3 inversions — by string set
            </h3>
            {drop3.map((row, si) => (
              <div key={si} className="mt-3">
                <div className="text-xs text-ink-dim">strings {DROP3_SET_LABELS[si]}</div>
                <div className="mt-1.5 grid grid-cols-2 gap-2 sm:grid-cols-4">
                  {row.map(({ g, inv }) =>
                    g ? (
                      <GripBoard key={inv} root={root} grip={g}
                        label={INVERSION_LABELS[inv]} />
                    ) : (
                      <div key={inv} className="rounded-lg border border-dashed border-line p-2 text-center text-[10px] text-ink-mute">
                        no one-position<br />{INVERSION_LABELS[inv]}
                      </div>
                    ))}
                </div>
              </div>
            ))}

            <h3 className="mt-8 text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-mute">
              Guide-tone dyads
            </h3>
            <div className="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
              {DYAD_KINDS.map((kind) =>
                DYAD_PAIRS.map((pair, pi) => {
                  const grips = dyadGrips(root, family.seventhIntervals!, kind, pair);
                  if (grips.length === 0) return null;
                  return (
                    <GripBoard key={`${kind.label}-${pi}`} root={root} grip={grips[0]}
                      label={`${kind.label} · strings ${DYAD_PAIR_LABELS[pi]}`} />
                  );
                }))}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
