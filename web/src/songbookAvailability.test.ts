import { describe, expect, it } from "vitest";
import { searchSongs, SONG_INDEX, SONGBOOKS } from "./songbooks";

// Every search result must open: tunes from books with no servable PDF
// (not on device, not in the cloud store, no site URL) stay out of the index.
describe("songbook availability", () => {
  it("drops tunes from missing books out of the index", () => {
    const missing = new Set(SONGBOOKS.filter((b) => b.missing).map((b) => b.key));
    expect(SONG_INDEX.some((e) => missing.has(e.book))).toBe(false);
  });

  it("still carries the full available index", () => {
    expect(SONG_INDEX.length).toBeGreaterThan(3000);
  });

  it("search never returns an unavailable book", () => {
    for (const q of ["stella", "all the things", "blue"]) {
      for (const e of searchSongs(q, 120)) {
        expect(e.book.startsWith("newreal")).toBe(false);
      }
    }
  });
});
