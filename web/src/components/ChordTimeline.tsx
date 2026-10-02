import { useCallback } from "react";
import { fetchTimeline } from "../api";
import { chordSymbol, formatKey } from "../music";
import { useFetch } from "../useFetch";
import { ErrorNotice } from "./ErrorNotice";

interface ChordTimelineProps {
  trackId: string;
}

/** Chord progression for one track: a horizontal bar strip, one cell per event. */
export function ChordTimeline({ trackId }: ChordTimelineProps) {
  const load = useCallback(
    (signal: AbortSignal) => fetchTimeline(trackId, signal),
    [trackId],
  );
  const { state, retry } = useFetch(load);

  if (state.status === "loading") {
    return (
      <div className="mt-4 flex gap-px overflow-hidden rounded-xl border border-white/10">
        {Array.from({ length: 8 }, (_, i) => (
          <div key={i} className="h-14 w-16 shrink-0 animate-pulse bg-white/5" />
        ))}
      </div>
    );
  }

  if (state.status === "error") {
    return (
      <div className="mt-4">
        <ErrorNotice compact message={state.message} onRetry={retry} />
      </div>
    );
  }

  const { events, key } = state.data;

  if (events.length === 0) {
    return (
      <p className="mt-4 text-sm text-ink-mute">
        No chord events on this timeline yet.
      </p>
    );
  }

  return (
    <div className="mt-4">
      {key && (
        <p className="mb-2 text-[11px] font-medium uppercase tracking-[0.14em] text-ink-mute">
          Key of {formatKey(key)}
        </p>
      )}
      <div className="overflow-x-auto pb-1">
        <div className="flex min-w-max gap-px rounded-xl border border-white/10 bg-white/10">
          {events.map((event, i) => (
            <div
              key={event.startMs}
              className="flex min-w-16 flex-col items-center bg-raise-2 px-3 py-2 transition-colors first:rounded-l-xl last:rounded-r-xl hover:bg-raise"
            >
              <span className="text-[10px] tabular-nums text-ink-mute">
                {i + 1}
              </span>
              <span className="mt-0.5 font-mono text-sm font-medium text-ink">
                {chordSymbol(event.chord)}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
