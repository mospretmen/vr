/// A chord occupying a span of a backing track. Mirrors the backend
/// `chord_events` table so timelines round-trip through the API unchanged.
public struct ChordEvent: Codable, Sendable, Hashable {
    public var startMs: Int
    public var durationMs: Int
    public var chord: Chord

    public init(startMs: Int, durationMs: Int, chord: Chord) {
        self.startMs = startMs
        self.durationMs = durationMs
        self.chord = chord
    }

    public var endMs: Int { startMs + durationMs }
}

/// The chord progression of a backing track, queryable by playback time.
/// Drives the Phase 2 overlay: scale context + the currently sounding chord,
/// with the next change pre-announced so colors can transition early.
public struct ChordTimeline: Codable, Sendable, Hashable {
    /// Events sorted by start time; enforced on init.
    public private(set) var events: [ChordEvent]
    /// Overall harmonic context used for scale-layer display.
    public var key: Scale?

    public init(events: [ChordEvent], key: Scale? = nil) {
        self.events = events.sorted { $0.startMs < $1.startMs }
        self.key = key
    }

    public var durationMs: Int { events.map(\.endMs).max() ?? 0 }

    /// The chord sounding at `timeMs`, if any (binary search over starts).
    public func chord(atMs timeMs: Int) -> Chord? {
        guard let index = indexOfEvent(atMs: timeMs) else { return nil }
        return events[index].chord
    }

    /// The next chord change strictly after `timeMs` — lets the overlay
    /// pre-announce the upcoming chord a beat early.
    public func nextChange(afterMs timeMs: Int) -> ChordEvent? {
        events.first { $0.startMs > timeMs }
    }

    private func indexOfEvent(atMs timeMs: Int) -> Int? {
        var low = 0, high = events.count - 1
        var candidate: Int? = nil
        while low <= high {
            let mid = (low + high) / 2
            if events[mid].startMs <= timeMs {
                candidate = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        guard let i = candidate, timeMs < events[i].endMs else { return nil }
        return i
    }
}
