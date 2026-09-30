import {
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  uuid,
} from "drizzle-orm/pg-core";
import type { ChordQuality, ScaleType } from "../tracks/repo";

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull().unique(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

// Backing tracks. `id` is a text slug (e.g. "blues-a", "ii-v-i-c") because
// the wire format (src/tracks/repo.ts `Track`) and the iOS client use
// human-readable ids validated as ^[A-Za-z0-9_-]+$.
//
// The musical key is stored as `key_root` (pitch class 0-11, C = 0) plus
// `key_type` (jsonb `{ name, intervals }`, matching the wire `ScaleType`),
// so `Track.key` is reconstructible losslessly. Both are null together for
// key-less tracks.
export const backingTracks = pgTable("backing_tracks", {
  id: text("id").primaryKey(),
  title: text("title").notNull(),
  artist: text("artist"),
  bpm: integer("bpm").notNull(),
  keyRoot: integer("key_root"),
  keyType: jsonb("key_type").$type<ScaleType>(),
  audioUrl: text("audio_url"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

// Chord timeline for a backing track: drives the fretboard overlay in the
// visionOS app during playback (which chord is active at a given time).
// `chord_quality` is jsonb `{ name, symbol, intervals }`, matching the wire
// `ChordQuality`, so `TimelineEvent.chord` is reconstructible losslessly.
export const chordEvents = pgTable(
  "chord_events",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    trackId: text("track_id")
      .notNull()
      .references(() => backingTracks.id, { onDelete: "cascade" }),
    startMs: integer("start_ms").notNull(),
    durationMs: integer("duration_ms").notNull(),
    chordRoot: integer("chord_root").notNull(),
    chordQuality: jsonb("chord_quality").$type<ChordQuality>().notNull(),
  },
  (table) => [index("chord_events_track_start_idx").on(table.trackId, table.startMs)],
);

// Practice sessions. Pre-auth, the client identifies itself with an
// `x-device-id` header (a UUID), stored in `device_id`. `user_id` is nullable
// until auth lands; at migration time one device_id maps onto one user_id.
// `id` is the client-generated UUID and doubles as the idempotency key for
// batch-sync retries (upsert by id).
export const practiceSessions = pgTable(
  "practice_sessions",
  {
    id: uuid("id").primaryKey(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }),
    deviceId: text("device_id").notNull(),
    startedAt: timestamp("started_at", { withTimezone: true }).notNull(),
    durationS: integer("duration_s").notNull(),
    mode: text("mode").notNull(),
  },
  (table) => [index("practice_sessions_device_idx").on(table.deviceId)],
);
