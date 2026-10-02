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
    <span className="rounded-full border border-white/10 bg-white/5 px-2.5 py-0.5 text-xs font-medium tabular-nums text-ink-dim">
      {children}
    </span>
  );
}

export function TrackCard({ track, expanded, onToggle }: TrackCardProps) {
  return (
    <div
      className={`rounded-2xl border bg-raise transition-colors duration-300 ${
        expanded
          ? "border-accent/30"
          : "border-white/10 hover:border-white/20"
      }`}
    >
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={expanded}
        className="flex w-full items-center justify-between gap-4 rounded-2xl p-5 text-left"
      >
        <div className="min-w-0">
          <h3 className="truncate font-display font-semibold text-ink">
            {track.title}
          </h3>
          {track.artist && (
            <p className="mt-0.5 truncate text-sm text-ink-dim">
              {track.artist}
            </p>
          )}
        </div>
        <div className="flex shrink-0 items-center gap-2">
          <Badge>{track.bpm} BPM</Badge>
          <Badge>{track.key ? formatKey(track.key) : "No key"}</Badge>
          <span
            aria-hidden="true"
            className={`text-ink-mute transition-transform duration-300 ${expanded ? "rotate-90 text-accent" : ""}`}
          >
            ›
          </span>
        </div>
      </button>
      {expanded && (
        <div className="border-t border-white/10 px-5 pb-5">
          <ChordTimeline trackId={track.id} />
        </div>
      )}
    </div>
  );
}
