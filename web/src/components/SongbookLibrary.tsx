// The songbook room: every fake book and songbook in one searchable place.
// PDFs stay in the user's own folder (File System Access API); the app
// holds only the index and opens the right page on demand.
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  bookByKey, searchSongs, SONG_INDEX, SONGBOOKS, type SongEntry,
} from "../songbooks";

// ---- Tiny IndexedDB keyval for the directory handle ----
const DB_NAME = "fretspace-songbooks";
function idb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore("kv");
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
async function idbGet<T>(key: string): Promise<T | undefined> {
  const db = await idb();
  return new Promise((resolve) => {
    const tx = db.transaction("kv", "readonly").objectStore("kv").get(key);
    tx.onsuccess = () => resolve(tx.result as T | undefined);
    tx.onerror = () => resolve(undefined);
  });
}
async function idbSet(key: string, value: unknown): Promise<void> {
  const db = await idb();
  return new Promise((resolve) => {
    const tx = db.transaction("kv", "readwrite").objectStore("kv").put(value, key);
    tx.onsuccess = () => resolve();
    tx.onerror = () => resolve();
  });
}

type DirHandle = FileSystemDirectoryHandle & {
  queryPermission?: (d: { mode: string }) => Promise<string>;
  requestPermission?: (d: { mode: string }) => Promise<string>;
};

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

export function SongbookLibrary() {
  const [dir, setDir] = useState<DirHandle | null>(null);
  const [needsGesture, setNeedsGesture] = useState(false);
  const [found, setFound] = useState<Record<string, boolean>>({});
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [offsets, setOffsets] = useState<Record<string, number>>(() =>
    Object.fromEntries(SONGBOOKS.map((b) => [b.key, getOffset(b.key)])));
  const urlCache = useRef<Map<string, string>>(new Map());

  const supported = typeof window !== "undefined" && "showDirectoryPicker" in window;

  const scanFolder = useCallback(async (handle: DirHandle) => {
    const names = new Set<string>();
    try {
      // @ts-expect-error async iteration of directory handles
      for await (const [name] of handle.entries()) names.add(name.toLowerCase());
    } catch {
      return;
    }
    setFound(Object.fromEntries(
      SONGBOOKS.map((b) => [b.key, names.has(b.file.toLowerCase())])));
  }, []);

  useEffect(() => {
    void (async () => {
      const saved = await idbGet<DirHandle>("dir");
      if (!saved) return;
      const perm = await saved.queryPermission?.({ mode: "read" });
      if (perm === "granted") {
        setDir(saved);
        void scanFolder(saved);
      } else {
        setNeedsGesture(true);
      }
    })();
  }, [scanFolder]);

  const connect = useCallback(async () => {
    try {
      if (needsGesture) {
        const saved = await idbGet<DirHandle>("dir");
        if (saved && (await saved.requestPermission?.({ mode: "read" })) === "granted") {
          setDir(saved);
          setNeedsGesture(false);
          void scanFolder(saved);
          return;
        }
      }
      // @ts-expect-error showDirectoryPicker is not in the TS lib yet
      const handle: DirHandle = await window.showDirectoryPicker({ mode: "read" });
      await idbSet("dir", handle);
      setDir(handle);
      setNeedsGesture(false);
      void scanFolder(handle);
    } catch {
      /* user cancelled */
    }
  }, [needsGesture, scanFolder]);

  const open = useCallback(async (entry: SongEntry) => {
    const book = bookByKey(entry.book);
    if (!book || !dir) return;
    setStatus(null);
    try {
      const fh = await dir.getFileHandle(book.file);
      let url = urlCache.current.get(book.key);
      if (!url) {
        const file = await fh.getFile();
        url = URL.createObjectURL(file);
        urlCache.current.set(book.key, url);
      }
      const page = Math.max(1, entry.page + (offsets[entry.book] ?? 0));
      window.open(`${url}#page=${page}`, "_blank");
    } catch {
      setStatus(`Couldn't open ${book.file} — is it still in the connected folder?`);
    }
  }, [dir, offsets]);

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
  const anyFound = Object.values(found).some(Boolean);

  return (
    <div className="mx-auto flex h-full w-full max-w-5xl flex-col">
      <div className="shrink-0 pb-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="font-display text-xl font-semibold text-ink">Songbook</h2>
            <p className="mt-0.5 text-sm text-ink-dim">
              {SONG_INDEX.length.toLocaleString()} tunes across {SONGBOOKS.length} books —
              search, click, play.
            </p>
          </div>
          <button
            onClick={() => void connect()}
            className={`rounded-full px-4 py-1.5 text-xs font-semibold transition-colors ${
              dir && !needsGesture
                ? "bg-fill-soft text-ink-dim hover:text-ink"
                : "bg-accent text-accent-deep hover:opacity-90"
            }`}
          >
            {dir && !needsGesture ? "Folder connected ✓ — change" :
              needsGesture ? "Reconnect your songbook folder" : "Connect your songbook folder"}
          </button>
        </div>
        {!supported && (
          <p className="mt-2 text-xs text-amber-400/90">
            This browser can't open local folders — use Chrome or Edge for
            click-to-song. Search still works; page numbers are shown.
          </p>
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
                const available = found[e.book];
                return (
                  <li key={`${e.title}-${e.book}-${i}`}>
                    <button
                      onClick={() => void open(e)}
                      disabled={!dir || needsGesture}
                      className="group flex w-full items-baseline gap-3 border-l-2 border-transparent px-3 py-2 text-left transition-colors hover:border-accent hover:bg-fill-soft disabled:cursor-default"
                    >
                      <span className="min-w-0 flex-1 truncate text-sm font-medium text-ink">
                        {e.title}
                      </span>
                      <span className="shrink-0 text-xs text-ink-mute">
                        {book.name} · p.{e.page}
                        {available === false && " · not in folder"}
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
              const available = found[b.key];
              return (
                <div key={b.key}
                     className="rounded-xl border border-line p-4 transition-colors hover:border-white/20">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <div className="truncate text-sm font-semibold text-ink">{b.name}</div>
                      <div className="mt-0.5 text-[11px] text-ink-mute">
                        {count > 0 ? `${count} tunes indexed` : `${b.pages} pages`}
                        {anyFound && (available ? " · in folder ✓" : " · not found")}
                      </div>
                    </div>
                    <button
                      onClick={() => void open({ title: b.name, book: b.key, page: 1 })}
                      disabled={!dir || needsGesture}
                      className="shrink-0 rounded-full bg-fill-soft px-3 py-1 text-[11px] text-ink-dim transition-colors hover:text-ink disabled:opacity-40"
                    >
                      Open
                    </button>
                  </div>
                  {b.indexed && (
                    <div className="mt-2.5 flex items-center gap-1.5 text-[11px] text-ink-mute">
                      page offset
                      <button onClick={() => bump(b.key, -1)}
                              className="rounded bg-fill-soft px-1.5 hover:text-ink">−</button>
                      <span className="w-5 text-center tabular-nums">{offsets[b.key] ?? 0}</span>
                      <button onClick={() => bump(b.key, 1)}
                              className="rounded bg-fill-soft px-1.5 hover:text-ink">+</button>
                      <span className="text-ink-mute/70">— calibrate once if pages land off</span>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
