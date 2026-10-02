import { describe, expect, it } from "vitest";
import {
  SCALE_TYPES,
  STANDARD_TUNING_MIDI,
  STRING_COUNT,
  TRIAD_QUALITIES,
  fretPositions,
  noteAt,
  scaleDegree,
} from "./theory";

describe("catalogs", () => {
  it("every scale shape starts at 0, is strictly increasing, and stays within an octave", () => {
    for (const scale of SCALE_TYPES) {
      expect(scale.intervals[0], scale.name).toBe(0);
      for (let i = 1; i < scale.intervals.length; i++) {
        expect(scale.intervals[i], scale.name).toBeGreaterThan(
          scale.intervals[i - 1],
        );
      }
      expect(scale.intervals.at(-1)!, scale.name).toBeLessThanOrEqual(11);
    }
  });

  it("matches the Swift core's mode shapes", () => {
    const byName = Object.fromEntries(
      SCALE_TYPES.map((s) => [s.name, s.intervals]),
    );
    expect(byName["Major (Ionian)"]).toEqual([0, 2, 4, 5, 7, 9, 11]);
    expect(byName["Minor (Aeolian)"]).toEqual([0, 2, 3, 5, 7, 8, 10]);
    expect(byName["Blues"]).toEqual([0, 3, 5, 6, 7, 10]);
    expect(byName["Harmonic Minor"]).toEqual([0, 2, 3, 5, 7, 8, 11]);
    expect(byName["Melodic Minor"]).toEqual([0, 2, 3, 5, 7, 9, 11]);
  });

  it("defines the four triad qualities with their canonical shapes", () => {
    expect(TRIAD_QUALITIES.map((t) => [...t.intervals])).toEqual([
      [0, 4, 7],
      [0, 3, 7],
      [0, 3, 6],
      [0, 4, 8],
    ]);
  });

  it("standard tuning is E2 A2 D3 G3 B3 E4, low string first", () => {
    expect(STANDARD_TUNING_MIDI).toEqual([40, 45, 50, 55, 59, 64]);
    expect(STRING_COUNT).toBe(6);
  });
});

describe("noteAt", () => {
  it("open strings sound E A D G B E", () => {
    // Pitch classes: E=4, A=9, D=2, G=7, B=11.
    expect([0, 1, 2, 3, 4, 5].map((s) => noteAt(s, 0))).toEqual([
      4, 9, 2, 7, 11, 4,
    ]);
  });

  it("fret 5 on each lower string matches the next open string (except G→B at fret 4)", () => {
    expect(noteAt(0, 5)).toBe(noteAt(1, 0)); // E+5 = A
    expect(noteAt(1, 5)).toBe(noteAt(2, 0)); // A+5 = D
    expect(noteAt(2, 5)).toBe(noteAt(3, 0)); // D+5 = G
    expect(noteAt(3, 4)).toBe(noteAt(4, 0)); // G+4 = B
    expect(noteAt(4, 5)).toBe(noteAt(5, 0)); // B+5 = E
  });

  it("the 12th fret is the octave of the open string", () => {
    for (let s = 0; s < STRING_COUNT; s++) {
      expect(noteAt(s, 12)).toBe(noteAt(s, 0));
    }
  });

  it("rejects out-of-range strings and negative frets", () => {
    expect(() => noteAt(-1, 0)).toThrow(RangeError);
    expect(() => noteAt(6, 0)).toThrow(RangeError);
    expect(() => noteAt(0, -1)).toThrow(RangeError);
    expect(() => noteAt(0, 1.5)).toThrow(RangeError);
  });
});

describe("scaleDegree", () => {
  const major = SCALE_TYPES[0].intervals;

  it("maps C major pitch classes to 1-based degrees", () => {
    expect(scaleDegree(0, major, 0)).toBe(1); // C
    expect(scaleDegree(0, major, 2)).toBe(2); // D
    expect(scaleDegree(0, major, 11)).toBe(7); // B
    expect(scaleDegree(0, major, 1)).toBeNull(); // C♯ not in C major
    expect(scaleDegree(0, major, 10)).toBeNull(); // B♭ not in C major
  });

  it("transposes with the root and wraps mod 12", () => {
    // A major: A B C♯ D E F♯ G♯ → pc 9, 11, 1, 2, 4, 6, 8.
    expect(scaleDegree(9, major, 9)).toBe(1);
    expect(scaleDegree(9, major, 1)).toBe(3);
    expect(scaleDegree(9, major, 8)).toBe(7);
    expect(scaleDegree(9, major, 0)).toBeNull();
    // Negative pitch classes still resolve (defensive mod).
    expect(scaleDegree(9, major, -3)).toBe(1); // -3 ≡ 9 (mod 12)
  });

  it("works for triad shapes: E major triad is E G♯ B", () => {
    const majorTriad = TRIAD_QUALITIES[0].intervals;
    expect(scaleDegree(4, majorTriad, 4)).toBe(1);
    expect(scaleDegree(4, majorTriad, 8)).toBe(2);
    expect(scaleDegree(4, majorTriad, 11)).toBe(3);
    expect(scaleDegree(4, majorTriad, 7)).toBeNull(); // G natural: not in E major
  });

  it("A blues scale contains the ♭5", () => {
    const blues = SCALE_TYPES.find((s) => s.name === "Blues")!.intervals;
    expect(scaleDegree(9, blues, 3)).toBe(4); // E♭ over A: the blue note
    expect(scaleDegree(9, blues, 4)).toBe(5); // E natural
  });
});

describe("fretPositions", () => {
  it("starts at the nut (0) and ends at the last fret (1)", () => {
    const pos = fretPositions(15);
    expect(pos).toHaveLength(16);
    expect(pos[0]).toBe(0);
    expect(pos[15]).toBeCloseTo(1, 10);
  });

  it("is strictly increasing with shrinking gaps (equal temperament)", () => {
    const pos = fretPositions(15);
    for (let i = 1; i < pos.length; i++) {
      expect(pos[i]).toBeGreaterThan(pos[i - 1]);
      if (i >= 2) {
        expect(pos[i] - pos[i - 1]).toBeLessThan(pos[i - 1] - pos[i - 2]);
      }
    }
  });

  it("puts fret 12 at half the scale length before renormalization", () => {
    const pos = fretPositions(15);
    const span = 1 - 2 ** (-15 / 12);
    expect(pos[12] * span).toBeCloseTo(0.5, 10);
  });

  it("rejects non-positive fret counts", () => {
    expect(() => fretPositions(0)).toThrow(RangeError);
    expect(() => fretPositions(-3)).toThrow(RangeError);
  });
});
