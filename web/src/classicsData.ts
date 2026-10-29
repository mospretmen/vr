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
    name: "Bird flight over ii\u2013V\u2013I (study line)",
    steps: [[2, 7], [3, 5], [4, 5], [4, 8], [4, 6], [4, 5], [3, 7], [3, 4], [3, 5], [2, 7], [2, 5], [3, 4], [3, 5]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    context: "ii\u2013V\u2013I in C",
    remark: "Dm9 arpeggio up, G7 spelled down to its 3rd, an enclosure into home — one breath of bebop.",
  },
  {
    name: "Blues chorus opener (study line)",
    steps: [[2, 5], [2, 7], [3, 5], [4, 5], [4, 8], [4, 5], [3, 3], [2, 7], [2, 5], [4, 5]],
    chord: { root: 0, intervals: [0, 4, 7, 10], symbol: "C7" },
    remark: "Pickup from the 5, major triad on top, the ♭7 answered — bar one of ten thousand choruses.",
  },
  {
    name: "Minor turnaround cry (study line)",
    steps: [[2, 7], [3, 5], [4, 5], [5, 5], [4, 9], [4, 5], [4, 6], [4, 5], [3, 7], [3, 5], [2, 7]],
    chord: { root: 9, intervals: [0, 3, 7], symbol: "Am" },
    remark: "Up the minor triad, the raised 7 pulling home, the ♭6 sighing down — a full turnaround phrase.",
  },
  {
    name: "Invention sequence (study line)",
    steps: [[3, 5], [3, 7], [4, 5], [3, 5], [3, 4], [3, 5], [3, 7], [3, 4], [2, 7], [3, 4], [3, 5], [2, 5]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    remark: "A three-step falling sequence, Bach's workshop habit: state it, move it down, resolve it.",
  },
  {
    name: "Minor arch statement (study line)",
    steps: [[3, 5], [4, 4], [4, 8], [5, 6], [5, 8], [5, 6], [4, 8], [4, 6], [4, 4], [3, 5]],
    chord: { root: 0, intervals: [0, 3, 7, 10], symbol: "Cm7" },
    remark: "Up the m7 arpeggio to the high root and back down through the 4 — one singable arch.",
  },
  {
    name: "Ballad descent (study line)",
    steps: [[5, 8], [5, 7], [5, 6], [5, 5], [4, 5], [4, 6], [4, 5], [3, 5], [2, 7]],
    chord: { root: 9, intervals: [0, 3, 7], symbol: "Am" },
    remark: "Chromatic fall from the ♭3, a leaning ♭6, and the long way home — gypsy ballad grammar.",
  },
  {
    name: "Blues head cell (study line)",
    steps: [[3, 5], [4, 5], [4, 8], [4, 10], [5, 6], [4, 10], [4, 8], [4, 5], [3, 7], [3, 5]],
    chord: { root: 0, intervals: [0, 4, 7, 10], symbol: "C7" },
    remark: "Triad up to the 6, the ♭7 on top, stepping back down through the 9 — a head in miniature.",
  },
  {
    name: "Rootless climb (study line)",
    steps: [[4, 5], [3, 4], [3, 7], [2, 5], [2, 9], [2, 7], [2, 5], [4, 5]],
    chord: { root: 0, intervals: [0, 4, 7, 11], symbol: "Cmaj7" },
    remark: "3–7–9–5 up to the high 7 and settle on the 3rd — the piano voicing as a line.",
  },
  {
    name: "Four-note cells rising (study line)",
    steps: [[3, 5], [3, 7], [4, 5], [4, 8], [3, 7], [4, 5], [4, 6], [4, 10], [4, 5], [4, 6], [4, 8], [5, 7], [5, 8]],
    chord: { root: 0, intervals: [0, 4, 7, 11], symbol: "Cmaj7" },
    remark: "1-2-3-5 moved up the scale, cell by cell, until it lands on the high root — the Coltrane drill as music.",
  },
  {
    name: "Bossa line home (study line)",
    steps: [[2, 7], [3, 4], [3, 5], [3, 7], [4, 5], [3, 7], [3, 5], [3, 4], [2, 7], [2, 5], [2, 7]],
    chord: { root: 9, intervals: [0, 3, 7], symbol: "Am" },
    remark: "Rise to the 5, fall by step, lean on the ♭7 and resolve — Jobim-school melodic speech.",
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
    name: "Prelude arpeggio (Bach, BWV 846)",
    steps: [[3, 5], [4, 5], [4, 8], [5, 8]],
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
    name: "Block-chord glide (style of Red Garland)",
    steps: [[4, 5], [4, 8], [5, 5], [4, 8], [4, 5]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    remark: "The right-hand melody of his block chords: 3-5-6-5-3, smiling.",
  },
  {
    name: "Flatpick run (style of Doc Watson)",
    steps: [[2, 5], [2, 7], [3, 4], [3, 5], [3, 7], [4, 8]],
    chord: { root: 7, intervals: [0, 4, 7], symbol: "G" },
    remark: "A fiddle-tune scale sprint, every note picked, straight to the root.",
  },
  {
    name: "Blues turnaround walk (common practice)",
    steps: [[3, 5], [3, 4], [3, 3], [2, 7], [2, 6], [2, 5]],
    chord: { root: 0, intervals: [0, 4, 7, 10], symbol: "C7" },
    context: "turnaround in C",
    remark: "The chromatic walkdown from root to 5th that ends ten thousand blues choruses.",
  },
  {
    name: "Hummingbird box (style of B.B. King)",
    steps: [[5, 8], [4, 8], [4, 10], [5, 8]],
    chord: { root: 0, intervals: [0, 4, 7, 10], symbol: "C7" },
    remark: "One note at a time out of the box: root, 5, 6, root — sing it, don't spray it.",
  },
  {
    name: "Cold-heart curl (style of Peter Green)",
    steps: [[2, 7], [3, 5], [3, 4], [2, 7]],
    chord: { root: 9, intervals: [0, 3, 7], symbol: "Am" },
    remark: "Less is everything: the minor third answered through the 9 — vibrato does the rest.",
  },
  {
    name: "Morning mood (Grieg, Op. 46)",
    steps: [[2, 5], [2, 2], [1, 5], [1, 3], [1, 5], [2, 2], [2, 5]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    remark: "Verbatim, public domain: Peer Gynt's sunrise, pentatonic and patient.",
  },
  {
    name: "Lullaby curve (Brahms, Op. 49)",
    steps: [[4, 5], [4, 5], [4, 8], [4, 5], [4, 5], [4, 8]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    remark: "Verbatim, public domain: the cradle-song thirds that rock the world to sleep.",
  },
  {
    name: "♯9 bite (style of Kenny Burrell)",
    steps: [[3, 5], [4, 4], [4, 5], [4, 8]],
    chord: { root: 0, intervals: [0, 4, 7, 10], symbol: "C7" },
    remark: "The blues rub: minor third against a dominant, resolved up into the major 3rd.",
  },
  {
    name: "Dorian turn (style of Grant Green)",
    steps: [[5, 1], [5, 3], [5, 5], [5, 3], [5, 1], [4, 3]],
    chord: { root: 2, intervals: [0, 3, 7, 10], symbol: "Dm7" },
    remark: "A singable turn on 3-4-5, resolved back to the root — groove over complexity.",
  },
  {
    name: "Linear machine (style of Pat Martino)",
    steps: [[4, 6], [4, 5], [3, 7], [3, 5], [3, 4], [2, 7]],
    chord: { root: 2, intervals: [0, 3, 7, 10], symbol: "Dm7" },
    remark: "Relentless stepwise descent — minor lines as perpetual motion.",
  },
  {
    name: "Cool interval skip (style of Jim Hall)",
    steps: [[2, 5], [4, 5], [3, 4], [3, 5]],
    chord: { root: 0, intervals: [0, 4, 7, 11], symbol: "Cmaj7" },
    remark: "Wide, quiet intervals — melody that listens to itself.",
  },
  {
    name: "Proto-bop rip (style of Charlie Christian)",
    steps: [[3, 5], [4, 5], [4, 8], [5, 5], [5, 6]],
    chord: { root: 0, intervals: [0, 4, 7, 10], symbol: "C7" },
    remark: "The electric blueprint: arpeggio up, 6th to ♭7 on top.",
  },
  {
    name: "Cool landing (style of Stan Getz)",
    steps: [[4, 8], [4, 5], [3, 7], [3, 5], [3, 4]],
    chord: { root: 0, intervals: [0, 4, 7, 11], symbol: "Cmaj7" },
    remark: "A breathy stepwise fall that parks on the major 7 — tension as perfume.",
  },
  {
    name: "Double-stop cry (style of Hendrix)",
    steps: [[3, 5], [4, 5], [3, 7], [3, 5], [2, 5]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    remark: "Hammer the 9 inside the shape — play it as double-stops with the thumb over.",
  },
  {
    name: "Pedal riff (style of Grant Green, II)",
    steps: [[2, 5], [3, 4], [2, 5], [3, 7], [2, 5]],
    chord: { root: 7, intervals: [0, 4, 7, 10], symbol: "G7" },
    remark: "Keep hitting the root between color tones — groove is repetition.",
  },
  {
    name: "Duck-walk opener (style of Chuck Berry)",
    steps: [[4, 8], [4, 5], [4, 8], [4, 5], [3, 5]],
    chord: { root: 0, intervals: [0, 4, 7, 10], symbol: "C7" },
    remark: "The double-stop intro flattened to a line: 5 and 3 hammering to the root.",
  },
  {
    name: "Bend contour (style of Gilmour)",
    steps: [[3, 7], [3, 9], [3, 7], [2, 10]],
    chord: { root: 9, intervals: [0, 3, 7], symbol: "Am" },
    remark: "The two-fret cry drawn as a slide: 4 up to 5, falling away to the ♭3.",
  },
  {
    name: "Steel glint (style of Knopfler)",
    steps: [[3, 5], [4, 5], [2, 5], [3, 5]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    remark: "Thumb-rolled triad, placed like speech — the National steel glint.",
  },
  {
    name: "Lágrima sigh (Tárrega)",
    steps: [[5, 8], [5, 7], [5, 8], [4, 8]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    remark: "Public domain: the teardrop's opening — a neighbor tone away from home.",
  },
  {
    name: "Badinerie kick (Bach, BWV 1067)",
    steps: [[4, 5], [3, 5], [2, 7], [3, 5], [4, 5]],
    chord: { root: 9, intervals: [0, 3, 7], symbol: "Am" },
    remark: "Public domain: the flute's playful plunge down the minor triad.",
  },
  {
    name: "Nachtmusik call (Mozart, K. 525)",
    steps: [[3, 5], [2, 5], [3, 5], [2, 5], [3, 5], [4, 5], [2, 5]],
    chord: { root: 0, intervals: [0, 4, 7], symbol: "C" },
    remark: "Public domain: the serenade's opening salute — all triad, all confidence.",
  },
];
