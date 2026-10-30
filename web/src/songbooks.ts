// The songbook shelf: metadata for the books in the user's own library
// folder, plus the master song index parsed from the fake-book index PDF
// (web/src/songIndex.json, 2124 entries). The PDFs themselves never leave
// the user's machine — the app opens them from a locally connected folder.
import rawIndex from "./songIndex.json";

export interface Songbook {
  key: string;
  name: string;
  /** Exact filename expected inside the connected folder. */
  file: string;
  pages: number;
  /** Books with no per-song index yet open at page 1. */
  indexed: boolean;
  /** Public-domain scores served by the site itself — no import needed. */
  url?: string;
}

export const SONGBOOKS: Songbook[] = [
  { key: "realbk1", name: "The Real Book I", file: "REALBK1.PDF", pages: 512, indexed: true },
  { key: "realbk3", name: "The Real Book III", file: "REALBK3.PDF", pages: 366, indexed: true },
  { key: "jazzfake", name: "The Jazz Fakebook", file: "JAZZFAKE-1.PDF", pages: 448, indexed: true },
  { key: "colorado", name: "The Colorado Cookbook", file: "COLOBK.PDF", pages: 292, indexed: true },
  { key: "evansbk", name: "The Bill Evans Fakebook", file: "EVANSBK.PDF", pages: 106, indexed: true },
  { key: "thebook", name: "The Book (commercial)", file: "THEBOOK.PDF", pages: 514, indexed: true },
  { key: "realbk2", name: "The Real Book II", file: "REALBK2.PDF", pages: 476, indexed: true },
  { key: "jazzltd", name: "Jazz LTD", file: "JAZZLTD.PDF", pages: 480, indexed: true },
  { key: "library", name: "Library of Musicians' Jazz", file: "LIBRARY.PDF", pages: 320, indexed: true },
  { key: "newreal1", name: "The New Real Book I", file: "NEWREAL1.PDF", pages: 440, indexed: true },
  { key: "newreal2", name: "The New Real Book II", file: "NEWREAL2.PDF", pages: 420, indexed: true },
  { key: "newreal3", name: "The New Real Book III", file: "NEWREAL3.PDF", pages: 400, indexed: true },
  { key: "jobim", name: "Tom Jobim Songbook vol. I", file: "Songbook Tom Jobim vol. I.pdf", pages: 76, indexed: false },
  { key: "jobim2", name: "Tom Jobim Songbook vol. II", file: "Songbook Tom Jobim vol. II.pdf", pages: 90, indexed: false },
  { key: "jobim3", name: "Tom Jobim Songbook vol. III", file: "Songbook Tom Jobim vol. III.pdf", pages: 90, indexed: false },
  { key: "chico", name: "Chico Buarque Songbook vol. I", file: "Songbook Chico Buarque vol. I.pdf", pages: 105, indexed: false },
  { key: "djavan", name: "Djavan Songbook vol. I & II", file: "Songbook Djavan vol. I & II.pdf", pages: 68, indexed: false },
  { key: "martino", name: "Pat Martino — Linear Expressions", file: "pdfcoffee.com-pat-martino-linear-expressions.pdf", pages: 63, indexed: false },
  { key: "bwv1002", name: "Bach — Partita No. 1, BWV 1002", file: "bwv1002-violin-partita-1.pdf", pages: 9, indexed: false, url: "/scores/bwv1002-violin-partita-1.pdf" },
  { key: "monk", name: "Thelonious Monk Compositions", file: "Thelonious_Monk_Compositions.pdf", pages: 73, indexed: false },
  { key: "baden", name: "Baden Powell Songbook vol. I", file: "Baden Pawel Vol. 1.pdf", pages: 26, indexed: false },
  { key: "bach1007", name: "Bach — Cello Suite No. 1, BWV 1007", file: "bwv1007-cello-suite-1.pdf", pages: 10, indexed: false, url: "/scores/bwv1007-cello-suite-1.pdf" },
  { key: "bach999", name: "Bach — Prelude in C minor, BWV 999", file: "bwv999-prelude-c-minor.pdf", pages: 3, indexed: false, url: "/scores/bwv999-prelude-c-minor.pdf" },
  { key: "bach1000", name: "Bach — Fugue in G minor, BWV 1000", file: "bwv1000-fugue-g-minor.pdf", pages: 4, indexed: false, url: "/scores/bwv1000-fugue-g-minor.pdf" },
];

export interface SongEntry {
  title: string;
  book: string;
  page: number;
}

export const SONG_INDEX: SongEntry[] = rawIndex as SongEntry[];

export function bookByKey(key: string): Songbook | undefined {
  return SONGBOOKS.find((b) => b.key === key);
}

/** Loose filename normalization so "Real Book 2.pdf" still lands. */
export function normalizeName(name: string): string {
  return name.toLowerCase().replace(/\.pdf$/i, "")
    .replace(/[^a-z0-9]/g, "").replace(/^the/, "");
}

/** Match an arbitrary file to a known book, or null. */
export function matchBook(filename: string): Songbook | null {
  const n = normalizeName(filename);
  for (const b of SONGBOOKS) {
    if (n === normalizeName(b.file) || n === normalizeName(b.name)) return b;
  }
  return null;
}

/** Rank search: startsWith beats includes; title order ties. */
export function searchSongs(query: string, limit = 60): SongEntry[] {
  const q = query.trim().toLowerCase();
  if (q.length < 2) return [];
  const starts: SongEntry[] = [];
  const within: SongEntry[] = [];
  for (const e of SONG_INDEX) {
    const t = e.title.toLowerCase();
    if (t.startsWith(q)) starts.push(e);
    else if (t.includes(q)) within.push(e);
    if (starts.length >= limit) break;
  }
  return [...starts, ...within].slice(0, limit);
}
