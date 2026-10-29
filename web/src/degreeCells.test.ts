import { describe as suite, expect, it } from "vitest";
import { degreeCells } from "./degreeCells";

const MAJOR = { name: "Major (Ionian)", intervals: [0, 2, 4, 5, 7, 9, 11] };
const MELODIC = { name: "Melodic Minor", intervals: [0, 2, 3, 5, 7, 9, 11] };
const HARMONIC = { name: "Harmonic Minor", intervals: [0, 2, 3, 5, 7, 8, 11] };

suite("non-heptatonic degree cards", () => {
  it("minor pentatonic shows 1 ♭3 4 5 ♭7", () => {
    const cells = degreeCells(9, { name: "Minor Pentatonic", intervals: [0, 3, 5, 7, 10] });
    expect(cells.map((c) => c.roman)).toEqual(["1", "♭3", "4", "5", "♭7"]);
    expect(cells.map((c) => c.chordSymbol)).toEqual(["A", "C", "D", "E", "G"]);
  });
  it("blues labels the 6-semitone tone ♭5", () => {
    const cells = degreeCells(0, { name: "Blues", intervals: [0, 3, 5, 6, 7, 10] });
    expect(cells[3].roman).toBe("♭5");
  });
});

suite("degree cells parity", () => {
  it("C major harmonizes to the textbook row", () => {
    const cells = degreeCells(0, MAJOR);
    expect(cells.map((c) => c.chordSymbol)).toEqual([
      "Cmaj7", "Dm7", "Em7", "Fmaj7", "G7", "Am7", "Bm7♭5",
    ]);
    expect(cells.map((c) => c.roman)).toEqual([
      "I", "ii", "iii", "IV", "V", "vi", "viiø",
    ]);
    expect(cells[0].tensions).toEqual(["9", "(11)", "13"]);
    expect(cells[1].mode).toBe("Dorian");
  });

  it("C melodic minor: Lydian dominant on 4, Altered on 7", () => {
    const cells = degreeCells(0, MELODIC);
    expect(cells[0].chordSymbol).toBe("Cm(maj7)");
    expect(cells[3].mode).toBe("Lydian dominant");
    expect(cells[6].mode).toBe("Altered");
    expect(cells[2].roman).toBe("♭III+");
  });

  it("C harmonic minor's V7 carries ♭9 and ♭13 as colors", () => {
    const cells = degreeCells(0, HARMONIC);
    const onV = cells[4];
    expect(onV.chordSymbol).toBe("G7");
    expect(onV.tensions).toContain("♭9");
    expect(onV.tensions).toContain("♭13");
    expect(onV.tensions).toContain("(11)");
  });
});
