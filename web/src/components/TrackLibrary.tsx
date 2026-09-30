import { useState } from "react";
import { fetchTracks } from "../api";
import { useFetch } from "../useFetch";
import { ErrorNotice } from "./ErrorNotice";
import { TrackCard } from "./TrackCard";

export function TrackLibrary() {
  const { state, retry } = useFetch(fetchTracks);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  if (state.status === "loading") {
    return (
      <div className="space-y-3" aria-busy="true" aria-label="Loading tracks">
        {Array.from({ length: 3 }, (_, i) => (
          <div
            key={i}
            className="h-[74px] animate-pulse rounded-xl border border-zinc-800 bg-zinc-900/60"
          />
        ))}
      </div>
    );
  }

  if (state.status === "error") {
    return <ErrorNotice message={state.message} onRetry={retry} />;
  }

  if (state.data.length === 0) {
    return (
      <div className="rounded-xl border border-dashed border-zinc-800 p-8 text-center">
        <p className="text-sm text-zinc-400">No tracks in the library yet.</p>
        <p className="mt-1 text-xs text-zinc-600">
          Seeded tracks will appear here once the backend has content.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {state.data.map((track) => (
        <TrackCard
          key={track.id}
          track={track}
          expanded={expandedId === track.id}
          onToggle={() =>
            setExpandedId((id) => (id === track.id ? null : track.id))
          }
        />
      ))}
    </div>
  );
}
