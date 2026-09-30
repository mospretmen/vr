// Tracks repository. The in-memory implementation below seeds starter
// content in code; a Drizzle/Neon-backed implementation can swap in later
// by implementing the same TrackRepo interface.

// --- Wire types (must match the Swift Codable models exactly) ---

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

export interface TimelineEvent {
  startMs: number;
  durationMs: number;
  chord: Chord;
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

export interface Timeline {
  events: TimelineEvent[];
  key: Key | null;
}

// --- Repository interface ---

export interface TrackRepo {
  listTracks(): Promise<Track[]>;
  getTimeline(trackId: string): Promise<Timeline | null>;
}

// --- Chord qualities and scale types used by the seed content ---

export const DOMINANT_7: ChordQuality = {
  name: "Dominant 7",
  symbol: "7",
  intervals: [0, 4, 7, 10],
};

export const MINOR_7: ChordQuality = {
  name: "Minor 7",
  symbol: "m7",
  intervals: [0, 3, 7, 10],
};

export const MAJOR_7: ChordQuality = {
  name: "Major 7",
  symbol: "maj7",
  intervals: [0, 4, 7, 11],
};

export const BLUES_SCALE: ScaleType = {
  name: "Blues",
  intervals: [0, 3, 5, 6, 7, 10],
};

export const MAJOR_SCALE: ScaleType = {
  name: "Major (Ionian)",
  intervals: [0, 2, 4, 5, 7, 9, 11],
};

// --- Seed generation ---

const PITCH_CLASSES = 12;
const NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"] as const;

/** Milliseconds per 4/4 bar at the given tempo. */
function barMs(bpm: number): number {
  return (60_000 / bpm) * 4;
}

function buildEvents(
  bars: Chord[],
  bpm: number,
): TimelineEvent[] {
  const duration = barMs(bpm);
  return bars.map((chord, i) => ({
    startMs: i * duration,
    durationMs: duration,
    chord,
  }));
}

/**
 * 12-bar blues: I7 I7 I7 I7 / IV7 IV7 I7 I7 / V7 IV7 I7 V7.
 * Scale degrees expressed as semitone offsets from the tonic.
 */
const TWELVE_BAR_BLUES_OFFSETS = [0, 0, 0, 0, 5, 5, 0, 0, 7, 5, 0, 7];

function twelveBarBlues(tonic: number, bpm: number): {
  track: Track;
  timeline: Timeline;
} {
  const key: Key = { root: tonic, type: BLUES_SCALE };
  const bars: Chord[] = TWELVE_BAR_BLUES_OFFSETS.map((offset) => ({
    root: (tonic + offset) % PITCH_CLASSES,
    quality: DOMINANT_7,
  }));
  const tonicName = NOTE_NAMES[tonic % PITCH_CLASSES];
  return {
    track: {
      id: `blues-${tonicName?.toLowerCase().replace("#", "s")}`,
      title: `12-Bar Blues in ${tonicName}`,
      artist: null,
      bpm,
      key,
    },
    timeline: { events: buildEvents(bars, bpm), key },
  };
}

function twoFiveOneInC(bpm: number): { track: Track; timeline: Timeline } {
  const key: Key = { root: 0, type: MAJOR_SCALE };
  const bars: Chord[] = [
    { root: 2, quality: MINOR_7 }, // Dm7
    { root: 7, quality: DOMINANT_7 }, // G7
    { root: 0, quality: MAJOR_7 }, // Cmaj7
    { root: 0, quality: MAJOR_7 }, // Cmaj7
  ];
  return {
    track: {
      id: "ii-v-i-c",
      title: "ii–V–I in C",
      artist: null,
      bpm,
      key,
    },
    timeline: { events: buildEvents(bars, bpm), key },
  };
}

// --- In-memory implementation ---

interface SeededTrack {
  track: Track;
  timeline: Timeline;
}

function seedTracks(): SeededTrack[] {
  const A = 9;
  const E = 4;
  const G = 7;
  return [
    twelveBarBlues(A, 120),
    twelveBarBlues(E, 120),
    twelveBarBlues(G, 120),
    twoFiveOneInC(120),
  ];
}

export class InMemoryTrackRepo implements TrackRepo {
  private readonly byId: Map<string, SeededTrack>;

  constructor(seed: SeededTrack[] = seedTracks()) {
    this.byId = new Map(seed.map((s) => [s.track.id, s]));
  }

  async listTracks(): Promise<Track[]> {
    return [...this.byId.values()].map((s) => s.track);
  }

  async getTimeline(trackId: string): Promise<Timeline | null> {
    return this.byId.get(trackId)?.timeline ?? null;
  }
}

export function createInMemoryTrackRepo(): TrackRepo {
  return new InMemoryTrackRepo();
}
