// The songbook room: every fake book and songbook in one searchable place.
// The library is imported ONCE from the user's folder into the browser's
// Origin Private File System — after that it lives with the site: no
// permission prompts, no reconnecting, works offline. Nothing is uploaded;
// the books stay on this machine.
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  bookByKey, searchSongs, SONG_INDEX, SONGBOOKS, type SongEntry,
} from "../songbooks";

const REMOTE_URL_KEY = "sb-remote-url";
const REMOTE_AUTH_KEY = "sb-remote-auth";

function remoteConfig(): { base: string; auth: string } {
  try {
    return {
      base: localStorage.getItem(REMOTE_URL_KEY) ?? "",
      auth: localStorage.getItem(REMOTE_AUTH_KEY) ?? "",
    };
  } catch {
    return { base: "", auth: "" };
  }
}

function offsetKey(book: string): string {
  return `sb-offset-${book}`;
}
function getOffset(book: string): number {
  try {
    return Number(localStorage.getItem(offsetKey(book)) ?? 0) || 0;
  } catch {
    return 0;
  }
}

async function opfsRoot(): Promise<FileSystemDirectoryHandle | null> {
  try {
    return await navigator.storage.getDirectory();
  } catch {
    return null;
  }
}

// IndexedDB blob store — the fallback when OPFS writing isn't supported
// (Safari, visionOS Safari). Same books, same keys (the file name).
function booksDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open("fretspace-books", 1);
    req.onupgradeneeded = () => req.result.createObjectStore("books");
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
async function idbPutBook(name: string, blob: Blob): Promise<void> {
  const db = await booksDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction("books", "readwrite");
    tx.objectStore("books").put(blob, name.toLowerCase());
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}
async function idbGetBook(name: string): Promise<Blob | null> {
  try {
    const db = await booksDb();
    return await new Promise((resolve) => {
      const rq = db.transaction("books", "readonly").objectStore("books").get(name.toLowerCase());
      rq.onsuccess = () => resolve((rq.result as Blob) ?? null);
      rq.onerror = () => resolve(null);
    });
  } catch {
    return null;
  }
}
async function idbBookNames(): Promise<string[]> {
  try {
    const db = await booksDb();
    return await new Promise((resolve) => {
      const rq = db.transaction("books", "readonly").objectStore("books").getAllKeys();
      rq.onsuccess = () => resolve((rq.result as string[]) ?? []);
      rq.onerror = () => resolve([]);
    });
  } catch {
    return [];
  }
}

/** Store one book: OPFS when writable, IndexedDB otherwise. */
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
  await idbPutBook(name, file);
}

/** Load one book from wherever it was stored. */
async function loadBook(name: string): Promise<Blob | null> {
  const root = await opfsRoot();
  if (root) {
    try {
      const fh = await root.getFileHandle(name);
      return await fh.getFile();
    } catch { /* try IDB */ }
  }
  return idbGetBook(name);
}

type ImportProgress = { done: number; total: number; current: string } | null;

export function SongbookLibrary() {
  const [stored, setStored] = useState<Record<string, boolean>>({});
  const [progress, setProgress] = useState<ImportProgress>(null);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [viewer, setViewer] = useState<{ entry: SongEntry; url: string } | null>(null);
  const [offsets, setOffsets] = useState<Record<string, number>>(() =>
    Object.fromEntries(SONGBOOKS.map((b) => [b.key, getOffset(b.key)])));
  const [remote, setRemote] = useState(remoteConfig);
  const [showSettings, setShowSettings] = useState(false);
  const urlCache = useRef<Map<string, string>>(new Map());

  const canPick = typeof window !== "undefined" && "showDirectoryPicker" in window;

  /** What's already in the site's own storage — readable with no prompt. */
  const scanStored = useCallback(async () => {
    const names = new Set<string>();
    const root = await opfsRoot();
    if (root) {
      try {
        // @ts-expect-error async iteration of directory handles
        for await (const [name] of root.entries()) names.add(name.toLowerCase());
      } catch { /* empty */ }
    }
    for (const name of await idbBookNames()) names.add(name.toLowerCase());
    setStored(Object.fromEntries(
      SONGBOOKS.map((b) => [b.key, names.has(b.file.toLowerCase())])));
  }, []);

  useEffect(() => {
    void scanStored();
  }, [scanStored]);

  /** Store a batch of picked files; unknown names are reported, not lost. */
  const importFiles = useCallback(async (files: { name: string; blob: () => Promise<Blob> }[]) => {
    void navigator.storage.persist?.();
    const byName = new Map(SONGBOOKS.map((b) => [b.file.toLowerCase(), b]));
    const known = files.filter((f) => byName.has(f.name.toLowerCase()));
    let done = 0;
    const failed: string[] = [];
    for (const f of known) {
      const book = byName.get(f.name.toLowerCase())!;
      setProgress({ done, total: known.length, current: book.name });
      try {
        await storeBook(book.file, await f.blob());
        done += 1;
      } catch (err) {
        console.error("songbook import failed", book.file, err);
        failed.push(book.name);
      }
    }
    setProgress(null);
    setStatus(
      done > 0
        ? `Imported ${done} book${done === 1 ? "" : "s"} — your library now lives here.`
          + (failed.length ? ` Failed: ${failed.join(", ")}.` : "")
        : files.length > 0
          ? "None of those files matched a known book name."
          : "No files chosen.");
    void scanStored();
  }, [scanStored]);

  /** One-time import via the folder picker (Chrome/Edge). */
  const importLibrary = useCallback(async () => {
    try {
      // @ts-expect-error showDirectoryPicker is not in the TS lib yet
      const dir: FileSystemDirectoryHandle = await window.showDirectoryPicker({ mode: "read" });
      const files: { name: string; blob: () => Promise<Blob> }[] = [];
      try {
        // @ts-expect-error async iteration of directory handles
        for await (const [name, handle] of dir.entries()) {
          if (handle.kind === "file") {
            files.push({ name, blob: () => handle.getFile() });
          }
        }
      } catch { /* partial listing is fine */ }
      await importFiles(files);
    } catch {
      setProgress(null); /* user cancelled */
    }
  }, [importFiles]);

  const open = useCallback(async (entry: SongEntry) => {
    const book = bookByKey(entry.book);
    if (!book) return;
    setStatus(null);
    const cached = urlCache.current.get(book.key);
    if (cached) {
      setViewer({ entry, url: cached });
      return;
    }
    // 1. The library stored with the site (OPFS or IndexedDB).
    const blob = await loadBook(book.file);
    if (blob) {
      const url = URL.createObjectURL(blob);
      urlCache.current.set(book.key, url);
      setViewer({ entry, url });
      return;
    }
    // 2. A configured remote library (private bucket / static host).
    if (remote.base) {
      try {
        const base = remote.base.replace(/\/+$/, "");
        const res = await fetch(`${base}/${encodeURIComponent(book.file)}`, {
          headers: remote.auth ? { Authorization: remote.auth } : undefined,
        });
        if (!res.ok) throw new Error(String(res.status));
        const url = URL.createObjectURL(await res.blob());
        urlCache.current.set(book.key, url);
        setViewer({ entry, url });
        return;
      } catch {
        setStatus(`Remote library didn't serve ${book.file} — check the URL/key in settings.`);
        return;
      }
    }
    setStatus(`“${book.name}” isn't in your library yet — Import it, or set a remote library in ⚙.`);
  }, [remote]);

  const bump = useCallback((book: string, delta: number) => {
    setOffsets((prev) => {
      const next = { ...prev, [book]: (prev[book] ?? 0) + delta };
      try {
        localStorage.setItem(offsetKey(book), String(next[book]));
      } catch { /* private mode */ }
      return next;
    });
  }, []);

  const results = useMemo(() => searchSongs(query), [query]);
  const storedCount = Object.values(stored).filter(Boolean).length;

  return (
    <div className="mx-auto flex h-full w-full max-w-5xl flex-col">
      <div className="shrink-0 pb-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="font-display text-xl font-semibold text-ink">Songbook</h2>
            <p className="mt-0.5 text-sm text-ink-dim">
              {SONG_INDEX.length.toLocaleString()} tunes across {SONGBOOKS.length} books —
              search, click, play.
              {storedCount > 0 && ` ${storedCount} book${storedCount === 1 ? "" : "s"} in your library.`}
            </p>
          </div>
          <button
            onClick={() => setShowSettings((v) => !v)}
            aria-label="Library settings"
            className="rounded-full bg-fill-soft px-2.5 py-1.5 text-xs text-ink-dim transition-colors hover:text-ink"
          >
            ⚙
          </button>
          {storedCount < SONGBOOKS.length && (
            <label className="cursor-pointer rounded-full bg-fill-soft px-4 py-1.5 text-xs font-semibold text-ink-dim transition-colors hover:text-ink">
              Add book files…
              <input
                type="file"
                multiple
                accept=".pdf,application/pdf"
                className="hidden"
                onChange={(e) => {
                  const list = Array.from(e.target.files ?? []);
                  void importFiles(list.map((f) => ({ name: f.name, blob: async () => f })));
                  e.target.value = "";
                }}
              />
            </label>
          )}
          {canPick && storedCount < SONGBOOKS.length && (
            <button
              onClick={() => void importLibrary()}
              disabled={progress !== null}
              className={`rounded-full px-4 py-1.5 text-xs font-semibold transition-colors ${
                storedCount === 0
                  ? "bg-accent text-accent-deep hover:opacity-90"
                  : "bg-fill-soft text-ink-dim hover:text-ink"
              }`}
            >
              {progress
                ? `Importing ${progress.done + 1}/${progress.total}: ${progress.current}…`
                : storedCount === 0 ? "Import your library — one time" : "Import missing books"}
            </button>
          )}
        </div>
        {showSettings && (
          <div className="mt-3 rounded-xl border border-line p-3 text-xs">
            <div className="font-semibold text-ink">Remote library (optional)</div>
            <p className="mt-1 text-ink-mute">
              A private bucket or host that serves your book files by name —
              lets every device stream the library without importing.
            </p>
            <div className="mt-2 flex flex-wrap gap-2">
              <input
                defaultValue={remote.base}
                placeholder="https://your-bucket.example.com/songbooks"
                onBlur={(e) => {
                  const base = e.target.value.trim();
                  try { localStorage.setItem(REMOTE_URL_KEY, base); } catch { /* */ }
                  setRemote((r) => ({ ...r, base }));
                }}
                className="min-w-[280px] flex-1 rounded-md border border-line bg-transparent px-2.5 py-1.5 text-ink placeholder:text-ink-mute focus:border-accent focus:outline-none"
              />
              <input
                defaultValue={remote.auth}
                placeholder="Authorization header (optional)"
                onBlur={(e) => {
                  const auth = e.target.value.trim();
                  try { localStorage.setItem(REMOTE_AUTH_KEY, auth); } catch { /* */ }
                  setRemote((r) => ({ ...r, auth }));
                }}
                className="min-w-[220px] flex-1 rounded-md border border-line bg-transparent px-2.5 py-1.5 text-ink placeholder:text-ink-mute focus:border-accent focus:outline-none"
              />
            </div>
          </div>
        )}

        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search a tune — “All The Things”, “Desafinado”, “Nardis”…"
          className="mt-4 w-full rounded-xl border border-line bg-transparent px-4 py-2.5 text-base text-ink placeholder:text-ink-mute focus:border-accent focus:outline-none"
          autoFocus
        />
        {status && <p className="mt-2 text-xs text-amber-400/90">{status}</p>}
      </div>

      <div className="no-scrollbar min-h-0 flex-1 overflow-y-auto pb-6">
        {query.trim().length >= 2 ? (
          results.length > 0 ? (
            <ul>
              {results.map((e, i) => {
                const book = bookByKey(e.book)!;
                return (
                  <li key={`${e.title}-${e.book}-${i}`}>
                    <button
                      onClick={() => void open(e)}
                      className="group flex w-full items-baseline gap-3 border-l-2 border-transparent px-3 py-2 text-left transition-colors hover:border-accent hover:bg-fill-soft"
                    >
                      <span className="min-w-0 flex-1 truncate text-sm font-medium text-ink">
                        {e.title}
                      </span>
                      <span className="shrink-0 text-xs text-ink-mute">
                        {book.name} · p.{e.page}
                        {stored[e.book] === false && storedCount > 0 && " · not imported"}
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          ) : (
            <p className="px-3 py-6 text-sm text-ink-mute">
              Nothing in the index for “{query.trim()}”.
            </p>
          )
        ) : (
          <div className="grid gap-2.5 sm:grid-cols-2 lg:grid-cols-3">
            {SONGBOOKS.map((b) => {
              const count = SONG_INDEX.filter((e) => e.book === b.key).length;
              return (
                <div key={b.key}
                     className="rounded-xl border border-line p-4 transition-colors hover:border-white/20">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <div className="truncate text-sm font-semibold text-ink">{b.name}</div>
                      <div className="mt-0.5 text-[11px] text-ink-mute">
                        {count > 0 ? `${count} tunes indexed` : `${b.pages} pages`}
                        {stored[b.key] ? " · in library ✓" : " · not imported"}
                      </div>
                    </div>
                    <button
                      onClick={() => void open({ title: b.name, book: b.key, page: 1 })}
                      className="shrink-0 rounded-full bg-fill-soft px-3 py-1 text-[11px] text-ink-dim transition-colors hover:text-ink"
                    >
                      Open
                    </button>
                  </div>
                  {b.indexed && stored[b.key] && (
                    <div className="mt-2.5 flex items-center gap-1.5 text-[11px] text-ink-mute">
                      page offset
                      <button onClick={() => bump(b.key, -1)}
                              className="rounded bg-fill-soft px-1.5 hover:text-ink">−</button>
                      <span className="w-5 text-center tabular-nums">{offsets[b.key] ?? 0}</span>
                      <button onClick={() => bump(b.key, 1)}
                              className="rounded bg-fill-soft px-1.5 hover:text-ink">+</button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {viewer && (
        <div className="fixed inset-0 z-50 flex flex-col bg-black/92 backdrop-blur-sm">
          <div className="flex shrink-0 items-center gap-3 px-4 py-2.5">
            <div className="min-w-0 flex-1">
              <span className="truncate text-sm font-semibold text-ink">{viewer.entry.title}</span>
              <span className="ml-2 text-xs text-ink-mute">
                {bookByKey(viewer.entry.book)?.name} · p.{viewer.entry.page}
              </span>
            </div>
            {bookByKey(viewer.entry.book)?.indexed && (
              <div className="flex items-center gap-1.5 text-[11px] text-ink-mute">
                page off by?
                <button onClick={() => bump(viewer.entry.book, -1)}
                        className="rounded bg-fill-soft px-2 py-0.5 hover:text-ink">−</button>
                <span className="w-5 text-center tabular-nums">{offsets[viewer.entry.book] ?? 0}</span>
                <button onClick={() => bump(viewer.entry.book, 1)}
                        className="rounded bg-fill-soft px-2 py-0.5 hover:text-ink">+</button>
              </div>
            )}
            <button onClick={() => setViewer(null)}
                    className="rounded-full bg-fill-soft px-3.5 py-1 text-xs text-ink-dim hover:text-ink">
              ✕ Close
            </button>
          </div>
          <iframe
            key={`${viewer.url}-${offsets[viewer.entry.book] ?? 0}`}
            title={viewer.entry.title}
            src={`${viewer.url}#page=${Math.max(1, viewer.entry.page + (offsets[viewer.entry.book] ?? 0))}`}
            className="min-h-0 w-full flex-1 border-0"
          />
        </div>
      )}
    </div>
  );
}
