// Pure helpers for the Practice Stats card. No DOM, no fetch — unit tested.

/** Practice modes reported by the backend's session summary. */
export type PracticeMode =
  | "scale"
  | "chord"
  | "chordInScale"
  | "exercise"
  | "backingTrack"
  | "listen";

const MODE_LABELS: Record<PracticeMode, string> = {
  scale: "Scale",
  chord: "Chord",
  chordInScale: "Chord + Scale",
  exercise: "Exercise",
  backingTrack: "Backing Track",
  listen: "Listen",
};

/** Human-friendly label for a practice mode; unknown modes pass through. */
export function modeLabel(mode: string): string {
  return MODE_LABELS[mode as PracticeMode] ?? mode;
}

/**
 * Humanize a duration in seconds: "0m", "<1m", "24m", "3h 24m".
 * Sub-minute remainders are truncated once past the first minute.
 */
export function humanizeDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return "0m";
  if (seconds < 60) return "<1m";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
}

/** Days since the UTC epoch for a "YYYY-MM-DD" date string. */
function epochDay(isoDate: string): number {
  const ms = Date.parse(`${isoDate}T00:00:00Z`);
  if (Number.isNaN(ms)) throw new Error(`Invalid UTC date: ${isoDate}`);
  return ms / 86_400_000;
}

/**
 * Current streak: count of consecutive UTC days in `days` (sorted unique
 * "YYYY-MM-DD" strings) ending on `today` or yesterday. A last practice
 * day older than yesterday means the streak is broken → 0.
 */
export function computeStreak(days: string[], today: string): number {
  if (days.length === 0) return 0;
  const todayDay = epochDay(today);
  const lastDay = epochDay(days[days.length - 1]);
  if (todayDay - lastDay > 1) return 0; // last practice older than yesterday
  if (lastDay > todayDay) return 0; // future-dated data; treat as no streak

  let streak = 1;
  for (let i = days.length - 2; i >= 0; i--) {
    if (epochDay(days[i + 1]) - epochDay(days[i]) !== 1) break;
    streak++;
  }
  return streak;
}
