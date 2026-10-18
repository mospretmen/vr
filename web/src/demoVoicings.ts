// Scales + grips for the web compass demo — ported from the Swift core's
// ChordScales and the published-chart grip templates, scoped to the four
// wheel qualities. Parity pinned in demoVoicings.test.ts.
import type { CompassNode } from "./compass";

export interface ScaleSuggestion {
  name: string;
  intervals: readonly number[];
}

const SCALES: Record<string, readonly number[]> = {
  "Major (Ionian)": [0, 2, 4, 5, 7, 9, 11],
  Lydian: [0, 2, 4, 6, 7, 9, 11],
  "Major Pentatonic": [0, 2, 4, 7, 9],
  Mixolydian: [0, 2, 4, 5, 7, 9, 10],
  "Double Harmonic": [0, 1, 4, 5, 7, 8, 11],
  "Minor (Aeolian)": [0, 2, 3, 5, 7, 8, 10],
  Dorian: [0, 2, 3, 5, 7, 9, 10],
  Phrygian: [0, 1, 3, 5, 7, 8, 10],
  "Harmonic Minor": [0, 2, 3, 5, 7, 8, 11],
  "Melodic Minor": [0, 2, 3, 5, 7, 9, 11],
  "Minor Pentatonic": [0, 3, 5, 7, 10],
  Blues: [0, 3, 5, 6, 7, 10],
  "Hungarian Minor": [0, 2, 3, 6, 7, 8, 11],
  "Lydian Dominant": [0, 2, 4, 6, 7, 9, 10],
  Altered: [0, 1, 3, 4, 6, 8, 10],
  "Half-Whole Diminished": [0, 1, 3, 4, 6, 7, 9, 10],
  "Whole Tone": [0, 2, 4, 6, 8, 10],
  "Phrygian Dominant": [0, 1, 4, 5, 7, 8, 10],
  "Bebop Dominant": [0, 2, 4, 5, 7, 9, 10, 11],
  "Whole-Half Diminished": [0, 2, 3, 5, 6, 8, 9, 11],
};

/** Mirrors ChordScales.suggestions(for:) for the wheel's four qualities. */
export function scaleSuggestions(node: CompassNode): ScaleSuggestion[] {
  const names: string[] = (() => {
    switch (node.ring) {
      case "majorKey":
        return ["Major (Ionian)", "Lydian", "Major Pentatonic", "Mixolydian", "Double Harmonic"];
      case "relativeMinor":
        return ["Minor (Aeolian)", "Dorian", "Phrygian", "Harmonic Minor",
                "Melodic Minor", "Minor Pentatonic", "Blues", "Hungarian Minor"];
      case "dominant":
        return ["Mixolydian", "Lydian Dominant", "Altered", "Half-Whole Diminished",
                "Whole Tone", "Phrygian Dominant", "Bebop Dominant", "Blues"];
      case "diminished":
        return ["Whole-Half Diminished"];
    }
  })();
  return names.map((name) => ({ name, intervals: SCALES[name] }));
}

const SHARP = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"];
const FLAT = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"];
const FLAT_DEGREES = new Set([1, 3, 6, 8, 10]);

/** Flat-side degrees spell flat — the Swift core's convention. */
export function spellScale(root: number, intervals: readonly number[]): string[] {
  return intervals.map((semis) => {
    const pc = (root + semis) % 12;
    return FLAT_DEGREES.has(semis) ? FLAT[pc] : SHARP[pc];
  });
}

// ---- Grips: published movable shapes, E-root and A-root ----

export interface Grip {
  /** Fret per string low→high, null = muted. */
  frets: (number | null)[];
  positionLabel: string;
}

/** Standard-tuning open-string pitch classes, low E → high E. */
export const OPEN_PCS = [4, 9, 2, 7, 11, 4] as const;

/** Offsets from the root fret per string; anchor string carries 0. */
const TEMPLATES: Record<CompassNode["ring"], (number | null)[][]> = {
  majorKey: [
    [0, 2, 2, 1, 0, 0],        // E shape
    [null, 0, 2, 2, 2, 0],     // A shape
  ],
  relativeMinor: [
    [0, 2, 2, 0, 0, 0],        // Em shape
    [null, 0, 2, 2, 1, 0],     // Am shape
  ],
  dominant: [
    [0, 2, 0, 1, 0, 0],        // E7 shape (G7 = 353433)
    [null, 0, 2, 0, 2, 0],     // A7 shape (C7 = x35353)
  ],
  diminished: [
    [0, null, -1, 0, -1, null],  // °7 E-root (G°7 = 3x232x)
    [null, 0, 1, -1, 1, null],   // °7 A-root (C°7 = x3424x)
  ],
};

/** The VR app's curated grip dictionary, per wheel family: movable shapes
 *  exactly as chord charts print them (ChordGripTemplates parity). */
const QUALITY_SHAPES: Record<CompassNode["ring"], [string, (number | null)[][]][]> = {
  majorKey: [
    ["", TEMPLATES.majorKey],
    ["6", [[0, null, -1, 1, 0, null], [null, 0, 2, 2, 2, 2]]],
    ["6/9", [[null, 0, -1, -1, 0, 0]]],
    ["maj7", [[0, null, 1, 1, 0, null], [null, 0, 2, 1, 2, 0]]],
    ["maj9", [[null, 0, -1, 1, 0, null]]],
  ],
  relativeMinor: [
    ["m", TEMPLATES.relativeMinor],
    ["m6", [[0, null, -1, 0, 0, null], [null, 0, -2, -1, -2, null]]],
    ["m7", [[0, 2, 0, 0, 0, 0], [null, 0, 2, 0, 1, 0]]],
    ["m9", [[null, 0, -2, 0, 0, 0], [0, 2, 0, 0, 0, 2]]],
    ["m11", [[0, null, 0, 0, -2, null], [0, 0, 0, 0, 0, 0], [null, 0, 0, 0, 1, null]]],
    ["m(maj7)", [[0, null, 1, 0, 0, null], [null, 0, 2, 1, 1, null]]],
  ],
  dominant: [
    ["7", TEMPLATES.dominant],
    ["9", [[null, 0, -1, 0, 0, 0]]],
    ["13", [[null, 0, -1, 0, 0, 2]]],
    ["7♭9", [[null, 0, -1, 0, -1, null]]],
    ["7♯9", [[null, 0, -1, 0, 1, null]]],
    ["7♯5", [[0, null, 0, 1, 1, null]]],
    ["7♭5", [[0, null, 0, 1, -1, null]]],
    ["7sus4", [[null, 0, 2, 0, 3, 0]]],
    ["9sus4", [[null, 0, 0, 0, 0, 0]]],
  ],
  diminished: [
    ["°7", TEMPLATES.diminished],
    ["ø7", [[0, null, 0, 0, -1, null], [null, 0, 1, 0, 1, null]]],
  ],
};

function instantiate(shapes: (number | null)[][], root: number): Grip[] {
  const grips: Grip[] = [];
  for (const offsets of shapes) {
    const anchor = offsets.findIndex((o) => o !== null);
    for (let rootFret = 0; rootFret <= 12; rootFret++) {
      if ((OPEN_PCS[anchor] + rootFret) % 12 !== root) continue;
      const frets = offsets.map((o) => (o === null ? null : rootFret + o));
      if (frets.some((f) => f !== null && (f < 0 || f > 14))) continue;
      const fretted = frets.filter((f): f is number => f !== null && f > 0);
      const low = fretted.length ? Math.min(...fretted) : 0;
      grips.push({ frets, positionLabel: low === 0 ? "Open" : `fret ${low}` });
    }
  }
  const seen = new Set<string>();
  return grips
    .filter((g) => {
      const key = g.frets.join(",");
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) => gripLow(a) - gripLow(b))
    .slice(0, 4);
}

export interface GripFamily {
  /** Chord-symbol suffix: "", "6/9", "maj9"… */
  suffix: string;
  grips: Grip[];
  /** Four-note interval content when the quality supports inversions. */
  seventhIntervals: number[] | null;
}

/** Interval content per suffix — drives the drop-2 inversion engine. */
const SUFFIX_INTERVALS: Record<string, number[]> = {
  "6": [0, 4, 7, 9], "maj7": [0, 4, 7, 11], "maj9": [0, 4, 7, 11],
  "m6": [0, 3, 7, 9], "m7": [0, 3, 7, 10], "m9": [0, 3, 7, 10],
  "m(maj7)": [0, 3, 7, 11],
  "7": [0, 4, 7, 10], "9": [0, 4, 7, 10], "13": [0, 4, 7, 10],
  "7♭9": [0, 4, 7, 10], "7♯9": [0, 4, 7, 10],
  "7♯5": [0, 4, 8, 10], "7♭5": [0, 4, 6, 10], "7sus4": [0, 5, 7, 10],
  "°7": [0, 3, 6, 9], "ø7": [0, 3, 6, 10],
};

/** Every quality the VR grip dictionary knows for this node's family. */
export function gripFamilies(node: CompassNode): GripFamily[] {
  return QUALITY_SHAPES[node.ring]
    .map(([suffix, shapes]) => ({
      suffix,
      grips: instantiate(shapes, node.root),
      seventhIntervals: SUFFIX_INTERVALS[suffix] ?? null,
    }))
    .filter((f) => f.grips.length > 0);
}

export const STRING_SETS: [number, number, number, number][] = [
  [0, 1, 2, 3], [1, 2, 3, 4], [2, 3, 4, 5],
];
export const STRING_SET_LABELS = ["6–3", "5–2", "4–1"];
/** Drop-3 lives on the skipped-string sets, as Joe Pass played them. */
export const DROP3_SETS: [number, number, number, number][] = [
  [0, 2, 3, 4], [1, 3, 4, 5],
];
export const DROP3_SET_LABELS = ["6·432", "5·321"];
export const INVERSION_LABELS = ["Root", "1st inv", "2nd inv", "3rd inv"];

/** Drop-2 voicing of a seventh chord on an adjacent 4-string set — the
 *  VR Inversions tab's engine. Returns the playable grip, or null when no
 *  one-position fingering exists on that set. */
export function drop2Grip(
  root: number, intervals: number[],
  set: [number, number, number, number], inversion: number,
): Grip | null {
  return dropGrip(root, intervals, set, inversion, 2);
}

export function dropGrip(
  root: number, intervals: number[],
  set: [number, number, number, number], inversion: number,
  drop: 2 | 3,
): Grip | null {
  // Close-position stack chosen so the named inversion's note lands in the
  // bass after the drop (players name these voicings by their bass note).
  // Drop-2 lowers the 2nd voice from the top; drop-3 the 3rd.
  const start = drop === 2 ? inversion + 2 : inversion + 3;
  const stack = Array.from({ length: 4 }, (_, v) =>
    (root + intervals[(start + v) % 4]) % 12);
  const voiced = drop === 2
    ? [stack[2], stack[0], stack[1], stack[3]]
    : [stack[1], stack[0], stack[2], stack[3]]; // low→high
  // Choose, per string, the lowest fret sounding its voice, allowing +12
  // to minimise the hand span (opens count toward the span).
  const base = voiced.map((pc, k) => ((pc - OPEN_PCS[set[k]]) % 12 + 12) % 12);
  let best: number[] | null = null;
  let bestSpan = 99;
  for (let mask = 0; mask < 16; mask++) {
    const frets = base.map((f, k) => (mask & (1 << k) ? f + 12 : f));
    if (frets.some((f) => f > 14)) continue;
    const span = Math.max(...frets) - Math.min(...frets);
    if (span <= 5 && span < bestSpan) {
      best = frets;
      bestSpan = span;
    }
  }
  if (!best) return null;
  const all: (number | null)[] = [null, null, null, null, null, null];
  set.forEach((stringIndex, k) => { all[stringIndex] = best![k]; });
  const fretted = best.filter((f) => f > 0);
  const low = fretted.length ? Math.min(...fretted) : 0;
  return { frets: all, positionLabel: low === 0 ? "Open" : `fret ${low}` };
}

export interface DyadKind {
  label: string;
  /** Interval indices into the chord's 4-note content, low voice first. */
  voices: [number, number];
}

/** Guide-tone and sixth dyads — the two-note vocabulary (3+7, 7+3, R+3). */
export const DYAD_KINDS: DyadKind[] = [
  { label: "3 + 7", voices: [1, 3] },
  { label: "7 + 3", voices: [3, 1] },
  { label: "R + 3", voices: [0, 1] },
  { label: "3 + 5", voices: [1, 2] },
];
export const DYAD_PAIRS: [number, number][] = [[2, 3], [3, 4], [4, 5], [2, 4]];
export const DYAD_PAIR_LABELS = ["4·3", "3·2", "2·1", "4·2"];

/** All positions of a two-voice dyad up the neck on one string pair. */
export function dyadGrips(
  root: number, intervals: number[],
  kind: DyadKind, pair: [number, number],
): Grip[] {
  const pcLow = (root + intervals[kind.voices[0]]) % 12;
  const pcHigh = (root + intervals[kind.voices[1]]) % 12;
  const grips: Grip[] = [];
  for (let base = 0; base <= 14; base++) {
    if ((OPEN_PCS[pair[0]] + base) % 12 !== pcLow) continue;
    // Highest-string fret nearest the low voice.
    let f = ((pcHigh - OPEN_PCS[pair[1]]) % 12 + 12) % 12;
    while (f < base - 3) f += 12;
    if (f > 14 || Math.abs(f - base) > 4) continue;
    const all: (number | null)[] = [null, null, null, null, null, null];
    all[pair[0]] = base;
    all[pair[1]] = f;
    const low = Math.min(...[base, f].filter((x) => x > 0));
    grips.push({ frets: all, positionLabel: base === 0 && f === 0 ? "Open" : `fret ${low}` });
  }
  return grips.slice(0, 5);
}

export function gripsFor(node: CompassNode): Grip[] {
  const grips: Grip[] = [];
  for (const offsets of TEMPLATES[node.ring]) {
    const anchor = offsets.findIndex((o) => o !== null);
    for (let rootFret = 0; rootFret <= 12; rootFret++) {
      if ((OPEN_PCS[anchor] + rootFret) % 12 !== node.root) continue;
      const frets = offsets.map((o) => (o === null ? null : rootFret + o));
      if (frets.some((f) => f !== null && (f < 0 || f > 14))) continue;
      const low = Math.min(...frets.filter((f): f is number => f !== null && f > 0), 99);
      grips.push({
        frets,
        positionLabel: low === 99 || low === 0 ? "Open" : `fret ${low}`,
      });
    }
  }
  const seen = new Set<string>();
  return grips
    .filter((g) => {
      const key = g.frets.join(",");
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) => gripLow(a) - gripLow(b))
    .slice(0, 4);
}

function gripLow(g: Grip): number {
  const fretted = g.frets.filter((f): f is number => f !== null && f > 0);
  return fretted.length ? Math.min(...fretted) : 0;
}

/** Chord-tone role per sounded position: 0 root, 1 third, 2 fifth, 3 seventh. */
export function toneRole(node: CompassNode, stringIndex: number, fret: number): number {
  const pc = (OPEN_PCS[stringIndex] + fret) % 12;
  const semis = (pc - node.root + 12) % 12;
  if (semis === 0) return 0;
  if (semis >= 2 && semis <= 5) return 1;
  if (semis >= 6 && semis <= 8) return 2;
  return 3;
}


/** One-line character notes per scale — mirrors the headset's ScaleLore. */
export const SCALE_LORE: Record<string, string> = {
  "Major (Ionian)": "The home base — bright, stable, resolved. Everything else is measured against it.",
  Dorian: "Minor with a bright natural 6 — the classic cool jazz and funk minor sound.",
  Phrygian: "Dark minor with a ♭2 — Spanish and modern-metal flavor.",
  Lydian: "Major with a raised 4 — floating, dreamy, film-score openness.",
  Mixolydian: "Major with a ♭7 — the dominant-chord scale; blues, rock and funk live here.",
  "Minor (Aeolian)": "The pure minor — melancholy, songlike, the relative shadow of major.",
  Locrian: "Unstable by design (♭2 and ♭5) — at home only over half-diminished chords.",
  "Major Pentatonic": "Five safe, open notes of major — country, gospel, and singable solos.",
  "Minor Pentatonic": "The guitarist's mother tongue — five notes, infinite blues and rock.",
  Blues: "Minor pentatonic plus the ♭5 'blue note' — tension you bend through, not sit on.",
  "Harmonic Minor": "Minor with a raised 7 — the dramatic pull home; neoclassical and gypsy heat.",
  "Melodic Minor": "Minor with a bright 6 and 7 — the jazz minor, smooth on the way up.",
  "Phrygian Dominant": "Harmonic minor's 5th mode — flamenco and metal fire over a dominant.",
  "Lydian Dominant": "Mixolydian with a ♯4 — the hip altered-but-not-too-altered dominant color.",
  "Bebop Dominant": "Mixolydian plus a passing major 7 — eight notes that keep chord tones on the beat.",
};
