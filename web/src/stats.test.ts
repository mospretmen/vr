import { describe, expect, it } from "vitest";
import { computeStreak, humanizeDuration, modeLabel } from "./stats";

describe("humanizeDuration", () => {
  it("renders zero as 0m", () => {
    expect(humanizeDuration(0)).toBe("0m");
  });

  it("renders sub-minute durations as <1m", () => {
    expect(humanizeDuration(1)).toBe("<1m");
    expect(humanizeDuration(59)).toBe("<1m");
  });

  it("renders sub-hour durations in minutes", () => {
    expect(humanizeDuration(60)).toBe("1m");
    expect(humanizeDuration(24 * 60)).toBe("24m");
    expect(humanizeDuration(59 * 60 + 59)).toBe("59m");
  });

  it("renders hour-plus durations as h and m", () => {
    expect(humanizeDuration(3600)).toBe("1h 0m");
    expect(humanizeDuration(3 * 3600 + 24 * 60)).toBe("3h 24m");
    expect(humanizeDuration(26 * 3600 + 5 * 60 + 30)).toBe("26h 5m");
  });

  it("treats negative or non-finite input as 0m", () => {
    expect(humanizeDuration(-10)).toBe("0m");
    expect(humanizeDuration(NaN)).toBe("0m");
  });
});

describe("computeStreak", () => {
  const today = "2026-09-30";

  it("returns 0 for no practice days", () => {
    expect(computeStreak([], today)).toBe(0);
  });

  it("counts a run ending today", () => {
    expect(
      computeStreak(["2026-09-28", "2026-09-29", "2026-09-30"], today),
    ).toBe(3);
  });

  it("keeps a streak alive when it ends yesterday", () => {
    expect(computeStreak(["2026-09-28", "2026-09-29"], today)).toBe(2);
  });

  it("returns 0 when the last practice is older than yesterday", () => {
    expect(computeStreak(["2026-09-26", "2026-09-27"], today)).toBe(0);
  });

  it("stops counting at a gap inside the run", () => {
    expect(
      computeStreak(
        ["2026-09-25", "2026-09-26", "2026-09-28", "2026-09-29", "2026-09-30"],
        today,
      ),
    ).toBe(3);
  });

  it("handles a single practice day today", () => {
    expect(computeStreak(["2026-09-30"], today)).toBe(1);
  });

  it("crosses month boundaries", () => {
    expect(
      computeStreak(["2026-08-31", "2026-09-01"], "2026-09-01"),
    ).toBe(2);
  });
});

describe("modeLabel", () => {
  it("maps every known mode to its display label", () => {
    expect(modeLabel("scale")).toBe("Scale");
    expect(modeLabel("chord")).toBe("Chord");
    expect(modeLabel("chordInScale")).toBe("Chord + Scale");
    expect(modeLabel("exercise")).toBe("Exercise");
    expect(modeLabel("backingTrack")).toBe("Backing Track");
    expect(modeLabel("listen")).toBe("Listen");
  });

  it("passes unknown modes through unchanged", () => {
    expect(modeLabel("mystery")).toBe("mystery");
  });
});
