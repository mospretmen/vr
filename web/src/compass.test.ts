// Parity pins against the Swift HarmonyWheel — the same musical facts the
// visionOS core enforces, so the two graphs cannot drift apart.
import { describe as suite, expect, it } from "vitest";
import {
  ALL_MOVES,
  chordPitchClasses,
  gradedPairs,
  isTwoWay,
  movesFrom,
  node,
} from "./compass";

suite("compass graph parity", () => {
  it("spells the flat side conventionally", () => {
    expect(node("majorKey", 10).label).toBe("B♭");
    expect(node("majorKey", 9).label).toBe("E♭");
    expect(node("relativeMinor", 0).label).toBe("Am");
    expect(node("majorKey", 6).label).toBe("F♯");
  });

  it("G7 resolves home to C and Cm, two-way with the departure", () => {
    const g7 = node("dominant", 9);
    expect(g7.label).toBe("G7");
    const resolves = movesFrom(g7).filter((m) => m.kind === "resolve");
    expect(resolves.map((m) => m.to.label)).toEqual(["Cm", "C"]);
    expect(resolves.every(isTwoWay)).toBe(true);
  });

  it("tritone subs run straight across and come home a half-step down", () => {
    const e7 = node("dominant", 0);
    const subs = movesFrom(e7).filter((m) => m.kind === "tritoneSub");
    expect(subs.map((m) => m.to.label)).toEqual(["A♯7", "E♭", "D♯m"]);
    expect(isTwoWay(subs[0])).toBe(true);
  });

  it("the ii–V–I chain is fully linked from the key", () => {
    const c = node("majorKey", 0);
    const dm = movesFrom(c).find((m) => m.kind === "twoFive")!.to;
    expect(dm.label).toBe("Dm");
    const g7 = movesFrom(dm).find(
      (m) => m.kind === "twoFive" && m.to.ring === "dominant",
    )!.to;
    expect(g7.label).toBe("G7");
    const home = movesFrom(g7).find(
      (m) => m.kind === "resolve" && m.to.ring === "majorKey",
    )!.to;
    expect(home.id).toBe(c.id);
  });

  it("secondary dominants soften into the ii on the same root", () => {
    const d7 = node("dominant", 10);
    expect(d7.label).toBe("D7");
    const soft = movesFrom(d7).filter((m) => m.kind === "soften");
    expect(soft.map((m) => m.to.label)).toEqual(["Dm"]);
  });

  it("keys reach their IV7 and their own vii°7, which returns", () => {
    const c = node("majorKey", 0);
    const labels = movesFrom(c).map((m) => m.to.label);
    expect(labels).toContain("F7");
    const a = node("majorKey", 3);
    const dim = movesFrom(a).find((m) => m.kind === "deepen")!;
    expect(dim.to.label).toBe("G♯°7");
    expect(isTwoWay(dim)).toBe(true);
  });

  it("dominants chain around the circle", () => {
    const e7 = node("dominant", 0);
    const down = movesFrom(e7).find(
      (m) => m.kind === "fifthFlatward" && m.to.ring === "dominant",
    )!;
    expect(down.to.label).toBe("A7");
    expect(isTwoWay(down)).toBe(true);
  });

  it("every edge references real nodes and dims form full cliques", () => {
    expect(ALL_MOVES.length).toBeGreaterThan(300);
    const dim = node("diminished", 0);
    const family = movesFrom(dim).filter((m) => m.kind === "dimFamily");
    expect(family.map((m) => m.to.index).sort((a, b) => a - b)).toEqual([3, 6, 9]);
  });

  it("graded web: the resolution owns the arrowhead on the C–G7 pair", () => {
    const pairs = gradedPairs(node("majorKey", 0));
    const cg7 = pairs.find(
      (p) => [p.move.from.label, p.move.to.label].sort().join() === "C,G7",
    )!;
    expect(cg7.depth).toBe(1);
    expect(cg7.move.kind).toBe("resolve");
    expect(cg7.move.to.label).toBe("C");
    expect(cg7.twoWay).toBe(true);
    expect(pairs.some((p) => p.depth === 3)).toBe(true);
  });

  it("chord pads sound the right tones", () => {
    expect(chordPitchClasses(node("dominant", 9))).toEqual([7, 11, 2, 5]); // G7
    expect(chordPitchClasses(node("relativeMinor", 0))).toEqual([9, 0, 4]); // Am
  });
});
