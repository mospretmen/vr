import { useMemo, useState } from "react";
import { NOTE_NAMES, noteName } from "../music";
import {
  SCALE_TYPES,
  SEVENTH_QUALITIES,
  STANDARD_TUNING_MIDI,
  STRING_COUNT,
  TRIAD_QUALITIES,
  fretPositions,
  noteAt,
} from "../theory";
import {
  INVERSION_LABELS,
  STRING_SETS_3,
  STRING_SETS_4,
  drop2,
  triadInversions,
} from "../voicings";

/*
 * Interactive fretboard explorer. Pure view over src/theory.ts and
 * src/voicings.ts: pick a root and a scale/mode (or a triad quality) and the
 * matching positions light up on an SVG board with realistic
 * equal-temperament fret spacing; Voicings mode draws connected inversion
 * shapes (triads + drop-2 sevenths) exactly as the headset overlay does.
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

type DisplayMode = "scale" | "triad" | "voicings";

/** Voicings-mode quality catalog: the four triads, then the four sevenths. */
const VOICING_QUALITIES = [...TRIAD_QUALITIES, ...SEVENTH_QUALITIES];

/** Chord-tone marker styling, indexed root/third/fifth/seventh. Full literal
 * class names so Tailwind generates the token utilities. */
const TONE_FILL = [
  "fill-accent-strong",
  "fill-tone-third",
  "fill-tone-fifth",
  "fill-tone-seventh",
] as const;
const TONE_MARKS = ["R", "3", "5", "7"] as const;

/** Connector line under the voicing markers. */
const SHAPE_STROKE = "rgba(255,255,255,0.45)";

/** "G · B · E" — a string set named by its open-string notes, low to high. */
function stringSetLabel(strings: readonly number[]): string {
  return strings.map((s) => noteName(noteAt(s, 0))).join(" · ");
}

interface Hovered {
  string: number;
  fret: number;
}

export function FretboardExplorer() {
  const [root, setRoot] = useState(9); // A — a guitarist's home base
  const [mode, setMode] = useState<DisplayMode>("scale");
  const [scaleIndex, setScaleIndex] = useState(8); // Minor Pentatonic
  const [triadIndex, setTriadIndex] = useState(0);
  const [voicingQualityIndex, setVoicingQualityIndex] = useState(0);
  // One set index per set size, so switching triad ↔ seventh keeps context.
  const [setIndex3, setSetIndex3] = useState(3); // G · B · E
  const [setIndex4, setSetIndex4] = useState(2); // D · G · B · E
  const [inversionFilter, setInversionFilter] = useState<number | null>(null);
  const [hovered, setHovered] = useState<Hovered | null>(null);

  const voicingsMode = mode === "voicings";
  const voicingQuality = VOICING_QUALITIES[voicingQualityIndex];
  const isSeventh = voicingQuality.intervals.length === 4;
  const stringSets = isSeventh ? STRING_SETS_4 : STRING_SETS_3;
  const setIndex = isSeventh ? setIndex4 : setIndex3;
  const stringSet = stringSets[setIndex];
  const inversionCount = isSeventh ? 4 : 3;

  function pickVoicingQuality(index: number) {
    setVoicingQualityIndex(index);
    // A triad has no 3rd inversion — drop a stale filter back to All.
    if (VOICING_QUALITIES[index].intervals.length === 3 && inversionFilter === 3) {
      setInversionFilter(null);
    }
  }

  const voicings = useMemo(
    () =>
      isSeventh
        ? drop2(root, voicingQuality.intervals, stringSet)
        : triadInversions(root, voicingQuality.intervals, stringSet),
    [root, voicingQuality, stringSet, isSeventh],
  );
  const shownVoicings =
    inversionFilter === null
      ? voicings
      : voicings.filter((v) => v.inversion === inversionFilter);

  const intervals =
    mode === "scale"
      ? SCALE_TYPES[scaleIndex].intervals
      : mode === "triad"
        ? TRIAD_QUALITIES[triadIndex].intervals
        : voicingQuality.intervals;

  const selectionName =
    mode === "scale"
      ? `${noteName(root)} ${SCALE_TYPES[scaleIndex].name}`
      : mode === "triad"
        ? `${noteName(root)}${TRIAD_QUALITIES[triadIndex].symbol} triad`
        : `${noteName(root)}${voicingQuality.symbol} ${isSeventh ? "drop-2" : "triad"} voicings`;

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
            {(["scale", "triad", "voicings"] as const).map((m) => (
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
          ) : mode === "triad" ? (
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
          ) : (
            <div
              role="group"
              aria-label="Chord quality"
              className="flex flex-wrap gap-1"
            >
              {VOICING_QUALITIES.map((quality, i) => (
                <button
                  key={quality.name}
                  type="button"
                  aria-pressed={voicingQualityIndex === i}
                  onClick={() => pickVoicingQuality(i)}
                  className={`h-8 rounded-lg px-3 text-sm font-medium transition-colors duration-200 ${
                    voicingQualityIndex === i
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

        {voicingsMode && (
          <div className="flex flex-wrap items-center gap-x-4 gap-y-3">
            <span className="w-10 shrink-0 text-[11px] font-medium uppercase tracking-[0.14em] text-ink-mute">
              On
            </span>
            <div
              role="group"
              aria-label="String set"
              className="flex flex-wrap gap-1"
            >
              {stringSets.map((set, i) => (
                <button
                  key={stringSetLabel(set)}
                  type="button"
                  aria-pressed={setIndex === i}
                  onClick={() =>
                    isSeventh ? setSetIndex4(i) : setSetIndex3(i)
                  }
                  className={`h-8 rounded-lg px-2.5 text-sm font-medium tabular-nums transition-colors duration-200 ${
                    setIndex === i
                      ? "bg-white/10 text-ink"
                      : "text-ink-dim hover:bg-white/5 hover:text-ink"
                  }`}
                >
                  {stringSetLabel(set)}
                </button>
              ))}
            </div>
            <div
              role="group"
              aria-label="Inversion"
              className="flex flex-wrap gap-1"
            >
              {[null, ...Array.from({ length: inversionCount }, (_, i) => i)].map(
                (inv) => (
                  <button
                    key={inv === null ? "all" : inv}
                    type="button"
                    aria-pressed={inversionFilter === inv}
                    onClick={() => setInversionFilter(inv)}
                    className={`h-8 rounded-lg px-2.5 text-sm font-medium transition-colors duration-200 ${
                      inversionFilter === inv
                        ? "bg-white/10 text-ink"
                        : "text-ink-dim hover:bg-white/5 hover:text-ink"
                    }`}
                  >
                    {inv === null ? "All" : INVERSION_LABELS[inv]}
                  </button>
                ),
              )}
            </div>
          </div>
        )}
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
          {voicingsMode &&
            inversionFilter === null &&
            shownVoicings.map((v) => (
              <span
                key={v.inversion}
                className="font-mono text-xs tabular-nums text-ink-mute"
              >
                {v.label} · fret {v.lowestFret}
              </span>
            ))}
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
              // Voicings mode paints its own shapes; the grid stays as
              // hover targets only.
              const active = offset !== null && !voicingsMode;
              const isRoot = offset === 0 && !voicingsMode;
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

          {/* Voicing shapes: connector lines under chord-tone markers.
              pointerEvents none keeps the grid underneath as the single
              hover surface; the key remounts the group so it fades in on
              every selection change (respects reduced motion). */}
          {voicingsMode && (
            <g
              key={`${root}-${voicingQualityIndex}-${setIndex}-${inversionFilter ?? "all"}`}
              className="fade-in"
              pointerEvents="none"
            >
              {shownVoicings.map((v) => (
                <polyline
                  key={`line-${v.inversion}`}
                  points={v.steps
                    .map((step) => `${noteX(step.fret)},${stringY(step.string)}`)
                    .join(" ")}
                  fill="none"
                  stroke={SHAPE_STROKE}
                  strokeWidth={2}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              ))}
              {shownVoicings.map((v) =>
                v.steps.map((step) => (
                  <g key={`${v.inversion}-${step.string}`}>
                    <circle
                      cx={noteX(step.fret)}
                      cy={stringY(step.string)}
                      r={DOT_R}
                      className={TONE_FILL[step.tone]}
                      stroke="rgba(255,255,255,0.35)"
                      strokeWidth={1}
                    />
                    <text
                      x={noteX(step.fret)}
                      y={stringY(step.string)}
                      dy="0.36em"
                      textAnchor="middle"
                      className={`text-[11px] font-semibold ${
                        step.tone === 0 ? "fill-accent-deep" : "fill-base"
                      }`}
                    >
                      {TONE_MARKS[step.tone]}
                    </text>
                  </g>
                )),
              )}
            </g>
          )}
        </svg>
      </div>
    </div>
  );
}
