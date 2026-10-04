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
    /// Audible chord pads — on by default so a loaded track actually sounds.
    var padsEnabled = true
    var clickEnabled = false {
        didSet { updateMetronome() }
    }
    /// Beats per minute, inferred from the first event on load (one bar per
    /// event in all seeded content) unless supplied explicitly.
    private(set) var bpm: Double?

    private let metronome = MetronomeEngine()
    private let pads = ChordPadEngine()
    private var tickTask: Task<Void, Never>?
    private var lastPadChord: Chord?

    func load(_ timeline: ChordTimeline, title: String, bpm: Double? = nil) {
        stop()
        self.timeline = timeline
        self.title = title
        self.bpm = bpm ?? timeline.events.first.map { 240_000.0 / Double($0.durationMs) }
        positionMs = 0
        currentChord = timeline.chord(atMs: 0)
        upcoming = timeline.nextChange(afterMs: 0)
    }

    func play() {
        guard let timeline, !isPlaying, timeline.durationMs > 0 else { return }
        isPlaying = true
        updateMetronome()
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

                // Sound each chord as the clock enters it.
                if padsEnabled, let chord = currentChord, chord != lastPadChord {
                    lastPadChord = chord
                    let remaining = (timeline.events.first {
                        $0.startMs <= elapsed && elapsed < $0.endMs
                    }?.endMs ?? elapsed) - elapsed
                    pads.play(chord, durationMs: max(remaining, 300))
                }

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
        lastPadChord = nil
        pads.stop()
        updateMetronome()
    }

    private func updateMetronome() {
        if isPlaying, clickEnabled, let bpm {
            if !metronome.isRunning { metronome.start(bpm: bpm) }
        } else if metronome.isRunning {
            metronome.stop()
        }
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
