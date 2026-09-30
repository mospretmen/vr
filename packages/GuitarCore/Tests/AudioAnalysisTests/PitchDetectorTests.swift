import Testing
import MusicTheory
@testable import AudioAnalysis

@Suite("Pitch class detector")
struct PitchClassDetectorTests {
    @Test func cleanSingleNoteDominates() {
        var chroma = Chromagram.synthetic([.e], weights: [2.0])
        chroma[.b] = 0.6 // fifth harmonic bleed, well under dominance ratio
        #expect(PitchClassDetector.dominantPitchClass(in: chroma) == .e)
    }

    @Test func chordsAndSilenceAreNotSingleNotes() {
        #expect(PitchClassDetector.dominantPitchClass(in: .silence) == nil)
        let chord = Chromagram.synthetic([.c, .e, .g]) // three equal bins
        #expect(PitchClassDetector.dominantPitchClass(in: chord) == nil)
    }
}

@Suite("Note hit tracker")
struct NoteHitTrackerTests {
    let e = Chromagram.synthetic([.e], weights: [2.0])
    let a = Chromagram.synthetic([.a], weights: [2.0])

    /// Feeds frames and returns the per-frame hit results.
    private func feed(_ tracker: inout NoteHitTracker, _ frames: [Chromagram]) -> [Bool] {
        frames.map { tracker.feed($0) }
    }

    @Test func firesOnceAfterHoldFramesThenLatches() {
        var tracker = NoteHitTracker(holdFrames: 2)
        tracker.setTarget(.e)
        let hits = feed(&tracker, [e, e, e, e])
        #expect(hits == [false, true, false, false])
    }

    @Test func wrongNotesResetTheStreak() {
        var tracker = NoteHitTracker(holdFrames: 2)
        tracker.setTarget(.e)
        let hits = feed(&tracker, [e, a, e, e])
        #expect(hits == [false, false, false, true])
    }

    @Test func newTargetUnlatches() {
        var tracker = NoteHitTracker(holdFrames: 1)
        tracker.setTarget(.e)
        let first = feed(&tracker, [e])
        #expect(first == [true])

        tracker.setTarget(.a)
        let second = feed(&tracker, [a])
        #expect(second == [true]) // fresh target, fresh hit

        tracker.setTarget(.a) // same target: not a reset
        let third = feed(&tracker, [a])
        #expect(third == [false]) // still latched
    }

    @Test func noTargetNeverFires() {
        var tracker = NoteHitTracker(holdFrames: 1)
        let hits = feed(&tracker, [e])
        #expect(hits == [false])
    }
}
