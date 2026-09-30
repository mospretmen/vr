// Unit tests for the pure row<->wire mapping functions used by the Drizzle
// repos. No database involved: rows are constructed in memory and mapped
// both directions to prove the wire format survives a round-trip through
// the Postgres schema.

import { describe, expect, it } from "vitest";
import { seedTracks } from "../src/tracks/repo";
import {
  chordEventRowToTimelineEvent,
  rowToKey,
  rowsToTimeline,
  timelineToChordEventRows,
  trackRowToTrack,
  trackToRow,
  type BackingTrackRow,
  type ChordEventRow,
} from "../src/tracks/drizzle-repo";
import { rowToSession, sessionToRow } from "../src/practice/drizzle-repo";
import type { PracticeSession } from "../src/practice/repo";

/** Fill in the DB-generated columns an insert shape lacks. */
function asTrackRow(insert: ReturnType<typeof trackToRow>): BackingTrackRow {
  return {
    id: insert.id,
    title: insert.title,
    artist: insert.artist ?? null,
    bpm: insert.bpm,
    keyRoot: insert.keyRoot ?? null,
    keyType: insert.keyType ?? null,
    audioUrl: null,
    createdAt: new Date("2026-01-01T00:00:00Z"),
  };
}

function asChordEventRows(
  inserts: ReturnType<typeof timelineToChordEventRows>,
): ChordEventRow[] {
  return inserts.map((insert, i) => ({
    id: `00000000-0000-4000-8000-${String(i).padStart(12, "0")}`,
    trackId: insert.trackId,
    startMs: insert.startMs,
    durationMs: insert.durationMs,
    chordRoot: insert.chordRoot,
    chordQuality: insert.chordQuality,
  }));
}

describe("track row <-> wire mapping", () => {
  it("round-trips every seeded track through the backing_tracks row shape", () => {
    for (const { track } of seedTracks()) {
      const row = asTrackRow(trackToRow(track));
      expect(trackRowToTrack(row)).toEqual(track);
    }
  });

  it("round-trips every seeded timeline through chord_event rows", () => {
    for (const { track, timeline } of seedTracks()) {
      const trackRow = asTrackRow(trackToRow(track));
      const eventRows = asChordEventRows(
        timelineToChordEventRows(track.id, timeline),
      );
      expect(rowsToTimeline(trackRow, eventRows)).toEqual(timeline);
    }
  });

  it("maps a null key (both columns null) to key: null", () => {
    const row = asTrackRow(
      trackToRow({ id: "no-key", title: "No Key", artist: "X", bpm: 90, key: null }),
    );
    expect(row.keyRoot).toBeNull();
    expect(row.keyType).toBeNull();
    expect(trackRowToTrack(row).key).toBeNull();
    expect(rowToKey(null, null)).toBeNull();
    expect(rowToKey(0, null)).toBeNull();
  });

  it("stores chord quality losslessly (name/symbol/intervals)", () => {
    const [first] = seedTracks();
    const event = first!.timeline.events[0]!;
    const [rowInsert] = timelineToChordEventRows(first!.track.id, {
      events: [event],
      key: null,
    });
    const [row] = asChordEventRows([rowInsert!]);
    const mapped = chordEventRowToTimelineEvent(row!);
    expect(mapped).toEqual(event);
    // Fresh arrays, not shared references into the row.
    expect(mapped.chord.quality.intervals).not.toBe(row!.chordQuality.intervals);
  });
});

describe("practice session row <-> wire mapping", () => {
  const session: PracticeSession = {
    id: "11111111-2222-4333-8444-555555555555",
    deviceId: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
    startedAt: "2026-09-29T18:30:00.000Z",
    durationS: 900,
    mode: "backingTrack",
  };

  it("round-trips a session through the practice_sessions row shape", () => {
    const insert = sessionToRow(session);
    expect(insert.startedAt).toBeInstanceOf(Date);
    const row = { ...insert, userId: null };
    expect(rowToSession(row)).toEqual(session);
  });

  it("rejects rows with an unknown mode", () => {
    const row = { ...sessionToRow(session), userId: null, mode: "yodeling" };
    expect(() => rowToSession(row)).toThrow(/unknown/);
  });
});
