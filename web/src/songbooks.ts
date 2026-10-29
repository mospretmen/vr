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
  { key: "jobim", name: "Tom Jobim Songbook vol. I", file: "Songbook Tom Jobim vol. I.pdf", pages: 76, indexed: false },
  { key: "jobim2", name: "Tom Jobim Songbook vol. II", file: "Songbook Tom Jobim vol. II.pdf", pages: 90, indexed: false },
  { key: "jobim3", name: "Tom Jobim Songbook vol. III", file: "Songbook Tom Jobim vol. III.pdf", pages: 90, indexed: false },
  { key: "chico", name: "Chico Buarque Songbook vol. I", file: "Songbook Chico Buarque vol. I.pdf", pages: 105, indexed: false },
  { key: "djavan", name: "Djavan Songbook vol. I & II", file: "Songbook Djavan vol. I & II.pdf", pages: 68, indexed: false },
  { key: "martino", name: "Pat Martino — Linear Expressions", file: "pdfcoffee.com-pat-martino-linear-expressions.pdf", pages: 63, indexed: false },
  { key: "bwv1002", name: "Bach — Partita No. 1, BWV 1002", file: "IMSLP01305-BWV1002.pdf", pages: 9, indexed: false },
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
