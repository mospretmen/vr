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
      <div className="mt-4 flex gap-px overflow-hidden rounded-lg border border-zinc-800">
        {Array.from({ length: 8 }, (_, i) => (
          <div key={i} className="h-14 w-16 shrink-0 animate-pulse bg-zinc-800/60" />
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
      <p className="mt-4 text-sm text-zinc-500">
        No chord events on this timeline yet.
      </p>
    );
  }

  return (
    <div className="mt-4">
      {key && (
        <p className="mb-2 text-xs uppercase tracking-wide text-zinc-500">
          Key of {formatKey(key)}
        </p>
      )}
      <div className="overflow-x-auto pb-1">
        <div className="flex min-w-max gap-px rounded-lg border border-zinc-800 bg-zinc-800">
          {events.map((event, i) => (
            <div
              key={event.startMs}
              className="flex min-w-16 flex-col items-center bg-zinc-950/90 px-3 py-2 first:rounded-l-lg last:rounded-r-lg"
            >
              <span className="text-[10px] tabular-nums text-zinc-500">
                {i + 1}
              </span>
              <span className="mt-0.5 font-mono text-sm font-medium text-zinc-100">
                {chordSymbol(event.chord)}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
