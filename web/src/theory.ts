// Pure music-theory data + fretboard math for the web explorer. Ported from
// the Swift core (packages/GuitarCore/Sources/MusicTheory) so the two stay in
// lockstep: same interval shapes, same catalogs. No DOM, no fetch — vitest'd.

/** A scale/mode preset: display name + semitone offsets from the root. */
export interface ScaleTypePreset {
  name: string;
  /** Strictly increasing semitone offsets, starting at 0, all within 0–11. */
  intervals: readonly number[];
}

/** Catalog shown in pickers, in display order (mirrors ScaleType.all). */
export const SCALE_TYPES: readonly ScaleTypePreset[] = [
  { name: "Major (Ionian)", intervals: [0, 2, 4, 5, 7, 9, 11] },
  { name: "Dorian", intervals: [0, 2, 3, 5, 7, 9, 10] },
  { name: "Phrygian", intervals: [0, 1, 3, 5, 7, 8, 10] },
  { name: "Lydian", intervals: [0, 2, 4, 6, 7, 9, 11] },
  { name: "Mixolydian", intervals: [0, 2, 4, 5, 7, 9, 10] },
  { name: "Minor (Aeolian)", intervals: [0, 2, 3, 5, 7, 8, 10] },
  { name: "Locrian", intervals: [0, 1, 3, 5, 6, 8, 10] },
  { name: "Major Pentatonic", intervals: [0, 2, 4, 7, 9] },
  { name: "Minor Pentatonic", intervals: [0, 3, 5, 7, 10] },
  { name: "Blues", intervals: [0, 3, 5, 6, 7, 10] },
  { name: "Harmonic Minor", intervals: [0, 2, 3, 5, 7, 8, 11] },
  { name: "Melodic Minor", intervals: [0, 2, 3, 5, 7, 9, 11] },
] as const;

/** A triad quality preset: name, chord-symbol suffix, interval shape. */
export interface TriadQualityPreset {
  name: string;
  symbol: string;
  intervals: readonly number[];
}

/** Triad catalog (mirrors ChordQuality's triad presets). */
export const TRIAD_QUALITIES: readonly TriadQualityPreset[] = [
  { name: "Major", symbol: "", intervals: [0, 4, 7] },
  { name: "Minor", symbol: "m", intervals: [0, 3, 7] },
  { name: "Diminished", symbol: "°", intervals: [0, 3, 6] },
  { name: "Augmented", symbol: "+", intervals: [0, 4, 8] },
] as const;

/**
 * Seventh-chord catalog (mirrors ChordQuality's seventh presets). Same shape
 * as the triad presets so pickers can mix the two catalogs freely.
 */
export const SEVENTH_QUALITIES: readonly TriadQualityPreset[] = [
  { name: "Major 7", symbol: "maj7", intervals: [0, 4, 7, 11] },
  { name: "Dominant 7", symbol: "7", intervals: [0, 4, 7, 10] },
  { name: "Minor 7", symbol: "m7", intervals: [0, 3, 7, 10] },
  { name: "Half-diminished", symbol: "m7♭5", intervals: [0, 3, 6, 10] },
] as const;

/**
 * Standard tuning as MIDI note numbers, string index 0 = lowest-pitched
 * string (E2 A2 D3 G3 B3 E4) — same convention as the Swift core.
 */
export const STANDARD_TUNING_MIDI: readonly number[] = [
  40, 45, 50, 55, 59, 64,
] as const;

export const STRING_COUNT = STANDARD_TUNING_MIDI.length;

/**
 * Pitch class (0–11, C = 0) sounding at `string`/`fret` in standard tuning.
 * Fret 0 is the open string. Throws on out-of-range input — callers iterate
 * fixed grids, so a bad index is a programmer error worth surfacing.
 */
export function noteAt(string: number, fret: number): number {
  if (!Number.isInteger(string) || string < 0 || string >= STRING_COUNT) {
    throw new RangeError(`string index out of range: ${string}`);
  }
  if (!Number.isInteger(fret) || fret < 0) {
    throw new RangeError(`fret must be a non-negative integer, got ${fret}`);
  }
  return (STANDARD_TUNING_MIDI[string] + fret) % 12;
}

/**
 * 1-based degree of pitch class `pc` in the scale/chord rooted at `root`
 * with the given interval shape, or null when `pc` is not in the shape.
 * E.g. scaleDegree(0, MAJOR, 11) → 7 (B is the 7th of C major).
 */
export function scaleDegree(
  root: number,
  intervals: readonly number[],
  pc: number,
): number | null {
  const offset = (((pc - root) % 12) + 12) % 12;
  const index = intervals.indexOf(offset);
  return index === -1 ? null : index + 1;
}

/**
 * Normalized fret-wire positions for a board truncated at `fretCount` frets.
 * Physical fret n sits at 1 − 2^(−n/12) of the scale length; we renormalize
 * so the last rendered fret lands at 1.0. Index 0 is the nut (0.0).
 */
export function fretPositions(fretCount: number): number[] {
  if (!Number.isInteger(fretCount) || fretCount < 1) {
    throw new RangeError(`fretCount must be a positive integer, got ${fretCount}`);
  }
  const span = 1 - 2 ** (-fretCount / 12);
  const positions: number[] = [];
  for (let n = 0; n <= fretCount; n++) {
    positions.push((1 - 2 ** (-n / 12)) / span);
  }
  return positions;
}
