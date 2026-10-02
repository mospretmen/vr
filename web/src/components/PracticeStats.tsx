import { useCallback, useState } from "react";
import type { FormEvent } from "react";
import { fetchPracticeSummary } from "../api";
import type { PracticeSummary } from "../api";
import { computeStreak, humanizeDuration, modeLabel } from "../stats";
import { useFetch } from "../useFetch";
import { ErrorNotice } from "./ErrorNotice";

const DEVICE_ID_KEY = "fretspace.deviceId";

function loadStoredDeviceId(): string {
  try {
    return localStorage.getItem(DEVICE_ID_KEY) ?? "";
  } catch {
    return "";
  }
}

function storeDeviceId(id: string) {
  try {
    localStorage.setItem(DEVICE_ID_KEY, id);
  } catch {
    // Private-mode storage failures are non-fatal; the id just won't persist.
  }
}

/** Today's UTC date as "YYYY-MM-DD", matching the backend's day buckets. */
function todayUtc(): string {
  return new Date().toISOString().slice(0, 10);
}

export function PracticeStats() {
  const [deviceId, setDeviceId] = useState(loadStoredDeviceId);
  const [draft, setDraft] = useState(deviceId);

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const trimmed = draft.trim();
    if (!trimmed) return;
    storeDeviceId(trimmed);
    setDraft(trimmed);
    setDeviceId(trimmed);
  }

  return (
    <div className="rounded-2xl border border-white/10 bg-raise p-6 transition-colors duration-300 hover:border-white/20">
      <h2 className="font-display text-lg font-semibold text-ink">Session Summary</h2>

      <form onSubmit={handleSubmit} className="mt-3">
        <label
          htmlFor="device-id"
          className="block text-xs font-medium text-ink-dim"
        >
          Device ID
        </label>
        <div className="mt-1.5 flex gap-2">
          <input
            id="device-id"
            type="text"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder="00000000-0000-0000-0000-000000000000"
            spellCheck={false}
            autoComplete="off"
            className="min-w-0 flex-1 rounded-lg border border-white/10 bg-base px-3 py-1.5 font-mono text-xs text-ink placeholder:text-ink-mute/60 transition-colors focus:border-accent/50 focus:outline-none"
          />
          <button
            type="submit"
            disabled={!draft.trim()}
            className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs font-medium text-ink transition-colors hover:border-white/25 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-40"
          >
            Load
          </button>
        </div>
        <p className="mt-1.5 text-xs text-ink-mute">
          Paste the device ID from the Fretspace app. Your Vision Pro syncs
          practice sessions under an anonymous device UUID.
        </p>
      </form>

      <div className="mt-4">
        {deviceId ? (
          <SummaryView key={deviceId} deviceId={deviceId} />
        ) : (
          <p className="rounded-xl border border-dashed border-white/15 p-4 text-center text-xs text-ink-mute">
            Enter a device ID to see session history, streaks, and time on the
            fretboard.
          </p>
        )}
      </div>
    </div>
  );
}

function SummaryView({ deviceId }: { deviceId: string }) {
  const load = useCallback(
    (signal: AbortSignal) => fetchPracticeSummary(deviceId, signal),
    [deviceId],
  );
  const { state, retry } = useFetch(load);

  if (state.status === "loading") {
    return (
      <div
        className="h-40 animate-pulse rounded-xl bg-white/5"
        aria-busy="true"
        aria-label="Loading practice stats"
      />
    );
  }

  if (state.status === "error") {
    return <ErrorNotice message={state.message} onRetry={retry} compact />;
  }

  return <SummaryContent summary={state.data} />;
}

function SummaryContent({ summary }: { summary: PracticeSummary }) {
  if (summary.sessionCount === 0) {
    return (
      <div className="rounded-xl border border-dashed border-white/15 p-4 text-center">
        <p className="text-sm text-ink-dim">No practice yet.</p>
        <p className="mt-1 text-xs text-ink-mute">
          Sessions logged in the headset will show up here.
        </p>
      </div>
    );
  }

  const streak = computeStreak(summary.days, todayUtc());
  const modes = Object.entries(summary.timeByMode)
    .filter(([, seconds]) => seconds > 0)
    .sort(([, a], [, b]) => b - a);
  const maxModeTime = modes.length > 0 ? modes[0][1] : 0;

  return (
    <div>
      <dl className="grid grid-cols-3 gap-3">
        <Stat label="Total time" value={humanizeDuration(summary.totalTimeS)} />
        <Stat label="Sessions" value={String(summary.sessionCount)} />
        <Stat
          label="Streak"
          value={`${streak} ${streak === 1 ? "day" : "days"}`}
        />
      </dl>

      {modes.length > 0 && (
        <div className="mt-4">
          <h3 className="text-[11px] font-medium uppercase tracking-[0.14em] text-ink-mute">Time by mode</h3>
          <ul className="mt-2 space-y-2">
            {modes.map(([mode, seconds]) => (
              <li key={mode}>
                <div className="flex items-baseline justify-between text-xs">
                  <span className="text-ink-dim">{modeLabel(mode)}</span>
                  <span className="tabular-nums text-ink-mute">
                    {humanizeDuration(seconds)}
                  </span>
                </div>
                <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-white/5">
                  <div
                    className="h-full rounded-full bg-accent-strong/90 transition-[width] duration-500"
                    style={{
                      width: `${Math.max((seconds / maxModeTime) * 100, 2)}%`,
                    }}
                  />
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-white/10 bg-base/60 p-3">
      <dt className="text-xs text-ink-mute">{label}</dt>
      <dd className="mt-0.5 font-display text-base font-semibold tabular-nums text-ink">
        {value}
      </dd>
    </div>
  );
}
