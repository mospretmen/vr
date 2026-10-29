// The live Harmony Compass demo — the showcase heart of the landing page.
// A faithful 2D rendering of the visionOS compass: tap any chord, hear it,
// and watch its legal departures light up over the quiet lattice.
import { useEffect, useMemo, useState } from "react";
import {
  ALL_MOVES,
  ALL_NODES,
  SPOKES,
  chordPitchClasses,
  describe,
  functionalLabel,
  gradedPairs,
  movesFrom,
  node,
  type CompassNode,
  type Move,
  type MoveKind,
} from "../compass";
import {
  DROP3_SET_LABELS,
  DROP3_SETS,
  dropGrip,
  DYAD_KINDS,
  DYAD_PAIR_LABELS,
  DYAD_PAIRS,
  dyadGrips,
  gripFamilies,
  INVERSION_LABELS,
  STRING_SET_LABELS,
  STRING_SETS,
  scaleSuggestions,
  spellScale,
  toneRole,
  type Grip,
} from "../demoVoicings";
import { voiceMoves } from "../voiceLeading";
import { degreeCells } from "../degreeCells";
import { playProgression, playRun, strum } from "../audio";

const SIZE = 720;
const CENTER = SIZE / 2;
const RIM = 290;
const DOMINANT_R = RIM * 0.62;
const HUB_R = RIM * 0.34;
const PAIR_NUDGE = ((Math.PI * 2) / 12) * 0.21;

const CHIP_RADIUS: Record<string, number> = {
  majorKey: 25,
  relativeMinor: 21,
  dominant: 22,
  diminished: 16,
};

const KIND_COLOR: Record<MoveKind, string> = {
  resolve: "#4ade80",
  deceptive: "#4ade80",
  toDominant: "#fb923c",
  twoFive: "#5eead4",
  soften: "#22d3ee",
  tritoneSub: "#f472b6",
  backdoor: "#facc15",
  fifthSharpward: "#60a5fa",
  fifthFlatward: "#60a5fa",
  relative: "#e2e8f0",
  mediant: "#cbd5e1",
  passingDim: "#c084fc",
  deepen: "#c084fc",
  dimFamily: "#c084fc",
};

function chipFill(ring: CompassNode["ring"], familyIndex: number): string {
  switch (ring) {
    case "majorKey":
      return "#2f66d0";
    case "relativeMinor":
      return "#4747b8";
    case "dominant":
      return "#b97718";
    case "diminished":
      return ["#8d4bb2", "#a0529b", "#7a55c2"][familyIndex % 3];
  }
}

function position(n: CompassNode): { x: number; y: number } {
  const spoke = -Math.PI / 2 + (n.index * Math.PI * 2) / 12;
  let angle = spoke;
  let radius: number;
  switch (n.ring) {
    case "majorKey":
      angle = spoke - PAIR_NUDGE;
      radius = RIM;
      break;
    case "relativeMinor":
      angle = spoke + PAIR_NUDGE;
      radius = RIM;
      break;
    case "dominant":
      radius = DOMINANT_R;
      break;
    case "diminished":
      radius = HUB_R;
      break;
  }
  return {
    x: CENTER + Math.cos(angle) * radius,
    y: CENTER + Math.sin(angle) * radius,
  };
}

/** Straight chip-border-to-chip-border segment with a slight inward bow. */
function edgePath(a: CompassNode, b: CompassNode): string {
  const pa = position(a);
  const pb = position(b);
  const dx = pb.x - pa.x;
  const dy = pb.y - pa.y;
  const len = Math.hypot(dx, dy) || 1;
  const ux = dx / len;
  const uy = dy / len;
  const start = {
    x: pa.x + ux * (CHIP_RADIUS[a.ring] + 3),
    y: pa.y + uy * (CHIP_RADIUS[a.ring] + 3),
  };
  const end = {
    x: pb.x - ux * (CHIP_RADIUS[b.ring] + 7),
    y: pb.y - uy * (CHIP_RADIUS[b.ring] + 7),
  };
  const mid = { x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 };
  const control = {
    x: mid.x + (CENTER - mid.x) * 0.14,
    y: mid.y + (CENTER - mid.y) * 0.14,
  };
  return `M ${start.x} ${start.y} Q ${control.x} ${control.y} ${end.x} ${end.y}`;
}

/** Unique unordered pairs of the whole lattice, for the resting web. */
function latticePairs(): [CompassNode, CompassNode][] {
  const seen = new Set<string>();
  const pairs: [CompassNode, CompassNode][] = [];
  for (const m of ALL_MOVES) {
    const key = [m.from.id, m.to.id].sort().join("|");
    if (!seen.has(key)) {
      seen.add(key);
      pairs.push([m.from, m.to]);
    }
  }
  return pairs;
}

/** Chord voicing for the pads: root in octave 3, tones in octave 4. */
function chordMidis(n: CompassNode): number[] {
  return [n.root + 48, ...chordPitchClasses(n).map((pc) => pc + 60)];
}

export function HarmonyCompass({ fill = false, wheelOnly = false }: {
  fill?: boolean; wheelOnly?: boolean;
} = {}) {
  // Key frame, selection and walk persist like the headset's compass.
  const [selected, setSelected] = useState<CompassNode>(() => {
    try {
      const raw = localStorage.getItem("hc-selected");
      if (raw) {
        const [ring, index] = JSON.parse(raw) as [CompassNode["ring"], number];
        return node(ring, index);
      }
    } catch { /* fresh start */ }
    return node("majorKey", 0);
  });
  const [frameTonic, setFrameTonic] = useState(() => {
    try { return Number(localStorage.getItem("hc-tonic") ?? 0) || 0; } catch { return 0; }
  });
  const [frameMinor, setFrameMinor] = useState(() => {
    try { return localStorage.getItem("hc-minor") === "1"; } catch { return false; }
  });
  const [path, setPath] = useState<CompassNode[]>(() => {
    try {
      const raw = localStorage.getItem("hc-path");
      if (raw) {
        const refs = JSON.parse(raw) as [CompassNode["ring"], number][];
        if (refs.length > 0) return refs.map(([r, i]) => node(r, i));
      }
    } catch { /* fresh start */ }
    return [node("majorKey", 0)];
  });
  useEffect(() => {
    try {
      localStorage.setItem("hc-selected", JSON.stringify([selected.ring, selected.index]));
      localStorage.setItem("hc-tonic", String(frameTonic));
      localStorage.setItem("hc-minor", frameMinor ? "1" : "0");
      localStorage.setItem("hc-path", JSON.stringify(path.map((n) => [n.ring, n.index])));
    } catch { /* private mode */ }
  }, [selected, frameTonic, frameMinor, path]);
  const lattice = useMemo(latticePairs, []);
  const moves = useMemo(() => movesFrom(selected), [selected]);
  // The 2D app's grammar: a three-hop web, blaze → glow → whisper.
  const web = useMemo(
    () => gradedPairs(selected).sort((a, b) => b.depth - a.depth),
    [selected],
  );
  const litIds = useMemo(
    () => new Set(moves.flatMap((m) => [m.from.id, m.to.id])),
    [moves],
  );

  const tap = (n: CompassNode) => {
    const wasDestination = moves.some((m) => m.to.id === n.id);
    setSelected(n);
    setPath((p) => (wasDestination ? [...p, n] : [n]));
    if (n.ring === "majorKey" || n.ring === "relativeMinor") {
      setFrameTonic(n.root);
      setFrameMinor(n.ring === "relativeMinor");
    }
    strum(chordMidis(n));
  };

  const playWalk = () => {
    playProgression(path.map(chordMidis));
    path.forEach((n, i) => {
      setTimeout(() => setSelected(n), i * 850);
    });
  };

  const arpeggiate = (grip: Grip) => {
    const midis = grip.frets
      .map((f, s) => (f === null ? null : 40 + [0, 5, 10, 15, 19, 24][s] + f))
      .filter((m): m is number => m !== null);
    playRun(midis, 0.13);
  };

  return (
    <div className={wheelOnly
        ? "w-full"
        : fill
        ? "mx-auto w-full max-w-[1680px] max-lg:space-y-4 lg:flex lg:h-full lg:min-h-0 lg:flex-row lg:gap-3"
        : "flex flex-col items-start gap-6 lg:flex-row"}>
      <div className={fill
          ? "flex min-w-0 items-center justify-center lg:min-h-0 lg:flex-1"
          : "contents"}>
      <svg
        viewBox={`0 0 ${SIZE} ${SIZE}`}
        className={wheelOnly
            ? "h-auto w-full select-none"
            : fill
            ? "max-w-full select-none max-lg:h-auto max-lg:w-full lg:h-full lg:max-h-full lg:w-auto"
            : "w-full max-w-[640px] flex-1 select-none"}
        role="img"
        aria-label="Interactive Harmony Compass"
      >
        <defs>
          {Object.entries(KIND_COLOR).flatMap(([kind, color]) => [
            <marker
              key={`h-${kind}`}
              id={`head-${kind}`}
              viewBox="0 0 10 10"
              refX="8"
              refY="5"
              markerWidth="5.5"
              markerHeight="5.5"
              orient="auto-start-reverse"
            >
              <path d="M 0 0 L 10 5 L 0 10 z" fill={color} />
            </marker>,
            <marker
              key={`t-${kind}`}
              id={`tail-${kind}`}
              viewBox="0 0 10 10"
              refX="8"
              refY="5"
              markerWidth="3.6"
              markerHeight="3.6"
              orient="auto-start-reverse"
            >
              <path d="M 0 0 L 10 5 L 0 10 z" fill={color} />
            </marker>,
          ])}
        </defs>

        {/* resting lattice */}
        {lattice.map(([a, b]) => (
          <path
            key={`${a.id}|${b.id}`}
            d={edgePath(a, b)}
            stroke="rgba(255,255,255,0.05)"
            strokeWidth={1}
            fill="none"
          />
        ))}

        {/* graded three-hop web, pair-collapsed; resolution owns the head */}
        {web.map(({ move: m, depth, twoWay }, i) => {
          const look = { 1: [0.95, 2.4], 2: [0.28, 1.3], 3: [0.08, 0.7] }[depth]!;
          return (
            <path
              key={i}
              d={edgePath(m.from, m.to)}
              stroke={KIND_COLOR[m.kind]}
              strokeWidth={look[1]}
              strokeDasharray={m.kind === "deceptive" ? "8 6" : undefined}
              fill="none"
              markerEnd={depth < 3 ? `url(#head-${m.kind})` : undefined}
              markerStart={depth === 1 && twoWay ? `url(#tail-${m.kind})` : undefined}
              opacity={look[0]}
            />
          );
        })}

        {/* selection halo */}
        {(() => {
          const p = position(selected);
          return (
            <circle
              cx={p.x}
              cy={p.y}
              r={CHIP_RADIUS[selected.ring] + 6}
              fill="none"
              stroke="rgba(255,255,255,0.65)"
              strokeWidth={1.5}
            />
          );
        })()}

        {/* chips */}
        {ALL_NODES.map((n) => {
          const p = position(n);
          const r = CHIP_RADIUS[n.ring];
          const isSelected = n.id === selected.id;
          const lit = litIds.has(n.id);
          return (
            <g
              key={n.id}
              onClick={() => tap(n)}
              className="cursor-pointer transition-opacity duration-200 hover:opacity-100"
              opacity={isSelected || lit ? 1 : 0.55}
            >
              <circle
                cx={p.x}
                cy={p.y}
                r={r}
                fill={chipFill(n.ring, n.root % 3)}
                stroke={isSelected ? "#fff" : "rgba(255,255,255,0.25)"}
                strokeWidth={isSelected ? 2.5 : 1}
              />
              <text
                x={p.x}
                y={p.y + 1}
                textAnchor="middle"
                dominantBaseline="middle"
                fill="#fff"
                fontSize={n.ring === "diminished" ? 9.5 : 12}
                fontWeight={600}
              >
                {functionalLabel(n, frameTonic)}
              </text>
            </g>
          );
        })}
      </svg>

      </div>
      {/* teaching card */}
      {!wheelOnly && (
      <div className={fill
          ? "flex w-full shrink-0 flex-col gap-0 border-line lg:h-full lg:min-h-0 lg:w-[460px] lg:overflow-hidden lg:border-l lg:pl-5"
          : "flex w-full max-w-md shrink-0 flex-col gap-3"}>
      <div className={fill
          ? "border-b border-line p-3 text-xs"
          : "rounded-2xl border border-line bg-fill-soft p-3 text-xs"}>
        <div className="flex items-center gap-2">
          <span className="text-ink-dim">Key</span>
          <select
            value={frameTonic}
            onChange={(e) => {
              const column = SPOKES.indexOf(
                Number(e.target.value) as (typeof SPOKES)[number],
              );
              tap(node(frameMinor ? "relativeMinor" : "majorKey", column));
            }}
            className="rounded-md border border-line bg-transparent px-2 py-1 text-ink"
            aria-label="Key center"
          >
            {SPOKES.map((pc) => (
              <option key={pc} value={frameMinor ? (pc + 9) % 12 : pc}>
                {functionalLabel(
                  node(frameMinor ? "relativeMinor" : "majorKey", SPOKES.indexOf(pc)),
                  frameTonic,
                )}
              </option>
            ))}
          </select>
          <div className="flex overflow-hidden rounded-md border border-line">
            {[false, true].map((minor) => (
              <button
                key={String(minor)}
                onClick={() => {
                  const column = SPOKES.indexOf(
                    ((frameTonic + (frameMinor ? 3 : 0)) % 12) as (typeof SPOKES)[number],
                  );
                  tap(node(minor ? "relativeMinor" : "majorKey",
                           column < 0 ? 0 : column));
                }}
                className={`px-2 py-1 ${minor === frameMinor ? "bg-fill text-ink" : "text-ink-dim"}`}
              >
                {minor ? "Minor" : "Major"}
              </button>
            ))}
          </div>
        </div>
        {path.length > 1 && (
          <div className="mt-2 flex items-center gap-2">
            <span className="no-scrollbar flex-1 overflow-x-auto whitespace-nowrap text-ink-dim">
              {path.map((n) => n.label).join(" → ")}
            </span>
            <button onClick={playWalk}
              className="rounded-full bg-accent px-3 py-1 font-semibold text-accent-deep">
              ▶ Walk
            </button>
            <button onClick={() => setPath([selected])} className="text-ink-mute">
              Clear
            </button>
          </div>
        )}
      </div>
      <TeachingCard
        selected={selected}
        moves={moves}
        embedded={fill}
        onArpeggiate={arpeggiate}
        onHearPair={(a, b) => {
          playProgression([chordMidis(a), chordMidis(b)]);
        }}
      />
      </div>
      )}
    </div>
  );
}


/** The scale written on a treble staff — note heads, accidentals,
 *  ledger lines, closing on the octave root. */
export function MiniStaff({ root, intervals }: { root: number; intervals: readonly number[] }) {
  const names = spellScale(root, intervals);
  const LETTERS: Record<string, number> = { C: 0, D: 1, E: 2, F: 3, G: 4, A: 5, B: 6 };
  // Absolute diatonic steps, ascending from octave 4; close with the root.
  const steps: { abs: number; acc: string }[] = [];
  let prev = -Infinity;
  for (const name of [...names, names[0]]) {
    const letter = LETTERS[name[0]] ?? 0;
    let oct = 4;
    let abs = letter + 7 * oct;
    while (abs <= prev) { oct += 1; abs = letter + 7 * oct; }
    prev = abs;
    steps.push({ abs, acc: name.slice(1) });
  }
  const half = 5;
  const baseY = 58; // E4, bottom staff line
  const y = (abs: number) => baseY - (abs - 30) * half;
  const left = 14;
  const gap = 27;
  const W = left + steps.length * gap + 8;
  return (
    <svg viewBox={`0 0 ${W} 76`} className="mt-1.5 h-[62px] w-auto max-w-full"
         aria-label="Scale on the staff">
      {[30, 32, 34, 36, 38].map((line) => (
        <line key={line} x1={4} x2={W - 4} y1={y(line)} y2={y(line)}
              stroke="currentColor" strokeWidth={0.8} opacity={0.35} />
      ))}
      {steps.map(({ abs, acc }, i) => {
        const cx = left + 10 + i * gap;
        const cy = y(abs);
        const ledgers: number[] = [];
        for (let l = 28; l >= abs - (abs % 2); l -= 2) if (l < 30) ledgers.push(l);
        for (let l = 40; l <= abs + (abs % 2); l += 2) if (l > 38) ledgers.push(l);
        return (
          <g key={i}>
            {ledgers.map((l) => (
              <line key={l} x1={cx - 8} x2={cx + 8} y1={y(l)} y2={y(l)}
                    stroke="currentColor" strokeWidth={0.8} opacity={0.45} />
            ))}
            {acc && (
              <text x={cx - 8} y={cy + 3.2} textAnchor="end" fontSize={9}
                    fill="currentColor" opacity={0.85}>{acc}</text>
            )}
            <ellipse cx={cx} cy={cy} rx={4.6} ry={3.5}
                     fill={i === 0 || i === steps.length - 1
                       ? "var(--color-accent-strong)" : "currentColor"}
                     transform={`rotate(-14 ${cx} ${cy})`} />
          </g>
        );
      })}
    </svg>
  );
}

type Tab = "pathways" | "scales" | "grips";

function TeachingCard({
  selected,
  moves,
  onArpeggiate,
  onHearPair,
  embedded = false,
}: {
  selected: CompassNode;
  moves: Move[];
  onArpeggiate: (grip: Grip) => void;
  onHearPair: (a: CompassNode, b: CompassNode) => void;
  embedded?: boolean;
}) {
  const [tab, setTab] = useState<Tab>("pathways");
  const [expanded, setExpanded] = useState<number | null>(null);
  const [gripIndex, setGripIndex] = useState(0);
  const [qualityIndex, setQualityIndex] = useState(0);
  const [gripView, setGripView] = useState<"shapes" | "drop2" | "drop3" | "dyads">("shapes");
  const [setIndex, setSetIndex] = useState(1);
  const [inversion, setInversion] = useState(0);
  const [dyadKind, setDyadKind] = useState(0);
  const [dyadPair, setDyadPair] = useState(1);
  const [dyadPos, setDyadPos] = useState(0);
  const families = useMemo(() => gripFamilies(selected), [selected]);
  const family = families[Math.min(qualityIndex, families.length - 1)];
  const hasShapes = (family?.grips.length ?? 0) > 0;
  const view = gripView === "shapes" && !hasShapes && family?.seventhIntervals
    ? "drop2" : gripView;
  const drop = view === "drop3" ? 3 : 2;
  const voicingSets = view === "drop3" ? DROP3_SETS : STRING_SETS;
  const voicingSetLabels = view === "drop3" ? DROP3_SET_LABELS : STRING_SET_LABELS;
  const boundedSet = Math.min(setIndex, voicingSets.length - 1);
  const inversionGrip = useMemo(
    () => family?.seventhIntervals
      ? dropGrip(selected.root, family.seventhIntervals, voicingSets[boundedSet], inversion, drop)
      : null,
    [family, selected, boundedSet, inversion, drop, voicingSets],
  );
  const dyads = useMemo(
    () => family?.seventhIntervals
      ? dyadGrips(selected.root, family.seventhIntervals, DYAD_KINDS[dyadKind], DYAD_PAIRS[dyadPair])
      : [],
    [family, selected, dyadKind, dyadPair],
  );
  const grips = family?.grips ?? [];
  const scales = useMemo(() => scaleSuggestions(selected), [selected]);
  const grip = grips[Math.min(gripIndex, grips.length - 1)];

  return (
    <aside className={embedded
        ? "min-h-0 w-full flex-1 overflow-y-auto p-5"
        : "w-full max-w-sm shrink-0 rounded-2xl border border-line bg-fill-soft p-5 backdrop-blur"}>
      <h3 className="font-display text-2xl font-bold text-ink">{selected.label}</h3>
      <div className="mt-3 flex gap-1 rounded-lg bg-fill-soft p-1 text-xs">
        {(["pathways", "scales", "grips"] as Tab[]).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`flex-1 rounded-md px-2 py-1.5 font-medium capitalize transition-colors ${
              tab === t ? "bg-fill text-ink" : "text-ink-dim hover:text-ink"
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {tab === "pathways" && (
        <>
        <p className="mt-3 text-[11px] text-ink-mute">
          Tap any pathway ▶ to see how the voices move.
        </p>
        <ul className="mt-2 space-y-1.5">
          {moves.map((m, i) => (
            <li key={i}>
              <button
                className="group flex w-full items-start gap-2 rounded-md px-1 py-0.5 text-left text-sm text-ink/90 transition-colors hover:bg-fill-soft"
                onClick={() => setExpanded(expanded === i ? null : i)}
                aria-expanded={expanded === i}
              >
                <span
                  className="mt-1.5 h-2 w-2 shrink-0 rounded-full"
                  style={{ backgroundColor: KIND_COLOR[m.kind] }}
                />
                <span className="flex-1">{describe(m)}</span>
                <span className={`mt-0.5 shrink-0 text-[10px] transition-transform duration-200 ${
                  expanded === i ? "rotate-90 text-accent" : "text-ink-mute group-hover:text-ink-dim"
                }`}>
                  ▶
                </span>
              </button>
              {expanded === i && (
                <div>
                  <VoiceStaff from={m.from} to={m.to} />
                  <button
                    onClick={() => onHearPair(m.from, m.to)}
                    className="mt-1 rounded-full bg-fill-soft px-3 py-1 text-[11px] text-ink-dim transition-colors hover:text-ink"
                  >
                    ▶ Hear the move
                  </button>
                </div>
              )}
            </li>
          ))}
        </ul>
        </>
      )}

      {tab === "scales" && (
        <ul className="mt-4 space-y-2">
          {scales.map((s) => (
            <ScaleRow key={s.name} root={selected.root} scale={s} />
          ))}
        </ul>
      )}

      {tab === "grips" && grip && (
        <div className="mt-4">
          <div className="flex flex-wrap gap-1.5">
            {families.map((f, i) => (
              <button
                key={f.suffix || "triad"}
                onClick={() => { setQualityIndex(i); setGripIndex(0); }}
                className={`rounded-md px-2.5 py-1 text-xs font-medium transition-colors ${
                  i === Math.min(qualityIndex, families.length - 1)
                    ? "bg-fill text-ink"
                    : "text-ink-mute hover:bg-fill-soft hover:text-ink-dim"
                }`}
              >
                {selected.label.replace(/(m|7|°7)$/, "")}{f.suffix || (selected.ring === "relativeMinor" ? "m" : "")}
              </button>
            ))}
          </div>
          {family?.seventhIntervals && (
            <div className="mt-2.5 flex flex-wrap gap-1">
              {([["shapes", "Shapes"], ["drop2", "Drop-2"], ["drop3", "Drop-3"], ["dyads", "Dyads"]] as const)
                .filter(([v]) => v !== "shapes" || hasShapes)
                .map(([v, label]) => (
                <button
                  key={v}
                  onClick={() => setGripView(v)}
                  className={`rounded-full px-3 py-1 text-[11px] transition-colors ${
                    view === v ? "bg-accent text-accent-deep" : "bg-fill-soft text-ink-mute hover:text-ink"
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>
          )}
          {view === "dyads" && family?.seventhIntervals ? (
            <div className="mt-2.5">
              <div className="flex flex-wrap gap-1.5">
                {DYAD_KINDS.map((k, i) => (
                  <button
                    key={k.label}
                    onClick={() => { setDyadKind(i); setDyadPos(0); }}
                    className={`rounded-full px-3 py-1 text-xs transition-colors ${
                      i === dyadKind ? "bg-fill text-ink" : "text-ink-mute hover:text-ink-dim"
                    }`}
                  >
                    {k.label}
                  </button>
                ))}
              </div>
              <div className="mt-1.5 flex flex-wrap gap-1.5">
                {DYAD_PAIR_LABELS.map((label, i) => (
                  <button
                    key={label}
                    onClick={() => { setDyadPair(i); setDyadPos(0); }}
                    className={`rounded-full px-3 py-1 text-xs transition-colors ${
                      i === dyadPair ? "bg-fill text-ink" : "text-ink-mute hover:text-ink-dim"
                    }`}
                  >
                    strings {label}
                  </button>
                ))}
              </div>
              <div className="mt-1.5 flex flex-wrap gap-1.5">
                {dyads.map((g, i) => (
                  <button
                    key={i}
                    onClick={() => { setDyadPos(i); onArpeggiate(g); }}
                    className={`rounded-full px-3 py-1 text-xs transition-colors ${
                      i === Math.min(dyadPos, dyads.length - 1)
                        ? "bg-accent text-accent-deep" : "bg-fill-soft text-ink-dim hover:text-ink"
                    }`}
                  >
                    {g.positionLabel}
                  </button>
                ))}
              </div>
              {dyads[Math.min(dyadPos, dyads.length - 1)] && (
                <MiniFretboard node={selected} grip={dyads[Math.min(dyadPos, dyads.length - 1)]} />
              )}
              <p className="mt-2 text-[11px] text-ink-mute">
                Two voices carry the whole chord — slide the pair through the changes.
              </p>
            </div>
          ) : (view === "drop2" || view === "drop3") && family?.seventhIntervals ? (
            <div className="mt-2.5">
              <div className="flex flex-wrap gap-1.5">
                {voicingSetLabels.map((label, i) => (
                  <button
                    key={label}
                    onClick={() => setSetIndex(i)}
                    className={`rounded-full px-3 py-1 text-xs transition-colors ${
                      i === boundedSet ? "bg-fill text-ink" : "text-ink-mute hover:text-ink-dim"
                    }`}
                  >
                    strings {label}
                  </button>
                ))}
              </div>
              <div className="mt-1.5 flex flex-wrap gap-1.5">
                {INVERSION_LABELS.map((label, i) => (
                  <button
                    key={label}
                    onClick={() => {
                      setInversion(i);
                      const g = dropGrip(selected.root, family.seventhIntervals!, voicingSets[boundedSet], i, drop);
                      if (g) onArpeggiate(g);
                    }}
                    className={`rounded-full px-3 py-1 text-xs transition-colors ${
                      i === inversion ? "bg-accent text-accent-deep" : "bg-fill-soft text-ink-dim hover:text-ink"
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
              {inversionGrip ? (
                <MiniFretboard node={selected} grip={inversionGrip} />
              ) : (
                <p className="mt-3 text-xs text-ink-mute">
                  No one-position voicing on this string set — try the next one.
                </p>
              )}
              <p className="mt-2 text-[11px] text-ink-mute">
                Same four voices, re-stacked: watch the root climb through the shape.
              </p>
            </div>
          ) : (
          <>
          <div className="mt-2.5 flex flex-wrap gap-1.5">
            {grips.map((g, i) => (
              <button
                key={i}
                onClick={() => {
                  setGripIndex(i);
                  onArpeggiate(g);
                }}
                className={`rounded-full px-3 py-1 text-xs transition-colors ${
                  i === Math.min(gripIndex, grips.length - 1)
                    ? "bg-accent text-accent-deep"
                    : "bg-fill text-ink-dim hover:text-ink"
                }`}
              >
                {g.positionLabel}
              </button>
            ))}
          </div>
          <MiniFretboard node={selected} grip={grip} />
          <p className="mt-2 text-[11px] text-ink-mute">
            Tap a position to hear it, bottom to top.
          </p>
          </>
          )}
        </div>
      )}


      <p className="mt-5 border-t border-line pt-4 text-xs text-ink-dim">
        In the full app every pathway opens full-neck scales, the complete
        grip dictionary, voice leading, and alterations.
      </p>
    </aside>
  );
}

const ROLE_COLOR = [
  "var(--color-accent-strong)",
  "var(--color-tone-third)",
  "var(--color-tone-fifth)",
  "var(--color-tone-seventh)",
];

/** A five-fret window of rosewood showing one grip. */
function MiniFretboard({ node: n, grip }: { node: CompassNode; grip: Grip }) {
  const sounded = grip.frets
    .map((f, s) => (f === null ? null : { s, f }))
    .filter((x): x is { s: number; f: number } => x !== null);
  const fretted = sounded.map(({ f }) => f).filter((f) => f > 0);
  const low = fretted.length ? Math.min(...fretted) : 1;
  const start = Math.max(1, Math.min(low, 11)); // window start fret
  const W = 300;
  const H = 128;
  const left = 26;
  const gap = (W - left - 10) / 5;
  const stringY = (s: number) => 13 + (5 - s) * ((H - 40) / 5);
  const fretX = (f: number) => left + (f - start + 1) * gap;
  const noteX = (f: number) =>
    f === 0 ? left - 13 : fretX(f) - gap / 2;

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="mt-3 w-full">
      <rect x={left} y={6} width={W - left - 8} height={H - 24}
        rx={5} fill="#4d2e1c" stroke="rgba(0,0,0,0.4)" />
      {start === 1 && (
        <rect x={left - 4} y={6} width={6} height={H - 24} rx={2} fill="#ded9cc" />
      )}
      {[0, 1, 2, 3, 4, 5].map((i) => (
        <line key={i} x1={fretX(start + i)} y1={8} x2={fretX(start + i)}
          y2={H - 20} stroke="rgba(210,210,214,0.7)" strokeWidth={2} />
      ))}
      {[0, 1, 2, 3, 4, 5].map((s) => (
        <line key={s} x1={left - 4} y1={stringY(s)} x2={W - 10} y2={stringY(s)}
          stroke="#c9c2b2" strokeWidth={2.4 - s * 0.3} opacity={0.85} />
      ))}
      <text x={left + gap / 2} y={H - 4} textAnchor="middle" fontSize={10}
        fill="var(--color-ink-mute)">
        {start}
      </text>
      {grip.frets.map((f, s) =>
        f === null ? (
          <text key={s} x={left - 14} y={stringY(s) + 3.5} fontSize={10}
            fill="var(--color-ink-mute)" textAnchor="middle">×</text>
        ) : null,
      )}
      {sounded.map(({ s, f }) => (
        <g key={s}>
          <circle cx={noteX(f)} cy={stringY(s)} r={8.5}
            fill={ROLE_COLOR[toneRole(n, s, f)]} />
          <text x={noteX(f)} y={stringY(s) + 3} textAnchor="middle"
            fontSize={8.5} fontWeight={700} fill="#1a1208">
            {["R", "3", "5", "7"][toneRole(n, s, f)]}
          </text>
        </g>
      ))}
    </svg>
  );
}


const SHARP_N = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"];

/** Two chord stacks with per-voice motion lines — green half-step pulls,
 *  dashed held common tones. Same grammar as the headset card. */
function VoiceStaff({ from, to }: { from: CompassNode; to: CompassNode }) {
  const moves = voiceMoves(from, to);
  const W = 300;
  const H = 108;
  const yFor = (pc: number, root: number) => {
    const rel = (((pc - root) % 12) + 12) % 12;
    return H - 26 - rel * 5.4;
  };
  const xL = 58;
  const xR = W - 58;
  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="mt-2 w-full rounded-lg bg-black/25">
      {moves.map((m, i) => {
        const y0 = yFor(m.from, from.root);
        const y1 = yFor(m.to, from.root);
        const half = Math.abs(m.semitones) === 1;
        const common = m.semitones === 0;
        return (
          <g key={i}>
            <line
              x1={xL + 14}
              y1={y0}
              x2={xR - 14}
              y2={y1}
              stroke={common ? "rgba(255,255,255,0.45)" : half ? "#4ade80" : "rgba(255,255,255,0.6)"}
              strokeWidth={half ? 2.6 : 1.4}
              strokeDasharray={common ? "4 4" : undefined}
            />
            <circle cx={xL} cy={y0} r={6} fill="#fff" />
            <text x={xL - 12} y={y0 + 3.5} textAnchor="end" fontSize={10} fill="#e4e4e7">
              {SHARP_N[m.from]}
            </text>
            <circle cx={xR} cy={y1} r={6} fill="#fff" />
            <text x={xR + 12} y={y1 + 3.5} fontSize={10} fill="#e4e4e7">
              {SHARP_N[m.to]}
            </text>
            <text
              x={(xL + xR) / 2}
              y={(y0 + y1) / 2 - 5}
              textAnchor="middle"
              fontSize={9.5}
              fontWeight={700}
              fill={half ? "#4ade80" : "rgba(255,255,255,0.8)"}
            >
              {common ? "=" : m.semitones > 0 ? `+${m.semitones}` : `−${Math.abs(m.semitones)}`}
            </text>
          </g>
        );
      })}
      <text x={xL} y={H - 6} textAnchor="middle" fontSize={11} fontWeight={600} fill="#fafafa">
        {from.label}
      </text>
      <text x={xR} y={H - 6} textAnchor="middle" fontSize={11} fontWeight={600} fill="#fafafa">
        {to.label}
      </text>
    </svg>
  );
}


/** A scale row that unfolds into its per-degree chord-scale cards —
 *  roman · seventh · tensions · mode, same engine rows as the headset. */
function ScaleRow({
  root,
  scale,
}: {
  root: number;
  scale: ReturnType<typeof scaleSuggestions>[number];
}) {
  const cells = useMemo(() => degreeCells(root, scale), [root, scale]);
  return (
    <li className="text-sm">
      <div className="flex w-full items-baseline gap-2 text-left">
        <span className="font-medium text-ink">{scale.name}</span>
        <span className="text-xs text-ink-dim">
          {spellScale(root, scale.intervals).join(" ")}
        </span>
      </div>
      <MiniStaff root={root} intervals={scale.intervals} />
      {cells.length > 0 && (
        <div className="mt-2 grid grid-cols-4 gap-1.5 sm:grid-cols-7">
          {cells.map((cell, i) => (
            <div
              key={i}
              className="rounded-lg bg-black/25 px-1 py-1.5 text-center"
            >
              <div className="text-xs font-bold text-orange-400">{cell.roman}</div>
              <div className="truncate text-[10px] text-ink">{cell.chordSymbol}</div>
              <div className="truncate text-[9px] font-semibold text-cyan-300/90">
                {cell.tensions.join(" ")}
              </div>
              {cell.mode && (
                <div className="truncate text-[8px] text-ink-mute">{cell.mode}</div>
              )}
            </div>
          ))}
        </div>
      )}
    </li>
  );
}
