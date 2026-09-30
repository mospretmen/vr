import Foundation
import Observation
import MusicTheory

/// Records practice time and persists it locally. One "segment" per
/// continuous stretch in a mode; segments shorter than the noise floor are
/// dropped. Backend sync attaches here once accounts exist.
@MainActor
@Observable
final class PracticeLog {
    private static let storageKey = "fretspace.practiceSessions.v1"
    /// Mode flips shorter than this are browsing, not practicing.
    private static let minimumSegmentDuration: TimeInterval = 10

    private(set) var sessions: [PracticeSession] = []

    private var activeMode: PracticeSession.Mode?
    private var activeStart: Date?
    private let sync = PracticeSyncClient()
    private var syncTask: Task<Void, Never>?

    init() {
        restore()
        scheduleSync() // push anything recorded while offline last time
    }

    var summary: PracticeStats.Summary {
        PracticeStats.summary(of: sessions, asOf: .now)
    }

    // MARK: - Recording

    func beginSegment(_ mode: PracticeSession.Mode, at now: Date = .now) {
        endSegment(at: now)
        activeMode = mode
        activeStart = now
    }

    func endSegment(at now: Date = .now) {
        defer {
            activeMode = nil
            activeStart = nil
        }
        guard let mode = activeMode, let start = activeStart else { return }
        let duration = now.timeIntervalSince(start)
        guard duration >= Self.minimumSegmentDuration else { return }

        sessions.append(PracticeSession(
            id: UUID(), startedAt: start, duration: duration, mode: mode))
        persist()
        scheduleSync()
        AppLog.app.info("""
            Practice segment: \(mode.rawValue, privacy: .public), \
            \(Int(duration))s
            """)
    }

    // MARK: - Sync

    /// Debounced best-effort push; the server upserts by id so re-sending
    /// the recent window is harmless.
    private func scheduleSync() {
        syncTask?.cancel()
        let recent = sessions
        syncTask = Task { [sync] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await sync.push(recent)
        }
    }

    // MARK: - Persistence

    private func persist() {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(sessions),
                                      forKey: Self.storageKey)
        } catch {
            AppLog.app.error("Failed to persist practice log: \(error)")
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            sessions = try JSONDecoder().decode([PracticeSession].self, from: data)
        } catch {
            // Corrupt log is not worth crashing or wiping silently; keep the
            // bytes on disk for support, start the in-memory log fresh.
            AppLog.app.error("Failed to restore practice log: \(error)")
        }
    }
}

extension DisplayMode {
    var practiceMode: PracticeSession.Mode {
        switch self {
        case .scale: .scale
        case .chord: .chord
        case .chordInScale: .chordInScale
        case .exercise: .exercise
        }
    }
}
