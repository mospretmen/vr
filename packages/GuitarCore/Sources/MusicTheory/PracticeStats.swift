import Foundation

/// One completed practice session. Mirrors the backend `practice_sessions`
/// table; synced once accounts exist, local-only until then.
public struct PracticeSession: Codable, Sendable, Hashable, Identifiable {
    public enum Mode: String, Codable, Sendable, CaseIterable {
        case scale, chord, chordInScale, exercise, backingTrack, listen
    }

    public var id: UUID
    public var startedAt: Date
    public var duration: TimeInterval
    public var mode: Mode

    public init(id: UUID, startedAt: Date, duration: TimeInterval, mode: Mode) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.mode = mode
    }
}

/// Aggregates sessions into the numbers the stats UI shows. Pure functions
/// of (sessions, calendar, reference date) so every figure is testable.
public enum PracticeStats {
    public struct Summary: Sendable, Equatable {
        public var totalTime: TimeInterval
        public var sessionCount: Int
        public var timeByMode: [PracticeSession.Mode: TimeInterval]
        /// Consecutive days practiced, counting back from the reference day
        /// (today counts if practiced today; otherwise the streak may end
        /// yesterday and still be alive).
        public var currentStreakDays: Int
    }

    public static func summary(
        of sessions: [PracticeSession],
        asOf now: Date,
        calendar: Calendar = .current
    ) -> Summary {
        var timeByMode: [PracticeSession.Mode: TimeInterval] = [:]
        for session in sessions {
            timeByMode[session.mode, default: 0] += session.duration
        }
        return Summary(
            totalTime: sessions.reduce(0) { $0 + $1.duration },
            sessionCount: sessions.count,
            timeByMode: timeByMode,
            currentStreakDays: streak(of: sessions, asOf: now, calendar: calendar)
        )
    }

    static func streak(
        of sessions: [PracticeSession],
        asOf now: Date,
        calendar: Calendar
    ) -> Int {
        let practicedDays = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
        guard !practicedDays.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: now)
        // A streak is alive if it includes today or ended yesterday.
        if !practicedDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  practicedDays.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var count = 0
        while practicedDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
