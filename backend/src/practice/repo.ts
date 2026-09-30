// Practice-sessions repository. Two implementations exist: the in-memory
// one below (default) and the Drizzle/Neon-backed one in drizzle-repo.ts
// (used when DATABASE_URL is set).
//
// NOTE on identity: until auth lands, the client identifies itself with an
// `x-device-id` header, stored in `practice_sessions.device_id`. The
// `user_id` column is nullable for now; when auth ships, one device-id maps
// onto one user at migration time.

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

// --- Pure summary computation (shared by in-memory and Drizzle repos) ---

/** UTC calendar date (YYYY-MM-DD) of an ISO 8601 timestamp. */
function utcDay(isoTimestamp: string): string {
  return new Date(isoTimestamp).toISOString().slice(0, 10);
}

/** Aggregate already-filtered sessions (one device) into the wire summary. */
export function summarizeSessions(
  sessions: Iterable<PracticeSession>,
): PracticeSummary {
  let totalTimeS = 0;
  let sessionCount = 0;
  const timeByMode: Partial<Record<PracticeMode, number>> = {};
  const days = new Set<string>();

  for (const session of sessions) {
    sessionCount += 1;
    totalTimeS += session.durationS;
    timeByMode[session.mode] =
      (timeByMode[session.mode] ?? 0) + session.durationS;
    days.add(utcDay(session.startedAt));
  }

  return { totalTimeS, sessionCount, timeByMode, days: [...days].sort() };
}

// --- In-memory implementation ---

export class InMemoryPracticeRepo implements PracticeRepo {
  private readonly byId = new Map<string, PracticeSession>();

  async upsertSessions(sessions: PracticeSession[]): Promise<number> {
    for (const session of sessions) {
      this.byId.set(session.id, { ...session });
    }
    return sessions.length;
  }

  async getSummary(deviceId: string): Promise<PracticeSummary> {
    const mine = [...this.byId.values()].filter(
      (s) => s.deviceId === deviceId,
    );
    return summarizeSessions(mine);
  }
}

export function createInMemoryPracticeRepo(): PracticeRepo {
  return new InMemoryPracticeRepo();
}
