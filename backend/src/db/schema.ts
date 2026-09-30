import { integer, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull().unique(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const backingTracks = pgTable("backing_tracks", {
  id: uuid("id").primaryKey().defaultRandom(),
  title: text("title").notNull(),
  artist: text("artist"),
  bpm: integer("bpm"),
  keyRoot: text("key_root"),
  keyMode: text("key_mode"),
  audioUrl: text("audio_url"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

// Chord timeline for a backing track: drives the fretboard overlay in the
// visionOS app during playback (which chord is active at a given time).
export const chordEvents = pgTable("chord_events", {
  id: uuid("id").primaryKey().defaultRandom(),
  trackId: uuid("track_id")
    .notNull()
    .references(() => backingTracks.id, { onDelete: "cascade" }),
  startMs: integer("start_ms").notNull(),
  durationMs: integer("duration_ms").notNull(),
  chordRoot: text("chord_root").notNull(),
  chordQuality: text("chord_quality").notNull(),
});

export const practiceSessions = pgTable("practice_sessions", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  startedAt: timestamp("started_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  durationS: integer("duration_s"),
  mode: text("mode"),
});
