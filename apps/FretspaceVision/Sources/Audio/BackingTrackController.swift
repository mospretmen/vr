import Foundation
import Observation
import MusicTheory

/// Plays a chord timeline against a wall clock and publishes the sounding
/// chord for the overlay to follow. Audio-file playback (AVAudioEngine,
/// beat-accurate scheduling) replaces the bare clock in Phase 2 proper;
/// the observable surface here is what the rest of the app builds against.
@MainActor
@Observable
final class BackingTrackController {
    private(set) var timeline: ChordTimeline?
    private(set) var title: String = ""
    private(set) var isPlaying = false
    private(set) var positionMs = 0
    private(set) var currentChord: Chord?
    /// The chord change coming up next — lets the UI pre-announce it.
    private(set) var upcoming: ChordEvent?

    var loops = true

    private var tickTask: Task<Void, Never>?

    func load(_ timeline: ChordTimeline, title: String) {
        stop()
        self.timeline = timeline
        self.title = title
        positionMs = 0
        currentChord = timeline.chord(atMs: 0)
        upcoming = timeline.nextChange(afterMs: 0)
    }

    func play() {
        guard let timeline, !isPlaying, timeline.durationMs > 0 else { return }
        isPlaying = true
        let start = ContinuousClock.now - .milliseconds(positionMs)

        tickTask = Task {
            while !Task.isCancelled {
                let elapsed = Int((ContinuousClock.now - start) / .milliseconds(1))
                if elapsed >= timeline.durationMs {
                    if loops {
                        // Restart the clock reference rather than recursing.
                        positionMs = 0
                        currentChord = timeline.chord(atMs: 0)
                        upcoming = timeline.nextChange(afterMs: 0)
                        play(from: 0)
                        return
                    }
                    stop()
                    return
                }
                positionMs = elapsed
                currentChord = timeline.chord(atMs: elapsed)
                upcoming = timeline.nextChange(afterMs: elapsed)
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func play(from ms: Int) {
        isPlaying = false
        positionMs = ms
        play()
    }

    func pause() {
        tickTask?.cancel()
        tickTask = nil
        isPlaying = false
    }

    func stop() {
        pause()
        positionMs = 0
        currentChord = timeline?.chord(atMs: 0)
        upcoming = timeline?.nextChange(afterMs: 0)
    }

    func eject() {
        pause()
        timeline = nil
        title = ""
        positionMs = 0
        currentChord = nil
        upcoming = nil
    }
}
