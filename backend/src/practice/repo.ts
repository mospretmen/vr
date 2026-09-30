// Practice-sessions repository. The in-memory implementation below is the
// pre-auth stand-in; a Drizzle/Neon-backed implementation can swap in later
// by implementing the same PracticeRepo interface.
//
// NOTE on the Drizzle schema: `practice_sessions` in src/db/schema.ts is
// keyed to `users` (user_id). Until auth lands, the client identifies itself
// with an `x-device-id` header, so the wire/storage type here carries
// `deviceId` instead. When auth ships, deviceId maps onto
// practice_sessions.user_id (one device-id → one user at migration time).
// The Drizzle schema is intentionally left untouched.

// --- Wire types (must match the Swift Codable models exactly) ---

export const PRACTICE_MODES = [
  "scale",
  "chord",
  "chordInScale",
  "exercise",
  "backingTrack",
  "listen",
] as const;

export type PracticeMode = (typeof PRACTICE_MODES)[number];

export interface PracticeSession {
  /** Client-generated UUID; doubles as the idempotency key for retries. */
  id: string;
  /** Device UUID from the `x-device-id` header (pre-auth user stand-in). */
  deviceId: string;
  /** ISO 8601 timestamp. */
  startedAt: string;
  /** Practice duration in seconds. */
  durationS: number;
  mode: PracticeMode;
}

export interface PracticeSummary {
  totalTimeS: number;
  sessionCount: number;
  timeByMode: Partial<Record<PracticeMode, number>>;
  /** Sorted unique YYYY-MM-DD dates (UTC) with practice, for streak rendering. */
  days: string[];
}

// --- Repository interface ---

export interface PracticeRepo {
  /**
   * Upsert sessions by id (idempotent: client retries of the same batch are
   * safe). Returns the number of sessions processed.
   */
  upsertSessions(sessions: PracticeSession[]): Promise<number>;
  getSummary(deviceId: string): Promise<PracticeSummary>;
}

// --- In-memory implementation ---

/** UTC calendar date (YYYY-MM-DD) of an ISO 8601 timestamp. */
function utcDay(isoTimestamp: string): string {
  return new Date(isoTimestamp).toISOString().slice(0, 10);
}

export class InMemoryPracticeRepo implements PracticeRepo {
  private readonly byId = new Map<string, PracticeSession>();

  async upsertSessions(sessions: PracticeSession[]): Promise<number> {
    for (const session of sessions) {
      this.byId.set(session.id, { ...session });
    }
    return sessions.length;
  }

  async getSummary(deviceId: string): Promise<PracticeSummary> {
    let totalTimeS = 0;
    let sessionCount = 0;
    const timeByMode: Partial<Record<PracticeMode, number>> = {};
    const days = new Set<string>();

    for (const session of this.byId.values()) {
      if (session.deviceId !== deviceId) continue;
      sessionCount += 1;
      totalTimeS += session.durationS;
      timeByMode[session.mode] =
        (timeByMode[session.mode] ?? 0) + session.durationS;
      days.add(utcDay(session.startedAt));
    }

    return { totalTimeS, sessionCount, timeByMode, days: [...days].sort() };
  }
}

export function createInMemoryPracticeRepo(): PracticeRepo {
  return new InMemoryPracticeRepo();
}
