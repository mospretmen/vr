// Drizzle/Postgres-backed TrackRepo. The row<->wire mapping functions are
// pure (no DB access) and unit-tested in test/db-mapping.test.ts.

import { asc, eq } from "drizzle-orm";
import type { Db } from "../db/client";
import { backingTracks, chordEvents } from "../db/schema";
import type {
  Key,
  SeededTrack,
  Timeline,
  TimelineEvent,
  Track,
  TrackRepo,
} from "./repo";

export type BackingTrackRow = typeof backingTracks.$inferSelect;
export type NewBackingTrackRow = typeof backingTracks.$inferInsert;
export type ChordEventRow = typeof chordEvents.$inferSelect;
export type NewChordEventRow = typeof chordEvents.$inferInsert;

// --- Pure row <-> wire mappers ---

/** `key_root` + `key_type` columns -> wire `Key | null` (null unless both set). */
export function rowToKey(
  keyRoot: number | null,
  keyType: BackingTrackRow["keyType"],
): Key | null {
  if (keyRoot === null || keyType === null) return null;
  return { root: keyRoot, type: { name: keyType.name, intervals: [...keyType.intervals] } };
}

export function trackRowToTrack(row: BackingTrackRow): Track {
  return {
    id: row.id,
    title: row.title,
    artist: row.artist,
    bpm: row.bpm,
    key: rowToKey(row.keyRoot, row.keyType),
  };
}

export function trackToRow(track: Track): NewBackingTrackRow {
  return {
    id: track.id,
    title: track.title,
    artist: track.artist,
    bpm: track.bpm,
    keyRoot: track.key?.root ?? null,
    keyType: track.key?.type ?? null,
  };
}

export function chordEventRowToTimelineEvent(row: ChordEventRow): TimelineEvent {
  return {
    startMs: row.startMs,
    durationMs: row.durationMs,
    chord: {
      root: row.chordRoot,
      quality: {
        name: row.chordQuality.name,
        symbol: row.chordQuality.symbol,
        intervals: [...row.chordQuality.intervals],
      },
    },
  };
}

/** Track row (for the key) + its chord_event rows (start-ordered) -> wire Timeline. */
export function rowsToTimeline(
  trackRow: Pick<BackingTrackRow, "keyRoot" | "keyType">,
  eventRows: ChordEventRow[],
): Timeline {
  return {
    events: eventRows.map(chordEventRowToTimelineEvent),
    key: rowToKey(trackRow.keyRoot, trackRow.keyType),
  };
}

export function timelineToChordEventRows(
  trackId: string,
  timeline: Timeline,
): NewChordEventRow[] {
  return timeline.events.map((event) => ({
    trackId,
    startMs: event.startMs,
    durationMs: event.durationMs,
    chordRoot: event.chord.root,
    chordQuality: event.chord.quality,
  }));
}

// --- Repository ---

export class DrizzleTrackRepo implements TrackRepo {
  constructor(private readonly db: Db) {}

  async listTracks(): Promise<Track[]> {
    const rows = await this.db
      .select()
      .from(backingTracks)
      .orderBy(asc(backingTracks.createdAt), asc(backingTracks.id));
    return rows.map(trackRowToTrack);
  }

  async getTimeline(trackId: string): Promise<Timeline | null> {
    const [trackRow] = await this.db
      .select({ keyRoot: backingTracks.keyRoot, keyType: backingTracks.keyType })
      .from(backingTracks)
      .where(eq(backingTracks.id, trackId))
      .limit(1);
    if (!trackRow) return null;

    const eventRows = await this.db
      .select()
      .from(chordEvents)
      .where(eq(chordEvents.trackId, trackId))
      .orderBy(asc(chordEvents.startMs));

    return rowsToTimeline(trackRow, eventRows);
  }
}

/**
 * Idempotently upsert a seeded track and replace its chord timeline.
 * Used by the db:seed script (src/db/seed.ts).
 */
export async function upsertSeededTrack(
  db: Db,
  seeded: SeededTrack,
): Promise<void> {
  const row = trackToRow(seeded.track);
  await db
    .insert(backingTracks)
    .values(row)
    .onConflictDoUpdate({ target: backingTracks.id, set: row });
  await db.delete(chordEvents).where(eq(chordEvents.trackId, seeded.track.id));
  const eventRows = timelineToChordEventRows(seeded.track.id, seeded.timeline);
  if (eventRows.length > 0) {
    await db.insert(chordEvents).values(eventRows);
  }
}
