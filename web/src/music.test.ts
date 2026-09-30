import { describe, expect, it } from "vitest";
import type { ChordQuality } from "./api";
import { NOTE_NAMES, chordSymbol, formatKey, noteName } from "./music";

const DOMINANT_7: ChordQuality = {
  name: "Dominant 7",
  symbol: "7",
  intervals: [0, 4, 7, 10],
};

const MINOR_7: ChordQuality = {
  name: "Minor 7",
  symbol: "m7",
  intervals: [0, 3, 7, 10],
};

const MAJOR_7: ChordQuality = {
  name: "Major 7",
  symbol: "maj7",
  intervals: [0, 4, 7, 11],
};

describe("noteName", () => {
  it("maps the 12 pitch classes to sharp-spelled names", () => {
    expect(NOTE_NAMES).toHaveLength(12);
    expect(noteName(0)).toBe("C");
    expect(noteName(1)).toBe("C♯");
    expect(noteName(4)).toBe("E");
    expect(noteName(9)).toBe("A");
    expect(noteName(11)).toBe("B");
  });

  it("wraps out-of-range integers mod 12", () => {
    expect(noteName(12)).toBe("C");
    expect(noteName(13)).toBe("C♯");
    expect(noteName(-1)).toBe("B");
    expect(noteName(-12)).toBe("C");
  });

  it("rejects non-integer pitch classes", () => {
    expect(() => noteName(1.5)).toThrow(RangeError);
    expect(() => noteName(NaN)).toThrow(RangeError);
  });
});

describe("chordSymbol", () => {
  it("joins note name and quality symbol", () => {
    expect(chordSymbol({ root: 9, quality: DOMINANT_7 })).toBe("A7");
    expect(chordSymbol({ root: 2, quality: MINOR_7 })).toBe("Dm7");
    expect(chordSymbol({ root: 0, quality: MAJOR_7 })).toBe("Cmaj7");
    expect(chordSymbol({ root: 6, quality: DOMINANT_7 })).toBe("F♯7");
  });
});

describe("formatKey", () => {
  it("formats key as note name plus scale type name", () => {
    expect(
      formatKey({ root: 9, type: { name: "Blues", intervals: [0, 3, 5, 6, 7, 10] } }),
    ).toBe("A Blues");
    expect(
      formatKey({
        root: 0,
        type: { name: "Major (Ionian)", intervals: [0, 2, 4, 5, 7, 9, 11] },
      }),
    ).toBe("C Major (Ionian)");
  });
});
