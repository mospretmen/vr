// Parity pins for the demo's scales + grips against the Swift core.
import { describe as suite, expect, it } from "vitest";
import { gripsFor, scaleSuggestions, spellScale, toneRole } from "./demoVoicings";
import { node } from "./compass";

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
