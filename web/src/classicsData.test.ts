// Truth pins for the web Classics slice — landings are chord tones,
// verbatim themes are note-for-note.
import { describe as suite, expect, it } from "vitest";
import { WEB_CLASSICS, stepPitchClass } from "./classicsData";

suite("web classics", () => {
  it("every fragment lands on a chord tone and stays on the neck", () => {
    for (const phrase of WEB_CLASSICS) {
      expect(phrase.steps.length).toBeGreaterThan(2);
      const chordPCs = new Set(
        phrase.chord.intervals.map((i) => (phrase.chord.root + i) % 12),
      );
      const last = phrase.steps[phrase.steps.length - 1];
      expect(chordPCs.has(stepPitchClass(last)),
             `${phrase.name} lands outside ${phrase.chord.symbol}`).toBe(true);
      for (const [string, fret] of phrase.steps) {
        expect(string).toBeGreaterThanOrEqual(0);
        expect(string).toBeLessThan(6);
        expect(fret).toBeGreaterThanOrEqual(0);
        expect(fret).toBeLessThanOrEqual(15);
      }
    }
  });

  it("the verbatim pins hold", () => {
    const elise = WEB_CLASSICS.find((p) => p.name.includes("Für Elise"))!;
    expect(elise.steps.map(stepPitchClass)).toEqual([4, 3, 4, 3, 4, 11, 2, 0, 9]);
    const prelude = WEB_CLASSICS.find((p) => p.name.includes("BWV 846"))!;
    expect(prelude.steps.map(stepPitchClass)).toEqual([0, 4, 7, 0, 4]);
  });
});
