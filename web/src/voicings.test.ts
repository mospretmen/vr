import { describe, expect, it } from "vitest";
import {
  SEVENTH_QUALITIES,
  TRIAD_QUALITIES,
} from "./theory";
import {
  STRING_SETS_3,
  STRING_SETS_4,
  drop2,
  lowestVoicing,
  triadInversions,
} from "./voicings";

// Expectations ported verbatim from the Swift core's TriadVoicingTests and
// SeventhVoicingTests — the two solvers must agree fret-for-fret.

const MAJOR = TRIAD_QUALITIES[0].intervals; // [0, 4, 7]
const MAJ7 = SEVENTH_QUALITIES[0].intervals; // [0, 4, 7, 11]

describe("catalogs", () => {
  it("defines the four seventh qualities with their canonical shapes", () => {
    expect(SEVENTH_QUALITIES.map((q) => [q.symbol, [...q.intervals]])).toEqual([
      ["maj7", [0, 4, 7, 11]],
      ["7", [0, 4, 7, 10]],
      ["m7", [0, 3, 7, 10]],
      ["m7♭5", [0, 3, 6, 10]],
    ]);
  });

  it("string sets match the Swift core, low string first", () => {
    expect(STRING_SETS_3.map((s) => [...s])).toEqual([
      [0, 1, 2],
      [1, 2, 3],
      [2, 3, 4],
      [3, 4, 5],
    ]);
    expect(STRING_SETS_4.map((s) => [...s])).toEqual([
      [0, 1, 2, 3],
      [1, 2, 3, 4],
      [2, 3, 4, 5],
    ]);
  });
});

describe("lowestVoicing", () => {
  it("prefers the nut-most shape, excluding open strings from span math", () => {
    // C major 2nd inversion (G C E) on the top three strings: open G,
    // 1st-fret C, open E — the span is just the single fretted note.
    expect(lowestVoicing([7, 0, 4], [3, 4, 5])).toEqual([0, 1, 0]);
  });

  it("returns null when a pitch class never sounds on its string", () => {
    expect(lowestVoicing([0], [0], 0)).toBeNull(); // C on open-only low E
  });

  it("rejects mismatched input lengths", () => {
    expect(() => lowestVoicing([0, 4], [0])).toThrow(RangeError);
  });
});

describe("triadInversions", () => {
  it("C major on the top strings yields the classic shapes up the neck", () => {
    const voicings = triadInversions(0, MAJOR, [3, 4, 5]);
    expect(voicings).toHaveLength(3);

    // Up the neck: (0,1,0) is the 2nd inversion (G in the bass),
    // (5,5,3) root position, (9,8,8) 1st inversion (E in the bass).
    expect(voicings.map((v) => v.steps.map((s) => s.fret))).toEqual([
      [0, 1, 0],
      [5, 5, 3],
      [9, 8, 8],
    ]);
    expect(voicings.map((v) => v.inversion)).toEqual([2, 0, 1]);
    expect(voicings.map((v) => v.label)).toEqual([
      "2nd inversion",
      "Root position",
      "1st inversion",
    ]);

    // The bass note of each voicing matches the inversion's chord tone.
    for (const voicing of voicings) {
      expect(voicing.steps[0].tone).toBe(voicing.bassTone);
      expect(voicing.steps[0].midi % 12).toBe(
        (0 + MAJOR[voicing.bassTone]) % 12,
      );
    }
  });

  it("diminished and augmented voice all inversions, strictly ascending", () => {
    for (const quality of TRIAD_QUALITIES.slice(2)) {
      const voicings = triadInversions(11, quality.intervals, [2, 3, 4]);
      expect(voicings, quality.name).toHaveLength(3);
      for (const voicing of voicings) {
        const midi = voicing.steps.map((s) => s.midi);
        expect(midi[0]).toBeLessThan(midi[1]);
        expect(midi[1]).toBeLessThan(midi[2]);
      }
    }
  });

  it("orders voicings up the neck on every string set", () => {
    const minor = TRIAD_QUALITIES[1].intervals;
    for (const strings of STRING_SETS_3) {
      const lows = triadInversions(7, minor, strings).map((v) => v.lowestFret);
      expect(lows, `strings ${strings}`).toEqual([...lows].sort((a, b) => a - b));
    }
  });

  it("degenerate qualities return [] (power-chord-ish input)", () => {
    expect(triadInversions(4, [0, 7, 12], [0, 1, 2])).toEqual([]);
  });
});

describe("drop2", () => {
  const topFour = [2, 3, 4, 5]; // D G B E

  it("Cmaj7 on the top strings produces the classic grips", () => {
    const voicings = drop2(0, MAJ7, topFour);
    expect(voicings).toHaveLength(4);

    // Ordered up the neck; these are the textbook drop-2 shapes.
    expect(voicings.map((v) => v.steps.map((s) => s.fret))).toEqual([
      [2, 4, 1, 3], // E in bass  — 1st inversion
      [5, 5, 5, 7], // G in bass  — 2nd inversion
      [9, 9, 8, 8], // B in bass  — 3rd inversion
      [10, 12, 12, 12], // C in bass — root position
    ]);
    expect(voicings.map((v) => v.inversion)).toEqual([1, 2, 3, 0]);
    expect(voicings.map((v) => v.label)).toEqual([
      "1st inversion",
      "2nd inversion",
      "3rd inversion",
      "Root position",
    ]);
  });

  it("bass note matches the inversion label on every string set", () => {
    const dom7 = SEVENTH_QUALITIES[1].intervals;
    for (const strings of STRING_SETS_4) {
      for (const voicing of drop2(7, dom7, strings)) {
        expect(voicing.steps[0].tone, `strings ${strings}`).toBe(
          voicing.bassTone,
        );
        expect(voicing.steps[0].midi % 12).toBe(
          (7 + dom7[voicing.bassTone]) % 12,
        );
      }
    }
  });

  it("voices always ascend and spell the whole chord", () => {
    const m7 = SEVENTH_QUALITIES[2].intervals; // Fm7
    const voicings = drop2(5, m7, [1, 2, 3, 4]);
    expect(voicings.length).toBeGreaterThan(0);
    for (const voicing of voicings) {
      const midi = voicing.steps.map((s) => s.midi);
      for (let i = 1; i < midi.length; i++) {
        expect(midi[i]).toBeGreaterThan(midi[i - 1]);
      }
      const sounded = new Set(voicing.steps.map((s) => s.midi % 12));
      expect(sounded).toEqual(new Set(m7.map((i) => (5 + i) % 12)));
    }
  });

  it("triad input has no drop-2 (needs four distinct tones)", () => {
    expect(drop2(0, MAJOR, topFour)).toEqual([]);
  });

  it("half-diminished voices all four inversions", () => {
    const m7b5 = SEVENTH_QUALITIES[3].intervals;
    expect(drop2(11, m7b5, topFour)).toHaveLength(4);
  });
});
