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
