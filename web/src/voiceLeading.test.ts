import { describe as suite, expect, it } from "vitest";
import { voiceMoves } from "./voiceLeading";
import { node } from "./compass";

suite("voice leading parity", () => {
  it("G7 → C: leading tone up, seventh down, root held", () => {
    const moves = voiceMoves(node("dominant", 9), node("majorKey", 0));
    expect(moves).toContainEqual({ from: 11, to: 0, semitones: 1 }); // B→C
    expect(moves).toContainEqual({ from: 5, to: 4, semitones: -1 }); // F→E
    expect(moves).toContainEqual({ from: 7, to: 7, semitones: 0 }); // G stays
  });

  it("the tritone sub slides down chromatically", () => {
    const moves = voiceMoves(node("dominant", 3), node("majorKey", 0)); // C♯7→C
    expect(moves.every((m) => Math.abs(m.semitones) <= 2)).toBe(true);
    expect(moves).toContainEqual({ from: 1, to: 0, semitones: -1 });
  });
});
