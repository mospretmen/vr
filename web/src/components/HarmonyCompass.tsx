// The live Harmony Compass demo — the showcase heart of the landing page.
// A faithful 2D rendering of the visionOS compass: tap any chord, hear it,
// and watch its legal departures light up over the quiet lattice.
import { useMemo, useRef, useState } from "react";
import {
  ALL_MOVES,
  ALL_NODES,
  chordPitchClasses,
  describe,
  gradedPairs,
  movesFrom,
  node,
  type CompassNode,
  type Move,
  type MoveKind,
} from "../compass";
import {
  gripsFor,
  scaleSuggestions,
  spellScale,
  toneRole,
  type Grip,
} from "../demoVoicings";
import { voiceMoves } from "../voiceLeading";

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
  fifthSharpward: "#60a5fa",
  fifthFlatward: "#60a5fa",
  relative: "#e2e8f0",
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

/** Soft chord pad via WebAudio — no samples, instant. */
function playChord(ctx: AudioContext, n: CompassNode) {
  const now = ctx.currentTime;
  const master = ctx.createGain();
  master.gain.setValueAtTime(0.0001, now);
  master.gain.exponentialRampToValueAtTime(0.16, now + 0.05);
  master.gain.exponentialRampToValueAtTime(0.0001, now + 1.5);
  master.connect(ctx.destination);
  const midis = [n.root + 48, ...chordPitchClasses(n).map((pc) => pc + 60)];
  for (const midi of midis) {
    const osc = ctx.createOscillator();
    osc.type = "triangle";
    osc.frequency.value = 440 * Math.pow(2, (midi - 69) / 12);
    const gain = ctx.createGain();
    gain.gain.value = 1 / midis.length;
    osc.connect(gain).connect(master);
    osc.start(now);
    osc.stop(now + 1.6);
  }
}

export function HarmonyCompass() {
  const [selected, setSelected] = useState<CompassNode>(() => node("majorKey", 0));
  const audio = useRef<AudioContext | null>(null);
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
    setSelected(n);
    audio.current ??= new AudioContext();
    playChord(audio.current, n);
  };

  const arpeggiate = (grip: Grip) => {
    audio.current ??= new AudioContext();
    const ctx = audio.current;
    const now = ctx.currentTime;
    const sounded = grip.frets
      .map((f, s) => (f === null ? null : 40 + [0, 5, 10, 15, 19, 24][s] + f))
      .filter((m): m is number => m !== null);
    sounded.forEach((midi, i) => {
      const osc = ctx.createOscillator();
      osc.type = "triangle";
      osc.frequency.value = 440 * Math.pow(2, (midi - 69) / 12);
      const gain = ctx.createGain();
      const t = now + i * 0.12;
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.exponentialRampToValueAtTime(0.14, t + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.9);
      osc.connect(gain).connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 1);
    });
  };

  return (
    <div className="flex flex-col items-start gap-6 lg:flex-row">
      <svg
        viewBox={`0 0 ${SIZE} ${SIZE}`}
        className="w-full max-w-[640px] flex-1 select-none"
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
          const look = { 1: [0.95, 2.4], 2: [0.42, 1.4], 3: [0.16, 0.8] }[depth]!;
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
              className="cursor-pointer"
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
                {n.label}
              </text>
            </g>
          );
        })}
      </svg>

      {/* teaching card */}
      <TeachingCard
        selected={selected}
        moves={moves}
        onArpeggiate={arpeggiate}
        onHearPair={(a, b) => {
          audio.current ??= new AudioContext();
          playChord(audio.current, a);
          const ctx = audio.current;
          const later = b;
          setTimeout(() => playChord(ctx, later), 850);
        }}
      />
    </div>
  );
}


type Tab = "pathways" | "scales" | "grips";

function TeachingCard({
  selected,
  moves,
  onArpeggiate,
  onHearPair,
}: {
  selected: CompassNode;
  moves: Move[];
  onArpeggiate: (grip: Grip) => void;
  onHearPair: (a: CompassNode, b: CompassNode) => void;
}) {
  const [tab, setTab] = useState<Tab>("pathways");
  const [expanded, setExpanded] = useState<number | null>(null);
  const [gripIndex, setGripIndex] = useState(0);
  const grips = useMemo(() => gripsFor(selected), [selected]);
  const scales = useMemo(() => scaleSuggestions(selected), [selected]);
  const grip = grips[Math.min(gripIndex, grips.length - 1)];

  return (
    <aside className="w-full max-w-sm shrink-0 rounded-2xl border border-line bg-fill-soft p-5 backdrop-blur">
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
        <ul className="mt-4 space-y-2.5">
          {moves.map((m, i) => (
            <li key={i}>
              <button
                className="flex w-full items-start gap-2 text-left text-sm text-ink/90"
                onClick={() => {
                  const open = expanded === i ? null : i;
                  setExpanded(open);
                  if (open !== null) onHearPair(m.from, m.to);
                }}
              >
                <span
                  className="mt-1.5 h-2 w-2 shrink-0 rounded-full"
                  style={{ backgroundColor: KIND_COLOR[m.kind] }}
                />
                <span>{describe(m)}</span>
              </button>
              {expanded === i && <VoiceStaff from={m.from} to={m.to} />}
            </li>
          ))}
        </ul>
      )}

      {tab === "scales" && (
        <ul className="mt-4 space-y-3">
          {scales.map((s) => (
            <li key={s.name} className="text-sm">
              <span className="font-medium text-ink">{s.name}</span>
              <span className="ml-2 text-xs text-ink-dim">
                {spellScale(selected.root, s.intervals).join(" ")}
              </span>
            </li>
          ))}
        </ul>
      )}

      {tab === "grips" && grip && (
        <div className="mt-4">
          <div className="flex flex-wrap gap-1.5">
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
        </div>
      )}

      {tab === "pathways" && (
        <p className="mt-2 text-[11px] text-ink-mute">
          Tap a pathway to watch the voices move.
        </p>
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
  const low = Math.max(
    1,
    Math.min(...sounded.map(({ f }) => f).filter((f) => f > 0), 1),
  );
  const start = Math.min(low, 11); // window start fret
  const W = 300;
  const H = 128;
  const left = 26;
  const gap = (W - left - 10) / 5;
  const stringY = (s: number) => 14 + (5 - s) * ((H - 32) / 5);
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
