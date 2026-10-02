// Voicing-shape solvers ported from the Swift core
// (packages/GuitarCore/Sources/MusicTheory/TriadVoicing.swift and
// SeventhVoicing.swift) so the web explorer and the headset overlay agree
// fret-for-fret. Pure math over src/theory.ts — no DOM, vitest'd.

import { STANDARD_TUNING_MIDI, noteAt } from "./theory";

/** One sounded note of a voicing. */
export interface VoicingStep {
  /** String index, 0 = lowest-pitched string. */
  string: number;
  /** Fret, 0 = open. */
  fret: number;
  /** Absolute MIDI pitch sounding at string/fret in standard tuning. */
  midi: number;
  /**
   * 0-based chord-tone index into the quality's intervals:
   * 0 = root, 1 = third, 2 = fifth, 3 = seventh.
   */
  tone: number;
}

/** One inversion of a chord voiced on a specific string set. */
export interface Voicing {
  /** 0 = root position, 1 = 1st inversion, 2 = 2nd, 3 = 3rd. */
  inversion: number;
  /** Player-facing label, e.g. "1st inversion". */
  label: string;
  /** Chord-tone index (into intervals) sounding at the bottom. */
  bassTone: number;
  /** Bottom-to-top (strictly ascending pitch), one step per string. */
  steps: VoicingStep[];
  lowestFret: number;
}

export const INVERSION_LABELS = [
  "Root position",
  "1st inversion",
  "2nd inversion",
  "3rd inversion",
] as const;

/** The canonical 3-string sets, low to high (0 = lowest-pitched string). */
export const STRING_SETS_3: readonly (readonly number[])[] = [
  [0, 1, 2],
  [1, 2, 3],
  [2, 3, 4],
  [3, 4, 5],
] as const;

/** The canonical 4-string sets, low to high. */
export const STRING_SETS_4: readonly (readonly number[])[] = [
  [0, 1, 2, 3],
  [1, 2, 3, 4],
  [2, 3, 4, 5],
] as const;

const mod12 = (n: number) => ((n % 12) + 12) % 12;

/**
 * Lowest fret combination putting `pitchClasses[i]` on `strings[i]` with
 * strictly ascending sounding pitch and a hand-sized fret spread. Depth-first
 * over the per-string candidate frets with ascending-pitch pruning, minimizing
 * (lowest fret of the voicing, then spread); open strings are excluded from
 * the spread math. Works for any voice count (triads, drop-2 sevenths, …).
 * Returns bottom-to-top frets, or null when no combination fits.
 */
export function lowestVoicing(
  pitchClasses: readonly number[],
  strings: readonly number[],
  maxFret = 22,
  maxSpan = 4,
): number[] | null {
  if (pitchClasses.length !== strings.length) {
    throw new RangeError(
      `pitchClasses (${pitchClasses.length}) and strings (${strings.length}) must pair up`,
    );
  }

  const candidates = strings.map((string, i) => {
    const pc = mod12(pitchClasses[i]);
    const frets: number[] = [];
    for (let fret = 0; fret <= maxFret; fret++) {
      if (noteAt(string, fret) === pc) frets.push(fret);
    }
    return frets;
  });
  if (candidates.some((frets) => frets.length === 0)) return null;

  let best: number[] | null = null;
  let bestLow = Infinity;
  let bestSpread = Infinity;
  const chosen: number[] = [];

  function search(voice: number): void {
    if (voice === candidates.length) {
      const fretted = chosen.filter((f) => f > 0);
      const spread =
        fretted.length === 0
          ? 0
          : Math.max(...fretted) - Math.min(...fretted) + 1;
      if (spread > maxSpan) return;
      const low = Math.min(...chosen);
      if (low < bestLow || (low === bestLow && spread < bestSpread)) {
        bestLow = low;
        bestSpread = spread;
        best = [...chosen];
      }
      return;
    }
    const floor =
      voice === 0
        ? -Infinity
        : STANDARD_TUNING_MIDI[strings[voice - 1]] + chosen[voice - 1];
    for (const fret of candidates[voice]) {
      // Prune: voices must ascend in pitch as we stack upward.
      if (STANDARD_TUNING_MIDI[strings[voice]] + fret <= floor) continue;
      chosen.push(fret);
      search(voice + 1);
      chosen.pop();
    }
  }
  search(0);
  return best;
}

/** Solve one ordering (tone indices, bottom-to-top) into a Voicing. */
function solve(
  inversion: number,
  toneOrder: readonly number[],
  tonePcs: readonly number[],
  strings: readonly number[],
  maxFret: number,
  maxSpan: number,
): Voicing | null {
  const frets = lowestVoicing(
    toneOrder.map((t) => tonePcs[t]),
    strings,
    maxFret,
    maxSpan,
  );
  if (!frets) return null;
  const steps = frets.map((fret, i) => ({
    string: strings[i],
    fret,
    midi: STANDARD_TUNING_MIDI[strings[i]] + fret,
    tone: toneOrder[i],
  }));
  return {
    inversion,
    label: INVERSION_LABELS[inversion],
    bassTone: toneOrder[0],
    steps,
    lowestFret: Math.min(...frets),
  };
}

/**
 * All three inversions of a triad on a 3-string set, each voiced at its
 * lowest playable spot, ordered up the neck. Qualities with fewer than three
 * distinct tones (power-chord-ish input) return [].
 */
export function triadInversions(
  rootPc: number,
  intervals: readonly number[],
  strings: readonly number[],
  maxFret = 22,
  maxSpan = 4,
): Voicing[] {
  if (strings.length !== 3) {
    throw new RangeError("Triad voicings use exactly three strings");
  }
  const tones = intervals.slice(0, 3).map((i) => mod12(rootPc + i));
  if (new Set(tones).size !== 3) return [];

  // Bottom-to-top chord-tone orders per inversion.
  const orderings: readonly (readonly number[])[] = [
    [0, 1, 2], // root position
    [1, 2, 0], // 1st inversion — third in the bass
    [2, 0, 1], // 2nd inversion — fifth in the bass
  ];
  return orderings
    .flatMap((order, inv) => {
      const voicing = solve(inv, order, tones, strings, maxFret, maxSpan);
      return voicing ? [voicing] : [];
    })
    .sort((a, b) => a.lowestFret - b.lowestFret);
}

/**
 * All four drop-2 inversions of a seventh chord on a 4-string set, each at
 * its lowest playable spot, ordered up the neck. Returns [] for qualities
 * without four distinct tones (triads).
 *
 * Each close-position inversion with its 2nd-highest voice dropped an octave
 * into the bass, labeled by the resulting bass tone:
 *   close 5-7-1-3 → drop the 1 → 1-5-7-3  (root in bass)
 *   close 7-1-3-5 → drop the 3 → 3-7-1-5  (3rd in bass)
 *   close 1-3-5-7 → drop the 5 → 5-1-3-7  (5th in bass)
 *   close 3-5-7-1 → drop the 7 → 7-3-5-1  (7th in bass)
 */
export function drop2(
  rootPc: number,
  intervals: readonly number[],
  strings: readonly number[],
  maxFret = 22,
  maxSpan = 5,
): Voicing[] {
  if (strings.length !== 4) {
    throw new RangeError("Drop-2 voicings use exactly four strings");
  }
  const tones = intervals.slice(0, 4).map((i) => mod12(rootPc + i));
  if (new Set(tones).size !== 4) return [];

  const orderings: readonly (readonly number[])[] = [
    [0, 2, 3, 1], // root position: 1-5-7-3
    [1, 3, 0, 2], // 1st inversion: 3-7-1-5
    [2, 0, 1, 3], // 2nd inversion: 5-1-3-7
    [3, 1, 2, 0], // 3rd inversion: 7-3-5-1
  ];
  return orderings
    .flatMap((order, inv) => {
      const voicing = solve(inv, order, tones, strings, maxFret, maxSpan);
      return voicing ? [voicing] : [];
    })
    .sort((a, b) => a.lowestFret - b.lowestFret);
}
