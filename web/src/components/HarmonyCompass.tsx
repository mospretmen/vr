// The live Harmony Compass demo — the showcase heart of the landing page.
// A faithful 2D rendering of the visionOS compass: tap any chord, hear it,
// and watch its legal departures light up over the quiet lattice.
import { useMemo, useRef, useState } from "react";
import {
  ALL_MOVES,
  ALL_NODES,
  chordPitchClasses,
  describe,
  isTwoWay,
  movesFrom,
  node,
  type CompassNode,
  type Move,
  type MoveKind,
} from "../compass";

const SIZE = 640;
const CENTER = SIZE / 2;
const RIM = 252;
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
  const litIds = useMemo(
    () => new Set(moves.flatMap((m) => [m.from.id, m.to.id])),
    [moves],
  );

  const tap = (n: CompassNode) => {
    setSelected(n);
    audio.current ??= new AudioContext();
    playChord(audio.current, n);
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
          {Object.entries(KIND_COLOR).map(([kind, color]) => (
            <marker
              key={kind}
              id={`head-${kind}`}
              viewBox="0 0 10 10"
              refX="8"
              refY="5"
              markerWidth="7"
              markerHeight="7"
              orient="auto-start-reverse"
            >
              <path d="M 0 0 L 10 5 L 0 10 z" fill={color} />
            </marker>
          ))}
        </defs>

        {/* resting lattice */}
        {lattice.map(([a, b]) => (
          <path
            key={`${a.id}|${b.id}`}
            d={edgePath(a, b)}
            stroke="rgba(255,255,255,0.07)"
            strokeWidth={1}
            fill="none"
          />
        ))}

        {/* the selected chord's departures */}
        {moves.map((m, i) => (
          <path
            key={i}
            d={edgePath(m.from, m.to)}
            stroke={KIND_COLOR[m.kind]}
            strokeWidth={2.6}
            strokeDasharray={m.kind === "deceptive" ? "8 6" : undefined}
            fill="none"
            markerEnd={`url(#head-${m.kind})`}
            markerStart={isTwoWay(m) ? `url(#head-${m.kind})` : undefined}
            opacity={0.95}
          />
        ))}

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
      <aside className="w-full max-w-sm shrink-0 rounded-2xl border border-white/10 bg-white/5 p-5 backdrop-blur">
        <h3 className="font-display text-2xl font-bold text-ink">
          {selected.label}
        </h3>
        <p className="mt-1 text-xs text-ink-dim">
          Tap any chord — hear it, and read where harmony can go.
        </p>
        <ul className="mt-4 space-y-2.5">
          {moves.map((m: Move, i) => (
            <li key={i} className="flex items-start gap-2 text-sm text-ink/90">
              <span
                className="mt-1.5 h-2 w-2 shrink-0 rounded-full"
                style={{ backgroundColor: KIND_COLOR[m.kind] }}
              />
              <span>{describe(m)}</span>
            </li>
          ))}
        </ul>
        <p className="mt-5 border-t border-white/10 pt-4 text-xs text-ink-dim">
          In the full app every pathway opens scales, real grips, voice
          leading, and alterations — on a fretboard in front of you.
        </p>
      </aside>
    </div>
  );
}
