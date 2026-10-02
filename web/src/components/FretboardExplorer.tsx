import { useMemo, useState } from "react";
import { NOTE_NAMES, noteName } from "../music";
import {
  SCALE_TYPES,
  STANDARD_TUNING_MIDI,
  STRING_COUNT,
  TRIAD_QUALITIES,
  fretPositions,
  noteAt,
} from "../theory";

/*
 * Interactive fretboard explorer. Pure view over src/theory.ts: pick a root
 * and a scale/mode (or a triad quality) and the matching positions light up
 * on an SVG board with realistic equal-temperament fret spacing.
 */

const FRETS = 15;

// Geometry in viewBox units.
const VB_W = 960;
const VB_H = 272;
const NUT_X = 72; // left edge of the playable board
const BOARD_RIGHT = 936;
const BOARD_W = BOARD_RIGHT - NUT_X;
const OPEN_X = 34; // open-string column, left of the nut
const STRING_TOP = 46;
const STRING_GAP = 36;
const STRING_BOTTOM = STRING_TOP + (STRING_COUNT - 1) * STRING_GAP;
const BOARD_PAD_Y = 17;
const DOT_R = 12.5;

const WIRE_X = fretPositions(FRETS).map((p) => NUT_X + p * BOARD_W);

/** Marker x for a fret: open column, or midpoint of its fret slot. */
function noteX(fret: number): number {
  return fret === 0 ? OPEN_X : (WIRE_X[fret - 1] + WIRE_X[fret]) / 2;
}

/** String y: high E on top (tab convention), low E at the bottom. */
function stringY(stringIndex: number): number {
  return STRING_TOP + (STRING_COUNT - 1 - stringIndex) * STRING_GAP;
}

/** Interval label by semitone offset from the root. */
const INTERVAL_LABELS = [
  "R", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♭6", "6", "♭7", "7",
] as const;

// Gauge illusion: lower strings draw thicker.
const STRING_WIDTHS = [2.7, 2.3, 1.9, 1.5, 1.2, 1.0];

const INLAY_FRETS = [3, 5, 7, 9, 15];
const NUMBERED_FRETS = [3, 5, 7, 9, 12, 15];

type DisplayMode = "scale" | "triad";

interface Hovered {
  string: number;
  fret: number;
}

export function FretboardExplorer() {
  const [root, setRoot] = useState(9); // A — a guitarist's home base
  const [mode, setMode] = useState<DisplayMode>("scale");
  const [scaleIndex, setScaleIndex] = useState(8); // Minor Pentatonic
  const [triadIndex, setTriadIndex] = useState(0);
  const [hovered, setHovered] = useState<Hovered | null>(null);

  const intervals =
    mode === "scale"
      ? SCALE_TYPES[scaleIndex].intervals
      : TRIAD_QUALITIES[triadIndex].intervals;

  const selectionName =
    mode === "scale"
      ? `${noteName(root)} ${SCALE_TYPES[scaleIndex].name}`
      : `${noteName(root)}${TRIAD_QUALITIES[triadIndex].symbol} triad`;

  const selectionTones = useMemo(
    () => intervals.map((i) => noteName((root + i) % 12)),
    [root, intervals],
  );

  /** Offset from root (0–11) if the pitch class is in the selection. */
  function offsetInSelection(pc: number): number | null {
    const offset = (((pc - root) % 12) + 12) % 12;
    return intervals.includes(offset) ? offset : null;
  }

  const hoveredReadout = useMemo(() => {
    if (!hovered) return null;
    const pc = noteAt(hovered.string, hovered.fret);
    const midi = STANDARD_TUNING_MIDI[hovered.string] + hovered.fret;
    const octave = Math.floor(midi / 12) - 1;
    const offset = offsetInSelection(pc);
    return {
      note: `${noteName(pc)}${octave}`,
      place: `string ${STRING_COUNT - hovered.string} · fret ${hovered.fret}`,
      role: offset === null ? "outside the selection" : INTERVAL_LABELS[offset],
    };
  }, [hovered, root, intervals]);

  const boardMidY = (STRING_TOP + STRING_BOTTOM) / 2;

  return (
    <div className="overflow-hidden rounded-2xl border border-white/10 bg-raise/80 shadow-[0_24px_80px_-32px_rgba(0,0,0,0.9)] backdrop-blur-sm">
      {/* Controls */}
      <div className="flex flex-col gap-4 border-b border-white/10 p-4 sm:p-5">
        <div className="flex flex-wrap items-center gap-x-4 gap-y-3">
          <span className="w-10 shrink-0 text-[11px] font-medium uppercase tracking-[0.14em] text-ink-mute">
            Root
          </span>
          <div
            role="group"
            aria-label="Root note"
            className="flex flex-wrap gap-1"
          >
            {NOTE_NAMES.map((name, pc) => (
              <button
                key={name}
                type="button"
                aria-pressed={root === pc}
                onClick={() => setRoot(pc)}
                className={`h-8 min-w-8 rounded-lg px-1.5 text-sm font-medium tabular-nums transition-colors duration-200 ${
                  root === pc
                    ? "bg-accent-strong text-accent-deep"
                    : "text-ink-dim hover:bg-white/5 hover:text-ink"
                }`}
              >
                {name}
              </button>
            ))}
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-x-4 gap-y-3">
          <span className="w-10 shrink-0 text-[11px] font-medium uppercase tracking-[0.14em] text-ink-mute">
            Show
          </span>
          <div
            role="group"
            aria-label="Display mode"
            className="flex rounded-lg border border-white/10 p-0.5"
          >
            {(["scale", "triad"] as const).map((m) => (
              <button
                key={m}
                type="button"
                aria-pressed={mode === m}
                onClick={() => setMode(m)}
                className={`rounded-md px-3 py-1.5 text-sm font-medium capitalize transition-colors duration-200 ${
                  mode === m
                    ? "bg-white/10 text-ink"
                    : "text-ink-dim hover:text-ink"
                }`}
              >
                {m}
              </button>
            ))}
          </div>

          {mode === "scale" ? (
            <label className="flex items-center gap-2">
              <span className="sr-only">Scale or mode</span>
              <select
                value={scaleIndex}
                onChange={(e) => setScaleIndex(Number(e.target.value))}
                className="h-9 rounded-lg border border-white/10 bg-raise-2 px-3 pr-8 text-sm text-ink transition-colors hover:border-white/20"
              >
                {SCALE_TYPES.map((scale, i) => (
                  <option key={scale.name} value={i}>
                    {scale.name}
                  </option>
                ))}
              </select>
            </label>
          ) : (
            <div
              role="group"
              aria-label="Triad quality"
              className="flex flex-wrap gap-1"
            >
              {TRIAD_QUALITIES.map((quality, i) => (
                <button
                  key={quality.name}
                  type="button"
                  aria-pressed={triadIndex === i}
                  onClick={() => setTriadIndex(i)}
                  className={`h-8 rounded-lg px-3 text-sm font-medium transition-colors duration-200 ${
                    triadIndex === i
                      ? "bg-white/10 text-ink"
                      : "text-ink-dim hover:bg-white/5 hover:text-ink"
                  }`}
                >
                  {quality.name}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Readout strip — fixed height so hover never shifts layout */}
      <div className="flex min-h-11 flex-wrap items-center justify-between gap-x-6 gap-y-1 px-4 py-2 sm:px-5">
        <p className="flex flex-wrap items-baseline gap-x-2.5 gap-y-1">
          <span className="font-display text-sm font-semibold text-ink">
            {selectionName}
          </span>
          <span className="text-sm tracking-wide text-ink-dim">
            {selectionTones.join(" · ")}
          </span>
        </p>
        <p
          aria-live="polite"
          className="font-mono text-xs tabular-nums text-ink-mute"
        >
          {hoveredReadout ? (
            <>
              <span className="text-ink">{hoveredReadout.note}</span>
              <span> · {hoveredReadout.place} · </span>
              <span
                className={
                  hoveredReadout.role === "outside the selection"
                    ? ""
                    : "text-accent"
                }
              >
                {hoveredReadout.role}
              </span>
            </>
          ) : (
            "hover a position"
          )}
        </p>
      </div>

      {/* Board */}
      <div className="overflow-x-auto px-2 pb-3 sm:px-3">
        <svg
          viewBox={`0 0 ${VB_W} ${VB_H}`}
          role="img"
          aria-label={`Fretboard showing ${selectionName}: ${selectionTones.join(", ")}`}
          className="min-w-[760px] select-none"
          onMouseLeave={() => setHovered(null)}
        >
          <defs>
            <linearGradient id="fb-wood" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="#1a1510" />
              <stop offset="0.5" stopColor="#141009" />
              <stop offset="1" stopColor="#0e0b07" />
            </linearGradient>
            <radialGradient id="fb-halo">
              <stop offset="0" stopColor="var(--color-accent-strong)" stopOpacity="0.5" />
              <stop offset="0.55" stopColor="var(--color-accent-strong)" stopOpacity="0.16" />
              <stop offset="1" stopColor="var(--color-accent-strong)" stopOpacity="0" />
            </radialGradient>
          </defs>

          {/* Fretboard surface */}
          <rect
            x={NUT_X}
            y={STRING_TOP - BOARD_PAD_Y}
            width={BOARD_W}
            height={STRING_BOTTOM - STRING_TOP + BOARD_PAD_Y * 2}
            rx={6}
            fill="url(#fb-wood)"
            stroke="rgba(255,255,255,0.08)"
          />

          {/* Inlays */}
          {INLAY_FRETS.map((f) => (
            <circle
              key={f}
              cx={noteX(f)}
              cy={boardMidY}
              r={6.5}
              fill="rgba(255,255,255,0.055)"
            />
          ))}
          {[boardMidY - STRING_GAP, boardMidY + STRING_GAP].map((y) => (
            <circle
              key={y}
              cx={noteX(12)}
              cy={y}
              r={6.5}
              fill="rgba(255,255,255,0.055)"
            />
          ))}

          {/* Fret wires */}
          {WIRE_X.slice(1).map((x) => (
            <line
              key={x}
              x1={x}
              y1={STRING_TOP - BOARD_PAD_Y}
              x2={x}
              y2={STRING_BOTTOM + BOARD_PAD_Y}
              stroke="rgba(203,206,215,0.22)"
              strokeWidth={2}
            />
          ))}

          {/* Nut */}
          <rect
            x={NUT_X - 3}
            y={STRING_TOP - BOARD_PAD_Y}
            width={7}
            height={STRING_BOTTOM - STRING_TOP + BOARD_PAD_Y * 2}
            rx={2.5}
            fill="#d8d3c8"
            opacity={0.85}
          />

          {/* Strings */}
          {Array.from({ length: STRING_COUNT }, (_, s) => (
            <line
              key={s}
              x1={NUT_X - 3}
              y1={stringY(s)}
              x2={BOARD_RIGHT}
              y2={stringY(s)}
              stroke={s < 3 ? "#9d9588" : "#c9c7bd"}
              strokeWidth={STRING_WIDTHS[s]}
              opacity={0.6}
            />
          ))}

          {/* Fret numbers */}
          {NUMBERED_FRETS.map((f) => (
            <text
              key={f}
              x={noteX(f)}
              y={STRING_BOTTOM + BOARD_PAD_Y + 24}
              textAnchor="middle"
              className="fill-ink-mute text-[12px] tabular-nums"
            >
              {f}
            </text>
          ))}

          {/* Note positions: every string × fret is a live hover target */}
          {Array.from({ length: STRING_COUNT }, (_, s) =>
            Array.from({ length: FRETS + 1 }, (_, f) => {
              const pc = noteAt(s, f);
              const offset = offsetInSelection(pc);
              const active = offset !== null;
              const isRoot = offset === 0;
              const isHovered = hovered?.string === s && hovered?.fret === f;
              const cx = noteX(f);
              const cy = stringY(s);
              const label = active
                ? INTERVAL_LABELS[offset]
                : noteName(pc);
              const fade = { transition: "opacity 0.3s ease, fill 0.3s ease" };

              return (
                <g
                  key={`${s}-${f}`}
                  onMouseEnter={() => setHovered({ string: s, fret: f })}
                  className="cursor-crosshair"
                >
                  <title>{`${noteName(pc)} — string ${STRING_COUNT - s}, fret ${f}`}</title>
                  {/* Root halo */}
                  <circle
                    cx={cx}
                    cy={cy}
                    r={DOT_R * 2.2}
                    fill="url(#fb-halo)"
                    style={fade}
                    opacity={isRoot ? 1 : 0}
                    pointerEvents="none"
                  />
                  {/* Marker */}
                  <circle
                    cx={cx}
                    cy={cy}
                    r={DOT_R}
                    style={fade}
                    fill={
                      isRoot
                        ? "var(--color-accent-strong)"
                        : "rgba(250,250,250,0.1)"
                    }
                    stroke={
                      isRoot
                        ? "var(--color-accent)"
                        : "rgba(250,250,250,0.28)"
                    }
                    strokeWidth={1}
                    opacity={active ? 1 : isHovered ? 0.4 : 0}
                  />
                  <text
                    x={cx}
                    y={cy}
                    dy="0.36em"
                    textAnchor="middle"
                    pointerEvents="none"
                    style={fade}
                    opacity={active ? 1 : isHovered ? 0.9 : 0}
                    className={`text-[11px] font-medium ${
                      isRoot ? "fill-accent-deep" : "fill-ink"
                    }`}
                  >
                    {label}
                  </text>
                  {/* Hit target (kept last so it owns the hover) */}
                  <circle cx={cx} cy={cy} r={16} fill="transparent" />
                </g>
              );
            }),
          )}
        </svg>
      </div>
    </div>
  );
}
