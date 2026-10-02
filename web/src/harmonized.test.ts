import { describe, expect, it } from "vitest";
import { diatonicTriads, triadLadder } from "./harmonized";
import { SCALE_TYPES } from "./theory";

// Expectations ported verbatim from the Swift core's HarmonizedScaleTests —
// the two ladders must agree rung-for-rung.

const byName = (name: string) => {
  const scale = SCALE_TYPES.find((s) => s.name === name);
  if (!scale) throw new Error(`missing scale preset: ${name}`);
  return scale.intervals;
};

const MAJOR = byName("Major (Ionian)");
const NATURAL_MINOR = byName("Minor (Aeolian)");
const HARMONIC_MINOR = byName("Harmonic Minor");
const MINOR_PENTATONIC = byName("Minor Pentatonic");

describe("diatonicTriads", () => {
  it("C major harmonizes to the textbook qualities", () => {
    const triads = diatonicTriads(0, MAJOR);
    expect(triads.map((t) => t.symbol)).toEqual([
      "C",
      "Dm",
      "Em",
      "F",
      "G",
      "Am",
      "B°",
    ]);
    expect(triads.map((t) => t.rootPc)).toEqual([0, 2, 4, 5, 7, 9, 11]);
  });

  it("A harmonic minor raises the five and augments the three", () => {
    const triads = diatonicTriads(9, HARMONIC_MINOR);
    expect(triads.map((t) => t.quality.symbol)).toEqual([
      "m",
      "°",
      "+",
      "m",
      "",
      "",
      "°",
    ]);
  });

  it("scales with fewer than five notes have no harmonization", () => {
    expect(diatonicTriads(0, [0, 4, 7])).toEqual([]);
  });
});

describe("triadLadder", () => {
  it("C major on the top strings climbs the neck", () => {
    const ladder = triadLadder(0, MAJOR, [3, 4, 5]);

    expect(ladder).toHaveLength(7);
    expect(ladder.map((r) => r.romanNumeral)).toEqual([
      "I",
      "ii",
      "iii",
      "IV",
      "V",
      "vi",
      "vii°",
    ]);
    expect(ladder.map((r) => r.triad.rootPc)).toEqual([0, 2, 4, 5, 7, 9, 11]);

    // The ladder never retreats down the neck.
    const frets = ladder.map((r) => r.voicing.lowestFret);
    expect(frets).toEqual([...frets].sort((a, b) => a - b));
    expect(frets).toEqual([0, 1, 3, 5, 7, 8, 10]); // verified by hand

    // Every rung actually spells its own triad.
    for (const rung of ladder) {
      const sounded = new Set(rung.voicing.steps.map((s) => s.midi % 12));
      const expected = new Set(
        rung.triad.quality.intervals.map((i) => (rung.triad.rootPc + i) % 12),
      );
      expect(sounded, rung.romanNumeral).toEqual(expected);
    }
  });

  it("minor-key numerals are cased", () => {
    const ladder = triadLadder(9, NATURAL_MINOR, [2, 3, 4]);
    expect(ladder.map((r) => r.romanNumeral)).toEqual([
      "i",
      "ii°",
      "III",
      "iv",
      "v",
      "VI",
      "VII",
    ]);
  });

  it("harmonic minor raises the five", () => {
    const ladder = triadLadder(9, HARMONIC_MINOR, [3, 4, 5]);
    // Harmonic minor: i ii° III+ iv V VI vii°
    expect(ladder.map((r) => r.romanNumeral)).toEqual([
      "i",
      "ii°",
      "III+",
      "iv",
      "V",
      "VI",
      "vii°",
    ]);
  });

  it("pentatonic scales have no ladder", () => {
    expect(triadLadder(9, MINOR_PENTATONIC, [3, 4, 5])).toEqual([]);
  });
});
