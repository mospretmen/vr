// Standard-fingering boxes: 3 notes per string (2 for pentatonics),
// box 1 using open strings when the scale allows it.
import { describe, expect, it } from "vitest";
import { scaleBoxes } from "./components/FretboardExplorer";

describe("scale boxes", () => {
  it("C major box 1 is the open-position 3NPS pattern", () => {
    const boxes = scaleBoxes(0, [0, 2, 4, 5, 7, 9, 11]);
    expect(boxes.length).toBe(7);
    const one = boxes[0];
    expect(one.startFret).toBe(0);
    // Low E string: E F G open-position
    expect(one.positions.has(0)).toBe(true);   // string 0 fret 0
    expect(one.positions.has(1)).toBe(true);   // F
    expect(one.positions.has(3)).toBe(true);   // G
    // 3 notes on every string
    expect(one.positions.size).toBe(18);
  });

  it("A minor pentatonic yields five 2NPS boxes, box at fret 5 first notes A C", () => {
    const boxes = scaleBoxes(9, [0, 3, 5, 7, 10]);
    expect(boxes.length).toBe(5);
    const five = boxes.find((b) => b.startFret === 5)!;
    expect(five.positions.has(5)).toBe(true);  // A on low E
    expect(five.positions.has(8)).toBe(true);  // C on low E
    expect(five.positions.size).toBe(12);
  });
});
