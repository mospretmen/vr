// Per-degree chord-scale cards for the web demo — ports of the Swift
// core's HarmonizedScale.seventhChords / .tensions and Modes.degreeModeNames,
// pinned in degreeCells.test.ts against the same textbook rows.
import { spellScale, type ScaleSuggestion } from "./demoVoicings";

export interface DegreeCell {
  roman: string;
  chordSymbol: string;
  tensions: string[]; // avoid notes parenthesized
  mode: string | null;
}

const SEVENTH_QUALITIES: [number[], string, boolean][] = [
  // intervals, symbol suffix, isMinorCased
  [[0, 4, 7, 11], "maj7", false],
  [[0, 4, 7, 10], "7", false],
  [[0, 3, 7, 10], "m7", true],
  [[0, 3, 6, 10], "m7♭5", true],
  [[0, 3, 6, 9], "°7", true],
  [[0, 3, 7, 11], "m(maj7)", true],
  [[0, 4, 8, 11], "maj7♯5", false],
  [[0, 4, 8, 10], "7♯5", false],
];

const MODE_NAMES: Record<string, string> = {
  "0,2,4,5,7,9,11": "Ionian",
  "0,2,3,5,7,9,10": "Dorian",
  "0,1,3,5,7,8,10": "Phrygian",
  "0,2,4,6,7,9,11": "Lydian",
  "0,2,4,5,7,9,10": "Mixolydian",
  "0,2,3,5,7,8,10": "Aeolian",
  "0,1,3,5,6,8,10": "Locrian",
  "0,2,3,5,7,9,11": "Melodic minor",
  "0,1,3,5,7,9,10": "Dorian ♭2",
  "0,2,4,6,8,9,11": "Lydian augmented",
  "0,2,4,6,7,9,10": "Lydian dominant",
  "0,2,4,5,7,8,10": "Mixolydian ♭6",
  "0,2,3,5,6,8,10": "Locrian ♮2",
  "0,1,3,4,6,8,10": "Altered",
  "0,2,3,5,7,8,11": "Harmonic minor",
  "0,1,3,5,6,9,10": "Locrian ♮6",
  "0,2,4,5,8,9,11": "Ionian ♯5",
  "0,2,3,6,7,9,10": "Dorian ♯4",
  "0,1,4,5,7,8,10": "Phrygian dominant",
  "0,3,4,6,7,9,11": "Lydian ♯2",
  "0,1,3,4,6,8,9": "Super Locrian 𝄫7",
};

const ROMANS = ["I", "II", "III", "IV", "V", "VI", "VII"];
const TENSION_LABELS: Record<number, string> = {
  1: "♭9", 2: "9", 3: "♯9", 4: "3", 5: "11", 6: "♯11",
  7: "5", 8: "♭13", 9: "13", 10: "♭7", 11: "♮7",
};
const MAJOR_DEGREES = [0, 2, 4, 5, 7, 9, 11];

/** The full chord-scale card per degree of a 7-note scale; [] otherwise. */
export function degreeCells(root: number, scale: ScaleSuggestion): DegreeCell[] {
  const intervals = scale.intervals;
  if (intervals.length !== 7) return [];
  const names = spellScale(root, intervals);

  return intervals.map((_, degree) => {
    const chordIntervals = [0, 2, 4, 6].map(
      (step) =>
        (((intervals[(degree + step) % 7] - intervals[degree]) % 12) + 12) % 12,
    );
    const match = SEVENTH_QUALITIES.find(
      ([pattern]) => pattern.join() === chordIntervals.join(),
    );
    const [, suffix, minorCased] = match ?? [[], "7?", false];

    // Roman numeral with accidental vs the major scale, cased by quality.
    let diff = intervals[degree] - MAJOR_DEGREES[degree];
    if (diff > 6) diff -= 12;
    if (diff < -6) diff += 12;
    const accidental = diff === -1 ? "♭" : diff === 1 ? "♯" : diff === -2 ? "𝄫" : "";
    let roman = ROMANS[degree];
    if (minorCased) roman = roman.toLowerCase();
    const ornament =
      suffix === "m7♭5" ? "ø" : suffix === "°7" ? "°" : suffix.includes("♯5") ? "+" : "";

    // Tensions: leftover scale tones labeled from the chord root; avoid =
    // half-step above a chord tone, except dominant colors ♭9/♯9/♭13.
    const chordSet = new Set(chordIntervals.map((s) => (intervals[degree] + s) % 12));
    const isDominant = chordIntervals.includes(4) && chordIntervals.includes(10);
    const tensions = intervals
      .map((s) => (root + s) % 12)
      .filter((pc) => !chordSet.has((pc - root + 12) % 12 === 0 ? pc : pc) || true)
      .map((pc) => (((pc - ((root + intervals[degree]) % 12)) % 12) + 12) % 12)
      .filter((semis) => !chordIntervals.includes(semis))
      .map((semis) => {
        const label = TENSION_LABELS[semis] ?? String(semis);
        const halfAbove = chordIntervals.includes((semis - 1 + 12) % 12);
        const color = isDominant && ["♭9", "♯9", "♭13"].includes(label);
        return halfAbove && !color ? `(${label})` : label;
      });

    const rotated = Array.from({ length: 7 }, (_, i) =>
      (((intervals[(degree + i) % 7] - intervals[degree]) % 12) + 12) % 12,
    );

    return {
      roman: accidental + roman + ornament,
      chordSymbol: names[degree] + suffix,
      tensions,
      mode: MODE_NAMES[rotated.join()] ?? null,
    };
  });
}
