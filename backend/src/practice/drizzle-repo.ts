// Drizzle/Postgres-backed PracticeRepo. The row<->wire mapping functions are
// pure (no DB access) and unit-tested in test/db-mapping.test.ts.

import { eq, sql } from "drizzle-orm";
import type { Db } from "../db/client";
import { practiceSessions } from "../db/schema";
import {
  PRACTICE_MODES,
  summarizeSessions,
  type PracticeMode,
  type PracticeRepo,
  type PracticeSession,
  type PracticeSummary,
} from "./repo";

export type PracticeSessionRow = typeof practiceSessions.$inferSelect;
export type NewPracticeSessionRow = typeof practiceSessions.$inferInsert;

// --- Pure row <-> wire mappers ---

export function sessionToRow(session: PracticeSession): NewPracticeSessionRow {
  return {
    id: session.id,
    deviceId: session.deviceId,
    startedAt: new Date(session.startedAt),
    durationS: session.durationS,
    mode: session.mode,
  };
}

export function rowToSession(row: PracticeSessionRow): PracticeSession {
  const mode = row.mode as PracticeMode;
  if (!PRACTICE_MODES.includes(mode)) {
    throw new Error(`practice_sessions.mode has unknown value: ${row.mode}`);
  }
  return {
    id: row.id,
    deviceId: row.deviceId,
    startedAt: row.startedAt.toISOString(),
    durationS: row.durationS,
    mode,
  };
}

// --- Repository ---

export class DrizzlePracticeRepo implements PracticeRepo {
  constructor(private readonly db: Db) {}

  async upsertSessions(sessions: PracticeSession[]): Promise<number> {
    if (sessions.length === 0) return 0;

    const rows = sessions.map(sessionToRow);
    // Idempotent by id (the client-generated UUID): retries of the same
    // batch overwrite in place instead of failing on the primary key.
    await this.db
      .insert(practiceSessions)
      .values(rows)
      .onConflictDoUpdate({
        target: practiceSessions.id,
        set: {
          deviceId: sql`excluded.device_id`,
          startedAt: sql`excluded.started_at`,
          durationS: sql`excluded.duration_s`,
          mode: sql`excluded.mode`,
        },
      });
    return sessions.length;
  }

  async getSummary(deviceId: string): Promise<PracticeSummary> {
    const rows = await this.db
      .select()
      .from(practiceSessions)
      .where(eq(practiceSessions.deviceId, deviceId));
    return summarizeSessions(rows.map(rowToSession));
  }
}
