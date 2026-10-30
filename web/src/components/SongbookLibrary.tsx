// The songbook room: one dynamic search over every tune the user owns.
// Books are imported once into the browser's own storage (OPFS, with an
// IndexedDB fallback); each gets a cover thumbnail; songs open at their
// page in a built-in viewer. Favorites pin to the top. Nothing is ever
// uploaded — the books live with the site on this machine.
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  bookByKey, matchBook, searchSongs, SONG_INDEX, SONGBOOKS,
  type SongEntry,
} from "../songbooks";
import pdfWorkerUrl from "pdfjs-dist/build/pdf.worker.min.mjs?url";

// ---- Local persistence helpers ----

function offsetKey(book: string): string {
  return `sb-offset-${book}`;
}
/** Measured front-matter offsets (printed page → PDF page); the ± control
 *  overrides and remembers per book. */
const DEFAULT_OFFSETS: Record<string, number> = { evansbk: 3, realbk1: 13 };
function getOffset(book: string): number {
  try {
    const raw = localStorage.getItem(offsetKey(book));
    if (raw !== null) return Number(raw) || 0;
  } catch { /* private mode */ }
  return DEFAULT_OFFSETS[book] ?? 0;
}
const FAVORITES_KEY = "sb-favorites";
function loadFavorites(): Set<string> {
  try {
    return new Set(JSON.parse(localStorage.getItem(FAVORITES_KEY) ?? "[]") as string[]);
  } catch {
    return new Set();
  }
}

async function opfsRoot(): Promise<FileSystemDirectoryHandle | null> {
  try {
    return await navigator.storage.getDirectory();
  } catch {
    return null;
  }
}

function booksDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open("fretspace-books", 2);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains("books")) db.createObjectStore("books");
      if (!db.objectStoreNames.contains("thumbs")) db.createObjectStore("thumbs");
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
async function idbPut(store: "books" | "thumbs", name: string, value: unknown): Promise<void> {
  const db = await booksDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(store, "readwrite");
    tx.objectStore(store).put(value, name.toLowerCase());
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}
async function idbGet<T>(store: "books" | "thumbs", name: string): Promise<T | null> {
  try {
    const db = await booksDb();
    return await new Promise((resolve) => {
      const rq = db.transaction(store, "readonly").objectStore(store).get(name.toLowerCase());
      rq.onsuccess = () => resolve((rq.result as T) ?? null);
      rq.onerror = () => resolve(null);
    });
  } catch {
    return null;
  }
}
async function idbKeys(store: "books" | "thumbs"): Promise<string[]> {
  try {
    const db = await booksDb();
    return await new Promise((resolve) => {
      const rq = db.transaction(store, "readonly").objectStore(store).getAllKeys();
      rq.onsuccess = () => resolve((rq.result as string[]) ?? []);
      rq.onerror = () => resolve([]);
    });
  } catch {
    return [];
  }
}

async function storeBook(name: string, file: Blob): Promise<void> {
  const root = await opfsRoot();
  if (root) {
    try {
      const dst = await root.getFileHandle(name, { create: true });
      const writable = await dst.createWritable();
      await writable.write(file);
      await writable.close();
      return;
    } catch { /* fall through to IDB */ }
  }
  await idbPut("books", name, file);
}

async function loadBookFile(name: string): Promise<Blob | null> {
  const root = await opfsRoot();
  if (root) {
    try {
      const fh = await root.getFileHandle(name);
      return await fh.getFile();
    } catch { /* try IDB */ }
  }
  return idbGet<Blob>("books", name);
}

async function storedFileNames(): Promise<string[]> {
  const names = new Set<string>();
  const root = await opfsRoot();
  if (root) {
    try {
      // @ts-expect-error async iteration of directory handles
      for await (const [name] of root.entries()) names.add(name);
    } catch { /* empty */ }
  }
  for (const n of await idbKeys("books")) names.add(n);
  return [...names];
}

/** Render page 1 of a stored book to a small cover thumbnail (pdf.js). */
async function makeThumb(fileName: string): Promise<string | null> {
  try {
    const blob = await loadBookFile(fileName);
    if (!blob) return null;
    const pdfjs = await import("pdfjs-dist");
    pdfjs.GlobalWorkerOptions.workerSrc = pdfWorkerUrl;
    const doc = await pdfjs.getDocument({ data: await blob.arrayBuffer() }).promise;
    const page = await doc.getPage(1);
    const viewport = page.getViewport({ scale: 1 });
    const scale = 72 / viewport.width;
    const vp = page.getViewport({ scale });
    const canvas = document.createElement("canvas");
    canvas.width = Math.ceil(vp.width);
    canvas.height = Math.ceil(vp.height);
    const ctx = canvas.getContext("2d");
    if (!ctx) return null;
    await page.render({ canvas, canvasContext: ctx, viewport: vp }).promise;
    const url = canvas.toDataURL("image/jpeg", 0.8);
    void doc.cleanup();
    await idbPut("thumbs", fileName, url);
    return url;
  } catch (err) {
    console.error("thumb failed", fileName, err);
    return null;
  }
}

function Star({ filled }: { filled: boolean }) {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" aria-hidden
         fill={filled ? "currentColor" : "none"}
         stroke="currentColor" strokeWidth={filled ? 0 : 1.6}>
      <path d="M12 2.6l2.9 5.9 6.5.95-4.7 4.58 1.1 6.47L12 17.45 6.2 20.5l1.1-6.47L2.6 9.45l6.5-.95L12 2.6z" />
    </svg>
  );
}

// ---- In-app PDF viewer (pdf.js): lands exactly on the page ----

type PdfDoc = { numPages: number; getPage: (n: number) => Promise<unknown> };
const docCache = new Map<string, Promise<PdfDoc>>();

async function openDoc(fileName: string, blob: Blob): Promise<PdfDoc> {
  const cached = docCache.get(fileName);
  if (cached) return cached;
  const p = (async () => {
    const pdfjs = await import("pdfjs-dist");
    pdfjs.GlobalWorkerOptions.workerSrc = pdfWorkerUrl;
    return pdfjs.getDocument({ data: await blob.arrayBuffer() }).promise as unknown as PdfDoc;
  })();
  docCache.set(fileName, p);
  p.catch(() => docCache.delete(fileName));
  return p;
}

function PdfPageView({ fileName, blob, page, onPageCount }: {
  fileName: string; blob: Blob; page: number;
  onPageCount: (n: number) => void;
}) {
  const holder = useRef<HTMLDivElement | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const doc = await openDoc(fileName, blob);
        if (cancelled) return;
        onPageCount(doc.numPages);
        const target = Math.min(Math.max(1, page), doc.numPages);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const pg: any = await doc.getPage(target);
        if (cancelled) return;
        const holderEl = holder.current;
        if (!holderEl) return;
        const width = holderEl.clientWidth || 800;
        const base = pg.getViewport({ scale: 1 });
        const scale = Math.min(2.2, (width - 8) / base.width) * (window.devicePixelRatio || 1);
        const vp = pg.getViewport({ scale });
        const canvas = document.createElement("canvas");
        canvas.width = Math.ceil(vp.width);
        canvas.height = Math.ceil(vp.height);
        canvas.style.width = `${Math.ceil(vp.width / (window.devicePixelRatio || 1))}px`;
        const ctx = canvas.getContext("2d");
        if (!ctx) return;
        await pg.render({ canvas, canvasContext: ctx, viewport: vp }).promise;
        if (cancelled) return;
        holderEl.replaceChildren(canvas);
      } catch (err) {
        console.error("pdf render failed", err);
        if (!cancelled) {
          const detail = err instanceof Error ? `${err.name}: ${err.message}` : String(err);
          setError(`Couldn't render ${fileName} — ${detail.slice(0, 160)}`);
        }
      }
    })();
    return () => { cancelled = true; };
  }, [fileName, blob, page, onPageCount]);
  return (
    <div className="flex min-h-0 flex-1 items-start justify-center overflow-auto bg-black/40 p-2">
      {error
        ? <p className="mt-10 text-sm text-amber-400/90">{error}</p>
        : <div ref={holder} className="flex w-full justify-center" />}
    </div>
  );
}

// ---- The room ----

type ImportProgress = { done: number; total: number; current: string } | null;
const LETTERS = ["★", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
  "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "#"] as const;

/** Stable hue per book key for the spine fallback. */
function spineHue(key: string): number {
  let h = 0;
  for (const c of key) h = (h * 31 + c.charCodeAt(0)) % 360;
  return h;
}
function bookInitials(name: string): string {
  return name.replace(/[^A-Za-z ]/g, "").split(/\s+/)
    .filter((w) => w && !/^(the|of|in|a|an|vol)$/i.test(w))
    .map((w) => w[0].toUpperCase()).slice(0, 2).join("");
}

function firstLetter(title: string): string {
  const c = title.replace(/^(The|A|An)\s+/i, "").charAt(0).toUpperCase();
  return c >= "A" && c <= "Z" ? c : "#";
}

export function SongbookLibrary() {
  const [storedFiles, setStoredFiles] = useState<string[]>([]);
  const [thumbs, setThumbs] = useState<Record<string, string>>({});
  const [progress, setProgress] = useState<ImportProgress>(null);
  const [query, setQuery] = useState("");
  const [letter, setLetter] = useState<string>("A");
  const [status, setStatus] = useState<string | null>(null);
  const [favorites, setFavorites] = useState<Set<string>>(loadFavorites);
  const [viewer, setViewer] = useState<{ entry: SongEntry; blob: Blob; fileName: string } | null>(null);
  const [viewerPage, setViewerPage] = useState(1);
  const [viewerPages, setViewerPages] = useState(0);
  const [offsets, setOffsets] = useState<Record<string, number>>(() =>
    Object.fromEntries(SONGBOOKS.map((b) => [b.key, getOffset(b.key)])));

  const canPick = typeof window !== "undefined" && "showDirectoryPicker" in window;
  const [manageOpen, setManageOpen] = useState(false);
  const [remote, setRemote] = useState(() => {
    try {
      return {
        base: localStorage.getItem("sb-remote-url") ?? "",
        auth: localStorage.getItem("sb-remote-auth") ?? "",
      };
    } catch {
      return { base: "", auth: "" };
    }
  });

  /** Known books stored (key → actual file name), plus unknown extras. */
  const storedByKey = useMemo(() => {
    const map: Record<string, string> = {};
    const extras: string[] = [];
    for (const f of storedFiles) {
      const book = matchBook(f);
      if (book) map[book.key] = f;
      else if (f.toLowerCase().endsWith(".pdf")) extras.push(f);
    }
    return { map, extras };
  }, [storedFiles]);

  const refresh = useCallback(async () => {
    const names = await storedFileNames();
    setStoredFiles(names);
    const t: Record<string, string> = {};
    for (const n of names) {
      const cached = await idbGet<string>("thumbs", n);
      if (cached) t[n] = cached;
    }
    setThumbs(t);
    for (const n of names) {
      if (!t[n]) {
        const url = await makeThumb(n);
        if (url) setThumbs((prev) => ({ ...prev, [n]: url }));
      }
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const importFiles = useCallback(async (files: { name: string; blob: () => Promise<Blob> }[]) => {
    void navigator.storage.persist?.();
    const pdfs = files.filter((f) => f.name.toLowerCase().endsWith(".pdf"));
    let done = 0;
    const failed: string[] = [];
    for (const f of pdfs) {
      const book = matchBook(f.name);
      // Store under the canonical name when recognized, else as-is —
      // nothing the user adds is ever silently dropped.
      const storeName = book ? book.file : f.name;
      setProgress({ done, total: pdfs.length, current: book?.name ?? f.name });
      try {
        await storeBook(storeName, await f.blob());
        done += 1;
      } catch (err) {
        console.error("import failed", f.name, err);
        failed.push(f.name);
      }
    }
    setProgress(null);
    setStatus(done > 0
      ? `Imported ${done} book${done === 1 ? "" : "s"}.` + (failed.length ? ` Failed: ${failed.join(", ")}` : "")
      : "No PDF files chosen.");
    void refresh();
  }, [refresh]);

  const importLibrary = useCallback(async () => {
    setStatus("Opening the folder picker…");
    try {
      // @ts-expect-error showDirectoryPicker is not in the TS lib yet
      const dir: FileSystemDirectoryHandle = await window.showDirectoryPicker({ mode: "read" });
      const files: { name: string; blob: () => Promise<Blob> }[] = [];
      try {
        // @ts-expect-error async iteration of directory handles
        for await (const [name, handle] of dir.entries()) {
          if (handle.kind === "file") files.push({ name, blob: () => handle.getFile() });
        }
      } catch { /* partial listing is fine */ }
      await importFiles(files);
    } catch (err) {
      setProgress(null);
      const name = err instanceof Error ? err.name : "UnknownError";
      setStatus(name === "AbortError" ? null
        : `Folder picker failed (${name}) — try "Add book files…" instead.`);
    }
  }, [importFiles]);

  const blobCache = useRef<Map<string, Blob>>(new Map());
  const open = useCallback(async (entry: SongEntry) => {
    const book = bookByKey(entry.book);
    const fileName = book ? (storedByKey.map[book.key] ?? book.file) : entry.book;
    setStatus(null);
    let blob = blobCache.current.get(fileName) ?? await loadBookFile(fileName);
    if (!blob && book?.url) {
      try {
        const res = await fetch(book.url);
        if (res.ok) blob = await res.blob();
      } catch { /* offline */ }
    }
    if (!blob && remote.base) {
      try {
        const res = await fetch(`${remote.base.replace(/\/+$/, "")}/${encodeURIComponent(fileName)}`,
          { headers: remote.auth ? { Authorization: remote.auth } : undefined });
        if (res.ok) blob = await res.blob();
      } catch { /* unreachable */ }
    }
    if (blob) {
      blobCache.current.set(fileName, blob);
      setViewerPages(0);
      setViewerPage(Math.max(1, entry.page + (getOffset(entry.book) || 0)));
      setViewer({ entry, blob, fileName });
      return;
    }
    setStatus(`“${book?.name ?? entry.book}” isn't in your library yet — add its PDF above.`);
  }, [storedByKey, remote]);

  const bump = useCallback((book: string, delta: number) => {
    setOffsets((prev) => {
      const next = { ...prev, [book]: (prev[book] ?? 0) + delta };
      try {
        localStorage.setItem(offsetKey(book), String(next[book]));
      } catch { /* private mode */ }
      return next;
    });
  }, []);

  const toggleFavorite = useCallback((e: SongEntry) => {
    setFavorites((prev) => {
      const next = new Set(prev);
      const id = `${e.book}|${e.title}|${e.page}`;
      if (next.has(id)) next.delete(id);
      else next.add(id);
      try {
        localStorage.setItem(FAVORITES_KEY, JSON.stringify([...next]));
      } catch { /* private mode */ }
      return next;
    });
  }, []);

  const searching = query.trim().length >= 2;
  const rows = useMemo<SongEntry[]>(() => {
    if (searching) return searchSongs(query, 120);
    if (letter === "★") {
      return SONG_INDEX.filter((e) => favorites.has(`${e.book}|${e.title}|${e.page}`));
    }
    return SONG_INDEX.filter((e) => firstLetter(e.title) === letter);
  }, [searching, query, letter, favorites]);

  const storedCount = Object.keys(storedByKey.map).length + storedByKey.extras.length;

  // Generate covers on demand for whatever the user is looking at.
  const thumbQueue = useRef<Set<string>>(new Set());
  useEffect(() => {
    const names = new Set<string>();
    for (const e of rows) {
      const book = bookByKey(e.book);
      const fileName = book ? (storedByKey.map[book.key] ?? book.file) : e.book;
      if (!thumbs[fileName] && !thumbQueue.current.has(fileName)) names.add(fileName);
    }
    if (names.size === 0) return;
    void (async () => {
      for (const n of names) {
        thumbQueue.current.add(n);
        const url = await makeThumb(n);
        if (url) setThumbs((prev) => ({ ...prev, [n]: url }));
      }
    })();
  }, [rows, storedByKey, thumbs]);

  return (
    <div className="mx-auto flex h-full w-full max-w-5xl flex-col">
      <div className="shrink-0 pb-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="font-display text-xl font-semibold text-ink">Songbook</h2>
            <p className="mt-0.5 text-sm text-ink-dim">
              {SONG_INDEX.length.toLocaleString()} tunes, one search.
              {storedCount > 0 && ` ${storedCount} book${storedCount === 1 ? "" : "s"} in your library.`}
            </p>
          </div>
          <button
            onClick={() => setManageOpen((v) => !v)}
            className="rounded-full bg-fill-soft px-3.5 py-1.5 text-xs font-medium text-ink-dim transition-colors hover:text-ink"
          >
            ⚙ Library
          </button>
        </div>
        {(manageOpen || storedCount === 0) && (
          <div className="mt-3 rounded-xl border border-line p-3">
            <div className="flex flex-wrap items-center gap-2">
              <label
                onClick={() => setStatus("Choose your PDF files in the dialog…")}
                className="cursor-pointer rounded-full bg-accent px-4 py-1.5 text-xs font-semibold text-accent-deep transition-opacity hover:opacity-90">
                Add book files…
                <input
                  type="file"
                  multiple
                  accept=".pdf,application/pdf"
                  className="hidden"
                  onChange={(ev) => {
                    const list = Array.from(ev.target.files ?? []);
                    void importFiles(list.map((f) => ({ name: f.name, blob: async () => f })));
                    ev.target.value = "";
                  }}
                />
              </label>
              {canPick && (
                <button
                  onClick={() => void importLibrary()}
                  disabled={progress !== null}
                  className="rounded-full bg-fill-soft px-4 py-1.5 text-xs font-semibold text-ink-dim transition-colors hover:text-ink"
                >
                  {progress
                    ? `Importing ${progress.done + 1}/${progress.total}…`
                    : "…or import the whole folder"}
                </button>
              )}
              <span className="text-[11px] text-ink-mute">
                Books stay on this device — nothing is uploaded.
              </span>
            </div>
            <div className="mt-2.5 flex flex-wrap gap-2">
              <input
                defaultValue={remote.base}
                placeholder="Remote library URL (optional — private bucket)"
                onBlur={(ev) => {
                  const base = ev.target.value.trim();
                  try { localStorage.setItem("sb-remote-url", base); } catch { /* */ }
                  setRemote((r) => ({ ...r, base }));
                }}
                className="min-w-[260px] flex-1 rounded-md border border-line bg-transparent px-2.5 py-1.5 text-xs text-ink placeholder:text-ink-mute focus:border-accent focus:outline-none"
              />
              <input
                defaultValue={remote.auth}
                placeholder="Authorization header (optional)"
                onBlur={(ev) => {
                  const auth = ev.target.value.trim();
                  try { localStorage.setItem("sb-remote-auth", auth); } catch { /* */ }
                  setRemote((r) => ({ ...r, auth }));
                }}
                className="min-w-[200px] flex-1 rounded-md border border-line bg-transparent px-2.5 py-1.5 text-xs text-ink placeholder:text-ink-mute focus:border-accent focus:outline-none"
              />
            </div>
          </div>
        )}
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search a tune — “All The Things”, “Desafinado”, “Nardis”…"
          className="mt-3 w-full rounded-xl border border-line bg-transparent px-4 py-2.5 text-base text-ink placeholder:text-ink-mute focus:border-accent focus:outline-none"
          autoFocus
        />
        {status && <p className="mt-2 text-xs text-amber-400/90">{status}</p>}
        {!searching && (
          <div className="no-scrollbar mt-2 flex gap-0.5 overflow-x-auto">
            {LETTERS.map((l) => (
              <button
                key={l}
                onClick={() => setLetter(l)}
                className={`min-w-7 rounded px-1.5 py-1 text-xs font-semibold transition-colors ${
                  letter === l ? "bg-accent text-accent-deep"
                    : l === "★" ? "text-accent/70 hover:text-accent"
                    : "text-ink-mute hover:text-ink"
                }`}
              >
                {l}
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="no-scrollbar min-h-0 flex-1 overflow-y-auto pb-6">
        {rows.length > 0 ? (
          <ul>
            {rows.map((e, i) => {
              const book = bookByKey(e.book);
              const fileName = book ? (storedByKey.map[book.key] ?? book.file) : e.book;
              const thumb = thumbs[fileName] ?? thumbs[fileName.toLowerCase()];
              const id = `${e.book}|${e.title}|${e.page}`;
              const isFav = favorites.has(id);
              const inLibrary = book
                ? storedByKey.map[book.key] !== undefined || book.url !== undefined
                : false;
              return (
                <li key={`${id}-${i}`}>
                  <div className="group flex w-full items-center gap-3 border-l-2 border-transparent px-2 py-1.5 transition-colors hover:border-accent hover:bg-fill-soft">
                    <button
                      onClick={() => toggleFavorite(e)}
                      aria-label={isFav ? "Unfavorite" : "Favorite"}
                      className={`shrink-0 text-base leading-none transition-colors ${
                        isFav ? "text-accent" : "text-ink-mute/40 hover:text-ink-mute"
                      }`}
                    >
                      <Star filled={isFav} />
                    </button>
                    <button
                      onClick={() => void open(e)}
                      className="flex min-w-0 flex-1 items-center gap-3 text-left"
                    >
                      {thumb ? (
                        <img src={thumb} alt="" aria-hidden
                             className="h-10 w-7 shrink-0 rounded-[3px] border border-line object-cover" />
                      ) : (
                        <span aria-hidden
                              className="flex h-10 w-7 shrink-0 items-center justify-center rounded-[3px] border border-white/10 text-[9px] font-bold text-white/80"
                              style={{ background: `hsl(${spineHue(e.book)} 45% 28%)` }}>
                          {bookInitials(book?.name ?? e.book)}
                        </span>
                      )}
                      <span className="min-w-0 flex-1 truncate text-sm font-medium text-ink">
                        {e.title}
                      </span>
                      <span className="shrink-0 text-xs text-ink-mute">
                        {book?.name ?? e.book} · p.{e.page}
                        {!inLibrary && storedCount > 0 && " · not in library"}
                      </span>
                    </button>
                  </div>
                </li>
              );
            })}
          </ul>
        ) : (
          <p className="px-3 py-6 text-sm text-ink-mute">
            {searching
              ? `Nothing in the index for “${query.trim()}”.`
              : letter === "★"
                ? "No favorites yet — tap the star on any tune."
                : "Nothing under this letter."}
          </p>
        )}
      </div>

      {viewer && (
        <div className="fixed inset-0 z-50 flex flex-col bg-black/92 backdrop-blur-sm">
          <div className="flex shrink-0 flex-wrap items-center gap-3 px-4 py-2.5">
            <div className="min-w-0 flex-1">
              <span className="truncate text-sm font-semibold text-ink">{viewer.entry.title}</span>
              <span className="ml-2 text-xs text-ink-mute">
                {bookByKey(viewer.entry.book)?.name ?? viewer.entry.book}
              </span>
            </div>
            <div className="flex items-center gap-1.5 text-xs text-ink-dim">
              <button onClick={() => setViewerPage((p) => Math.max(1, p - 1))}
                      className="rounded bg-fill-soft px-2.5 py-1 hover:text-ink">‹</button>
              <span className="tabular-nums">
                p.{viewerPage}{viewerPages > 0 && ` / ${viewerPages}`}
              </span>
              <button onClick={() => setViewerPage((p) => (viewerPages ? Math.min(viewerPages, p + 1) : p + 1))}
                      className="rounded bg-fill-soft px-2.5 py-1 hover:text-ink">›</button>
            </div>
            {(bookByKey(viewer.entry.book)?.indexed ?? false) && (
              <div className="flex items-center gap-1.5 text-[11px] text-ink-mute">
                page off by?
                <button onClick={() => { bump(viewer.entry.book, -1); setViewerPage((p) => Math.max(1, p - 1)); }}
                        className="rounded bg-fill-soft px-2 py-0.5 hover:text-ink">−</button>
                <span className="w-5 text-center tabular-nums">{offsets[viewer.entry.book] ?? 0}</span>
                <button onClick={() => { bump(viewer.entry.book, 1); setViewerPage((p) => p + 1); }}
                        className="rounded bg-fill-soft px-2 py-0.5 hover:text-ink">+</button>
              </div>
            )}
            <button onClick={() => setViewer(null)}
                    className="rounded-full bg-fill-soft px-3.5 py-1 text-xs text-ink-dim hover:text-ink">
              ✕ Close
            </button>
          </div>
          <PdfPageView
            fileName={viewer.fileName}
            blob={viewer.blob}
            page={viewerPage}
            onPageCount={setViewerPages}
          />
        </div>
      )}
    </div>
  );
}
