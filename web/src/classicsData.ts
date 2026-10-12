// A curated slice of the app's Classics shelf for the web showcase —
// style-of fragments and verbatim public-domain themes, mirroring
// packages/GuitarCore BuiltInPhrases (sanity-pinned in classicsData.test.ts).
import { OPEN_PCS } from "./demoVoicings";

export interface WebPhrase {
  name: string;
  /** [stringIndex low→high, fret][] in playing order. */
  steps: [number, number][];
  /** Chord context: root pitch class + intervals + display symbol. */
  chord: { root: number; intervals: number[]; symbol: string };
  context?: string;
  remark: string;
}

export function stepMidi([string, fret]: [number, number]): number {
  const OPEN_MIDI = [40, 45, 50, 55, 59, 64];
  return OPEN_MIDI[string] + fret;
}

export function stepPitchClass(step: [number, number]): number {
  return (OPEN_PCS[step[0]] + step[1]) % 12;
}

export const WEB_CLASSICS: WebPhrase[] = [
  {
    name: "Enclosure of the 3rd (style of Parker)",
    steps: [[4, 6], [4, 4], [4, 5]],
    chord: { root: 0, intervals: [0, 4, 7, 11], symbol: "Cmaj7" },
    remark: "Surround the target from above and a half step below, then land — bebop's signature move.",
  },
  {
    name: "ii–V–I pocket (style of Parker)",
    steps: [[2, 3], [2, 7], [3, 5], [4, 5], [3, 7], [3, 4], [3, 5]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    context: "ii–V–I in C",
    remark: "Arpeggiate the ii, enclose the landing root — two bars of bebop in seven notes.",
  },
  {
    name: "Octave riff cell (style of Wes)",
    steps: [[3, 5], [3, 3], [2, 5], [3, 3], [3, 5]],
    chord: { root: 0, intervals: [0, 3, 7, 10], symbol: "Cm7" },
    remark: "Play it doubled an octave up with the thumb — melody first, always singable.",
  },
  {
    name: "Chromatic drop to the root (style of Joe Pass)",
    steps: [[3, 4], [3, 3], [3, 2], [3, 1], [3, 0]],
    chord: { root: 7, intervals: [0, 4, 7, 10], symbol: "G7" },
    remark: "Walk the 3rd down chromatically until it becomes the root.",
  },
  {
    name: "Four notes and air (style of Miles)",
    steps: [[2, 7], [3, 5], [3, 7], [3, 10], [3, 7]],
    chord: { root: 2, intervals: [0, 3, 7, 10], symbol: "Dm7" },
    context: "static minor vamp",
    remark: "Economy as style: chord tones placed like brushstrokes — the rest is space.",
  },
  {
    name: "Tritone jab (style of Monk)",
    steps: [[4, 6], [3, 6], [3, 4], [2, 5]],
    chord: { root: 7, intervals: [0, 4, 7, 10], symbol: "G7" },
    remark: "Poke the ♭5 against the dominant, then land flat-footed on the root.",
  },
  {
    name: "1·2·3·5 stack (style of Coltrane)",
    steps: [[3, 5], [3, 7], [4, 5], [4, 8]],
    chord: { root: 0, intervals: [0, 4, 7, 11], symbol: "Cmaj7" },
    remark: "The Giant-Steps-era building block — stack the cell and move it through the changes.",
  },
  {
    name: "Rootless ii–V cell (style of Bill Evans)",
    steps: [[2, 7], [3, 5], [4, 6], [4, 5]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    context: "ii–V–I in C",
    remark: "Guide tones only: the ii's 3rd becomes the V's 7th becomes the I's 3rd.",
  },
  {
    name: "Chromatic gallop (style of Django)",
    steps: [[4, 5], [4, 6], [4, 7], [4, 8], [5, 5]],
    chord: { root: 9, intervals: [0, 3, 7], symbol: "Am" },
    remark: "Every fret on the way up — the gypsy sprint into the root.",
  },
  {
    name: "Falling sigh to the 7 (style of Chet Baker)",
    steps: [[5, 5], [5, 3], [5, 1], [5, 0]],
    chord: { root: 5, intervals: [0, 4, 7, 11], symbol: "Fmaj7" },
    remark: "Stepwise descent 3-2-1-7: lyrical, patient, lands on the color tone.",
  },
  {
    name: "Prelude arpeggio (Bach, BWV 846)",
    steps: [[3, 5], [4, 5], [4, 8], [5, 8], [5, 12]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    remark: "The C major Prelude's broken chord — public domain, verbatim.",
  },
  {
    name: "Cello Suite prelude (Bach, BWV 1007)",
    steps: [[0, 3], [1, 5], [3, 4], [2, 7], [3, 4], [1, 5], [3, 4], [1, 5]],
    chord: { root: 7, intervals: [0, 4, 7], symbol: "G" },
    remark: "Verbatim, public domain: the broken-chord bloom that opens the first suite.",
  },
  {
    name: "Für Elise opening (Beethoven, WoO 59)",
    steps: [[4, 5], [4, 4], [4, 5], [4, 4], [4, 5], [3, 4], [3, 7], [3, 5], [2, 7]],
    chord: { root: 9, intervals: [0, 3, 7], symbol: "Am" },
    remark: "Verbatim, public domain: the E–D♯ trembling that resolves into A minor.",
  },
  {
    name: "Fifth motif (Beethoven, Op. 67)",
    steps: [[4, 8], [4, 8], [4, 8], [4, 4]],
    chord: { root: 0, intervals: [0, 3, 7], symbol: "Cm" },
    remark: "Verbatim, public domain: three Gs and the fall to E♭ — fate knocking.",
  },
  {
    name: "Dies irae (plainchant)",
    steps: [[2, 3], [2, 2], [2, 3], [1, 5], [2, 2], [1, 3], [1, 5]],
    chord: { root: 2, intervals: [0, 3, 7], symbol: "Dm" },
    remark: "Public domain, eight centuries old: the chant every film score quotes.",
  },
  {
    name: "Sixth-dim slide (style of Barry Harris)",
    steps: [[2, 7], [2, 6], [2, 5], [1, 7]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    remark: "6 falls through ♭6 to 5 and lands on the 3rd — the movement school in four notes.",
  },
];
