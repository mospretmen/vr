// Parity pins for the demo's scales + grips against the Swift core.
import { describe as suite, expect, it } from "vitest";
import { drop2Grip, DYAD_KINDS, dyadGrips, dropGrip, gripFamilies, gripsFor, scaleSuggestions, spellScale, toneRole } from "./demoVoicings";
import { node } from "./compass";

suite("grip dictionary (ChordGripTemplates parity)", () => {
  it("drop-2 inversions land the textbook voicings", () => {
    const g = drop2Grip(0, [0, 4, 7, 11], [1, 2, 3, 4], 0)!; // Cmaj7, strings 5-2
    expect(g.frets).toEqual([null, 3, 5, 4, 5, null]); // C G B E — x3545x
    for (let inv = 0; inv < 4; inv++) {
      const v = drop2Grip(7, [0, 4, 7, 10], [2, 3, 4, 5], inv); // G7 top set
      expect(v, `G7 drop-2 inv ${inv}`).not.toBeNull();
      const fretted = v!.frets.filter((f): f is number => f !== null);
      expect(Math.max(...fretted) - Math.min(...fretted)).toBeLessThanOrEqual(5);
    }
  });

  it("drop-3 lands the Joe Pass shapes", () => {
    // G7 drop-3 root position on 6·432: G(3) x F(3) B(4) D(3) x — 3x343x
    const g = dropGrip(7, [0, 4, 7, 10], [0, 2, 3, 4], 0, 3)!;
    expect(g.frets).toEqual([3, null, 3, 4, 3, null]);
    for (let inv = 0; inv < 4; inv++) {
      const v = dropGrip(0, [0, 4, 7, 11], [1, 3, 4, 5], inv, 3); // Cmaj7 5·321
      expect(v, `Cmaj7 drop-3 inv ${inv}`).not.toBeNull();
    }
  });

  it("dyads put the guide tones where players grab them", () => {
    // C7 guide tones 3+7 on strings 4·3: E(2) B♭(3) — x x 2 3 x x
    const dyads = dyadGrips(0, [0, 4, 7, 10], DYAD_KINDS[0], [2, 3]);
    expect(dyads[0].frets).toEqual([null, null, 2, 3, null, null]);
  });

  it("knows the extended qualities per family, charts-exact", () => {
    const cMajor = gripFamilies(node("majorKey", 0));
    expect(cMajor.map((f) => f.suffix)).toEqual(["", "add9", "6", "6/9", "maj7", "maj9"]);
    const sixNine = cMajor.find((f) => f.suffix === "6/9")!;
    expect(sixNine.grips[0].frets).toEqual([null, 3, 2, 2, 3, 3]); // C6/9 x32233
    const g7 = gripFamilies(node("dominant", 9)); // spoke 9 = G
    const hendrix = g7.find((f) => f.suffix === "7♯9")!;
    expect(hendrix.grips[0].frets).toEqual([null, 10, 9, 10, 11, null]); // G7♯9 x(10)9(10)(11)x
    const am = gripFamilies(node("relativeMinor", 9));
    expect(am.map((f) => f.suffix)).toContain("m(maj7)");
  });
});

suite("demo scales & grips", () => {
  it("dominant scale list matches the core's ordering", () => {
    const names = scaleSuggestions(node("dominant", 9)).map((s) => s.name);
    expect(names[0]).toBe("Mixolydian");
    expect(names).toContain("Altered");
    expect(names).toContain("Half-Whole Diminished");
    expect(names).toContain("Whole Tone");
  });

  it("diminished chords get the whole-half scale only", () => {
    expect(scaleSuggestions(node("diminished", 0)).map((s) => s.name))
      .toEqual(["Whole-Half Diminished"]);
  });

  it("spelling follows the flat-degree convention (G blues)", () => {
    expect(spellScale(7, [0, 3, 5, 6, 7, 10]))
      .toEqual(["G", "B♭", "C", "D♭", "D", "F"]);
  });

  it("G7 instantiates the published E7 barre at fret 3", () => {
    const grips = gripsFor(node("dominant", 9));
    expect(grips.some((g) => g.frets.join(",") === "3,5,3,4,3,3")).toBe(true);
  });

  it("every grip sounds only chord tones with the root in the bass", () => {
    for (const ring of [0, 3, 7, 10] as const) {
      const n = node("dominant", ring);
      for (const grip of gripsFor(n)) {
        const sounded = grip.frets
          .map((f, s) => (f === null ? null : { s, f }))
          .filter((x): x is { s: number; f: number } => x !== null);
        expect(sounded.length).toBeGreaterThanOrEqual(4);
        expect(toneRole(n, sounded[0].s, sounded[0].f)).toBe(0);
      }
    }
  });
});
