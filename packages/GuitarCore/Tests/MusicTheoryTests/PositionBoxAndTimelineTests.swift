import Testing
@testable import MusicTheory

@Suite("Position boxes & fret windows")
struct PositionBoxTests {
    let board = FretboardModel(tuning: .standard, fretCount: 22)
    let aMinorPent = Scale(root: .a, type: .minorPentatonic)

    @Test func fretWindowExcludesOutsideFrets() {
        let highlights = board.highlights(for: aMinorPent, frets: 5...8)
        #expect(!highlights.isEmpty)
        #expect(highlights.allSatisfy { (5...8).contains($0.position.fret) })
    }

    @Test func boxOneOfAMinorPentatonicIsTheClassicShape() {
        // The canonical "box 1" at the 5th fret: two notes per string,
        // all within frets 5–8.
        let box = board.positionBox(for: aMinorPent, startingAt: 5, span: 4)
        #expect(box.count == 12) // 2 notes × 6 strings
        for string in 0..<6 {
            #expect(box.filter { $0.position.string == string }.count == 2)
        }
        // Starts on the root: low string fret 5 is A.
        #expect(board.note(at: FretPosition(string: 0, fret: 5)).pitchClass == .a)
    }

    @Test func boxStartsFollowScaleTonesUpTheLowString() {
        let starts = board.boxStartFrets(for: aMinorPent, count: 5)
        // Low E string scale tones: A(5) C(8) D(10) E(12) G(15) — after the
        // open-position tones G(3) and the open E(0).
        #expect(starts == [0, 3, 5, 8, 10])
    }
}

@Suite("Chord timeline")
struct ChordTimelineTests {
    // A 12-bar-blues-ish snippet at 120bpm, 2s per bar.
    let timeline = ChordTimeline(events: [
        ChordEvent(startMs: 0,    durationMs: 2000, chord: Chord(root: .a, quality: .dominant7)),
        ChordEvent(startMs: 2000, durationMs: 2000, chord: Chord(root: .d, quality: .dominant7)),
        ChordEvent(startMs: 4000, durationMs: 2000, chord: Chord(root: .a, quality: .dominant7)),
        ChordEvent(startMs: 6000, durationMs: 2000, chord: Chord(root: .e, quality: .dominant7)),
    ], key: Scale(root: .a, type: .blues))

    @Test func lookupFindsTheSoundingChord() {
        #expect(timeline.chord(atMs: 0)?.root == .a)
        #expect(timeline.chord(atMs: 1999)?.root == .a)
        #expect(timeline.chord(atMs: 2000)?.root == .d)
        #expect(timeline.chord(atMs: 7999)?.root == .e)
    }

    @Test func lookupOutsideTimelineIsNil() {
        #expect(timeline.chord(atMs: 8000) == nil)
        #expect(timeline.chord(atMs: -1) == nil)
    }

    @Test func nextChangeSupportsPreAnnouncing() {
        let next = timeline.nextChange(afterMs: 1500)
        #expect(next?.startMs == 2000)
        #expect(next?.chord.root == .d)
        #expect(timeline.nextChange(afterMs: 6000) == nil)
    }

    @Test func unsortedInputIsSortedAndGapsStayEmpty() {
        let gappy = ChordTimeline(events: [
            ChordEvent(startMs: 3000, durationMs: 1000, chord: Chord(root: .g, quality: .major)),
            ChordEvent(startMs: 0, durationMs: 1000, chord: Chord(root: .c, quality: .major)),
        ])
        #expect(gappy.events.first?.chord.root == .c)
        #expect(gappy.chord(atMs: 1500) == nil) // silence between events
        #expect(gappy.durationMs == 4000)
    }
}
