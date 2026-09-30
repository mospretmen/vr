// Pure music-formatting helpers. Kept free of DOM/fetch so they can run
// under vitest's node environment.

import type { Chord, Key } from "./api";

/** Pitch-class names, index 0-11 (C = 0), sharps only. */
export const NOTE_NAMES = [
  "C",
  "C♯",
  "D",
  "D♯",
  "E",
  "F",
  "F♯",
  "G",
  "G♯",
  "A",
  "A♯",
  "B",
] as const;

/** Map any integer pitch class to its note name (wraps mod 12). */
export function noteName(pitchClass: number): string {
  if (!Number.isInteger(pitchClass)) {
    throw new RangeError(`pitch class must be an integer, got ${pitchClass}`);
  }
  return NOTE_NAMES[((pitchClass % 12) + 12) % 12];
}

/** Chord symbol, e.g. root 9 + "7" → "A7", root 2 + "m7" → "Dm7". */
export function chordSymbol(chord: Pick<Chord, "root" | "quality">): string {
  return `${noteName(chord.root)}${chord.quality.symbol}`;
}

/** Key label, e.g. "A Blues", "C Major (Ionian)". */
export function formatKey(key: Key): string {
  return `${noteName(key.root)} ${key.type.name}`;
}
