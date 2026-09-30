// Typed client for the Fretspace backend. All requests go through the Vite
// dev proxy (`/api` → http://localhost:3000, prefix stripped) so the app
// only ever talks same-origin.

// --- Wire types (mirror the backend's JSON schemas exactly) ---

export interface ChordQuality {
  name: string;
  symbol: string;
  intervals: number[];
}

export interface Chord {
  /** Pitch-class integer 0-11 (C = 0). */
  root: number;
  quality: ChordQuality;
}

export interface ScaleType {
  name: string;
  intervals: number[];
}

export interface Key {
  /** Pitch-class integer 0-11 (C = 0). */
  root: number;
  type: ScaleType;
}

export interface Track {
  id: string;
  title: string;
  artist: string | null;
  bpm: number;
  key: Key | null;
}

export interface TimelineEvent {
  startMs: number;
  durationMs: number;
  chord: Chord;
}

export interface Timeline {
  events: TimelineEvent[];
  key: Key | null;
}

// --- Fetch helpers ---

const API_BASE = "/api/v1";

async function getJson<T>(path: string, signal?: AbortSignal): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${API_BASE}${path}`, { signal });
  } catch (err) {
    // Let aborts propagate untouched; callers ignore them.
    if (err instanceof DOMException && err.name === "AbortError") throw err;
    throw new Error(
      "Couldn't reach the Fretspace backend. Is it running on port 3000?",
    );
  }
  if (!res.ok) {
    // The dev proxy answers 5xx when the backend is down, so treat server
    // errors as "backend unavailable" rather than a generic HTTP failure.
    throw new Error(
      res.status >= 500
        ? `The Fretspace backend isn't responding (HTTP ${res.status}). Start it with \`npm run dev\` in backend/ and retry.`
        : `Request failed: HTTP ${res.status}`,
    );
  }
  return (await res.json()) as T;
}

export function fetchTracks(signal?: AbortSignal): Promise<Track[]> {
  return getJson<Track[]>("/tracks", signal);
}

export function fetchTimeline(
  trackId: string,
  signal?: AbortSignal,
): Promise<Timeline> {
  return getJson<Timeline>(
    `/tracks/${encodeURIComponent(trackId)}/timeline`,
    signal,
  );
}
