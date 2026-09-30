import Foundation
import Testing
@testable import MusicTheory

@Suite("Practice stats")
struct PracticeStatsTests {
    // Fixed reference: 2026-09-29 20:00 UTC.
    let now = Date(timeIntervalSince1970: 1_790_712_000)
    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    func session(daysAgo: Int, minutes: Double, mode: PracticeSession.Mode = .scale) -> PracticeSession {
        PracticeSession(
            id: UUID(),
            startedAt: now.addingTimeInterval(Double(-daysAgo) * 86_400),
            duration: minutes * 60,
            mode: mode
        )
    }

    @Test func summaryAggregatesTotalsAndModes() {
        let sessions = [
            session(daysAgo: 0, minutes: 30, mode: .scale),
            session(daysAgo: 0, minutes: 15, mode: .exercise),
            session(daysAgo: 1, minutes: 45, mode: .scale),
        ]
        let summary = PracticeStats.summary(of: sessions, asOf: now, calendar: calendar)
        #expect(summary.totalTime == 90 * 60)
        #expect(summary.sessionCount == 3)
        #expect(summary.timeByMode[.scale] == TimeInterval(75 * 60))
        #expect(summary.timeByMode[.exercise] == TimeInterval(15 * 60))
        #expect(summary.timeByMode[.listen] == nil)
    }

    @Test func streakCountsConsecutiveDaysIncludingToday() {
        let sessions = (0...3).map { session(daysAgo: $0, minutes: 10) }
        #expect(PracticeStats.streak(of: sessions, asOf: now, calendar: calendar) == 4)
    }

    @Test func streakSurvivesWhenTodayNotYetPracticed() {
        // Practiced the previous 3 days but not today: streak is alive at 3.
        let sessions = (1...3).map { session(daysAgo: $0, minutes: 10) }
        #expect(PracticeStats.streak(of: sessions, asOf: now, calendar: calendar) == 3)
    }

    @Test func streakBreaksOnAGap() {
        let sessions = [
            session(daysAgo: 0, minutes: 10),
            session(daysAgo: 1, minutes: 10),
            // gap on day 2
            session(daysAgo: 3, minutes: 10),
            session(daysAgo: 4, minutes: 10),
        ]
        #expect(PracticeStats.streak(of: sessions, asOf: now, calendar: calendar) == 2)
    }

    @Test func streakZeroWhenLastPracticeIsOld() {
        let sessions = [session(daysAgo: 2, minutes: 10)]
        #expect(PracticeStats.streak(of: sessions, asOf: now, calendar: calendar) == 0)
        #expect(PracticeStats.streak(of: [], asOf: now, calendar: calendar) == 0)
    }

    @Test func multipleSessionsSameDayCountOnceForStreak() {
        let sessions = [
            session(daysAgo: 0, minutes: 10),
            session(daysAgo: 0, minutes: 20),
            session(daysAgo: 1, minutes: 10),
        ]
        #expect(PracticeStats.streak(of: sessions, asOf: now, calendar: calendar) == 2)
    }
}
