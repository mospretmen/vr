// Harmonized-scale ladder ported from the Swift core
// (packages/GuitarCore/Sources/MusicTheory/HarmonizedScale.swift and the
// diatonicTriads logic in Chord.swift) so the web explorer and the headset
// overlay agree rung-for-rung. Pure math over src/theory.ts + src/voicings.ts
// — no DOM, vitest'd.

import { noteName } from "./music";
import type { TriadQualityPreset } from "./theory";
import { TRIAD_QUALITIES } from "./theory";
import type { Voicing } from "./voicings";
import { triadInversions } from "./voicings";

/** One scale degree's diatonic triad. */
export interface DiatonicTriad {
  /** Pitch class (0–11) of the triad's root. */
  rootPc: number;
  quality: TriadQualityPreset;
  /** Chord symbol, e.g. "Dm", "B°". */
  symbol: string;
}

/** One rung of the harmonized ladder. */
export interface HarmonizedTriad {
  /** 1-based scale degree. */
  degree: number;
  /** Case-styled roman numeral: I, ii, vii°, III+ … */
  romanNumeral: string;
  /** Chord symbol, e.g. "C", "Dm", "B°". */
  symbol: string;
  triad: DiatonicTriad;
  voicing: Voicing;
}

const ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII"] as const;

const mod12 = (n: number) => ((n % 12) + 12) % 12;

/** Triad quality for a (third, fifth) semitone pair, mirroring Chord.swift. */
function qualityFor(third: number, fifth: number): TriadQualityPreset {
  for (const quality of TRIAD_QUALITIES) {
    if (quality.intervals[1] === third && quality.intervals[2] === fifth) {
      return quality;
    }
  }
  // Exotic stacks (e.g. in synthetic scales) keep their raw shape.
  return { name: "Custom", symbol: "?", intervals: [0, third, fifth] };
}

/**
 * The diatonic triads of a scale, one per degree: stack degrees i, i+2, i+4
 * (mod note count) and classify the quality by its (third, fifth) semitone
 * intervals — (4,7) major, (3,7) minor, (3,6) diminished, (4,8) augmented.
 * Scales with fewer than five notes return [].
 */
export function diatonicTriads(
  rootPc: number,
  scaleIntervals: readonly number[],
): DiatonicTriad[] {
  const pcs = scaleIntervals.map((i) => mod12(rootPc + i));
  if (pcs.length < 5) return [];
  return pcs.map((root, i) => {
    const third = pcs[(i + 2) % pcs.length];
    const fifth = pcs[(i + 4) % pcs.length];
    const quality = qualityFor(mod12(third - root), mod12(fifth - root));
    return { rootPc: root, quality, symbol: `${noteName(root)}${quality.symbol}` };
  });
}

/** Roman numeral for a 1-based degree, cased by quality (HarmonizedScale.swift). */
function romanNumeral(degree: number, quality: TriadQualityPreset): string {
  if (degree < 1 || degree > 7) return "?";
  const base = ROMAN[degree - 1];
  switch (quality.symbol) {
    case "m":
      return base.toLowerCase();
    case "°":
      return base.toLowerCase() + "°";
    case "+":
      return base + "+";
    default:
      return base;
  }
}

/**
 * The triad ladder for a scale on a 3-string set: walks degrees in order,
 * choosing for each the lowest voicing at or above the current neck
 * position, so the sequence never retreats. Seven-note scales produce seven
 * rungs; scales with any other note count return [].
 */
export function triadLadder(
  rootPc: number,
  scaleIntervals: readonly number[],
  strings: readonly number[],
): HarmonizedTriad[] {
  const triads = diatonicTriads(rootPc, scaleIntervals);
  if (triads.length !== 7) return [];

  const ladder: HarmonizedTriad[] = [];
  let position = 0;
  triads.forEach((triad, index) => {
    const voicings = triadInversions(triad.rootPc, triad.quality.intervals, strings);
    const voicing =
      voicings.find((v) => v.lowestFret >= position) ??
      voicings[voicings.length - 1];
    if (!voicing) return;
    ladder.push({
      degree: index + 1,
      romanNumeral: romanNumeral(index + 1, triad.quality),
      symbol: triad.symbol,
      triad,
      voicing,
    });
    position = voicing.lowestFret;
  });
  return ladder;
}
