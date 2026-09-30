import type { Track } from "../api";
import { formatKey } from "../music";
import { ChordTimeline } from "./ChordTimeline";

interface TrackCardProps {
  track: Track;
  expanded: boolean;
  onToggle: () => void;
}

function Badge({ children }: { children: React.ReactNode }) {
  return (
    <span className="rounded-full border border-zinc-700 bg-zinc-800/80 px-2.5 py-0.5 text-xs font-medium text-zinc-300">
      {children}
    </span>
  );
}

export function TrackCard({ track, expanded, onToggle }: TrackCardProps) {
  return (
    <div
      className={`rounded-xl border bg-zinc-900/60 transition-colors ${
        expanded ? "border-zinc-600" : "border-zinc-800 hover:border-zinc-700"
      }`}
    >
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={expanded}
        className="flex w-full items-center justify-between gap-4 rounded-xl p-5 text-left"
      >
        <div className="min-w-0">
          <h3 className="truncate font-semibold text-zinc-100">
            {track.title}
          </h3>
          {track.artist && (
            <p className="mt-0.5 truncate text-sm text-zinc-400">
              {track.artist}
            </p>
          )}
        </div>
        <div className="flex shrink-0 items-center gap-2">
          <Badge>{track.bpm} BPM</Badge>
          <Badge>{track.key ? formatKey(track.key) : "No key"}</Badge>
          <span
            aria-hidden="true"
            className={`text-zinc-500 transition-transform ${expanded ? "rotate-90" : ""}`}
          >
            ›
          </span>
        </div>
      </button>
      {expanded && (
        <div className="border-t border-zinc-800 px-5 pb-5">
          <ChordTimeline trackId={track.id} />
        </div>
      )}
    </div>
  );
}
