// "Steal from the masters" — the Classics shelf, playable in the browser:
// pick a fragment, watch it on rosewood, hear it plucked, read why it works.
import { useMemo, useState } from "react";
import { playRun } from "../audio";
import { WEB_CLASSICS, stepMidi, stepPitchClass, type WebPhrase } from "../classicsData";

const SHARP = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"];

export function ClassicsShowcase() {
  const [index, setIndex] = useState(0);
  const phrase = WEB_CLASSICS[index];

  return (
    <section id="classics" className="scroll-mt-20 border-t border-line">
      <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <h2 className="font-display text-2xl font-bold tracking-tight sm:text-3xl">
          Steal from the masters.
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-ink-dim sm:text-base">
          A taste of the built-in phrase shelf: style-of fragments and
          public-domain themes, every one explained — and in the app,
          transposable to any key and importable into your own library.
        </p>
        <div className="stage-panel mt-8 rounded-3xl border border-line p-4 sm:p-6">
          <div className="flex flex-col gap-5 lg:flex-row">
            <div className="no-scrollbar max-h-[320px] w-full overflow-y-auto lg:max-w-xs">
              <ul className="space-y-1.5">
                {WEB_CLASSICS.map((p, i) => (
                  <li key={p.name}>
                    <button
                      onClick={() => {
                        setIndex(i);
                        playRun(p.steps.map(stepMidi));
                      }}
                      className={`w-full rounded-lg px-3 py-2 text-left text-sm transition-colors ${
                        i === index
                          ? "bg-fill text-ink"
                          : "text-ink-dim hover:bg-fill-soft hover:text-ink"
                      }`}
                    >
                      <span className="font-medium">{p.name}</span>
                      <span className="mt-0.5 block text-[11px] text-ink-mute">
                        {p.context ?? `over ${p.chord.symbol}`}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex items-baseline justify-between gap-3">
                <h3 className="font-display text-lg font-semibold text-ink">
                  {phrase.name}
                </h3>
                <button
                  onClick={() => playRun(phrase.steps.map(stepMidi))}
                  className="shrink-0 rounded-full bg-accent px-4 py-1.5 text-xs font-semibold text-accent-deep transition-opacity hover:opacity-90"
                >
                  ▶ Play
                </button>
              </div>
              <p className="mt-1 text-sm text-ink-dim">{phrase.remark}</p>
              <PhraseBoard phrase={phrase} />
              <p className="mt-2 text-[11px] text-ink-mute">
                {phrase.steps
                  .map((s) => SHARP[stepPitchClass(s)])
                  .join(" → ")}{" "}
                · over {phrase.chord.symbol}
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

/** The phrase on rosewood: a fret window fitted to the line, notes
 *  numbered in playing order. */
function PhraseBoard({ phrase }: { phrase: WebPhrase }) {
  const { start, span } = useMemo(() => {
    const frets = phrase.steps.map(([, f]) => f).filter((f) => f > 0);
    const low = Math.min(...(frets.length ? frets : [1]));
    const high = Math.max(...(frets.length ? frets : [4]), 4);
    const start = Math.max(1, Math.min(low, 11));
    return { start, span: Math.max(4, high - start + 1) };
  }, [phrase]);

  const W = 560;
  const H = 150;
  const left = phrase.steps.some(([, f]) => f === 0) ? 44 : 28;
  const gap = (W - left - 12) / span;
  const stringY = (s: number) => 16 + (5 - s) * ((H - 44) / 5);
  const wireX = (f: number) => left + (f - start + 1) * gap;
  const noteX = (f: number) => (f === 0 ? left - 16 : wireX(f) - gap / 2);

  const chordPCs = new Set(
    phrase.chord.intervals.map((i) => (phrase.chord.root + i) % 12),
  );

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="mt-4 w-full">
      <rect x={left} y={8} width={W - left - 8} height={H - 40} rx={6}
        fill="#4d2e1c" stroke="rgba(0,0,0,0.4)" />
      {start === 1 && (
        <rect x={left - 5} y={8} width={6} height={H - 40} rx={2} fill="#ded9cc" />
      )}
      {Array.from({ length: span + 1 }, (_, i) => (
        <line key={i} x1={wireX(start + i)} y1={10} x2={wireX(start + i)}
          y2={H - 34} stroke="rgba(210,210,214,0.7)" strokeWidth={2} />
      ))}
      {[0, 1, 2, 3, 4, 5].map((s) => (
        <line key={s} x1={left - 6} y1={stringY(s)} x2={W - 8} y2={stringY(s)}
          stroke="#c9c2b2" strokeWidth={2.4 - s * 0.3} opacity={0.85} />
      ))}
      <text x={wireX(start) - gap / 2} y={H - 16} textAnchor="middle"
        fontSize={11} fill="var(--color-ink-mute)">
        {start}
      </text>
      {phrase.steps.map((step, order) => {
        const [s, f] = step;
        const isChordTone = chordPCs.has(stepPitchClass(step));
        return (
          <g key={order}>
            <circle cx={noteX(f)} cy={stringY(s)} r={10}
              fill={isChordTone ? "var(--color-accent-strong)" : "#5eead4"}
              opacity={0.95} />
            <text x={noteX(f)} y={stringY(s) + 3.5} textAnchor="middle"
              fontSize={9.5} fontWeight={700} fill="#1a1208">
              {order + 1}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
