import Testing
@testable import MusicTheory

@Suite("Progression templates")
struct ProgressionTemplateTests {
    @Test func twelveBarBluesInA() {
        let blues = ProgressionTemplate.twelveBarBlues(in: .a, bpm: 120)
        #expect(blues.events.count == 12)
        #expect(blues.durationMs == 24_000) // 12 bars × 2s at 120bpm
        #expect(blues.key == Scale(root: .a, type: .blues))

        let roots = blues.events.map(\.chord.root)
        #expect(roots == [.a, .a, .a, .a, .d, .d, .a, .a, .e, .d, .a, .e])
        #expect(blues.events.allSatisfy { $0.chord.quality == .dominant7 })

        // Bar 5 (index 4) starts at 8s and is the IV.
        #expect(blues.chord(atMs: 8_000) == Chord(root: .d, quality: .dominant7))
    }

    @Test func twoFiveOneInC() {
        let progression = ProgressionTemplate.twoFiveOne(in: .c)
        #expect(progression.events.map(\.chord) == [
            Chord(root: .d, quality: .minor7),
            Chord(root: .g, quality: .dominant7),
            Chord(root: .c, quality: .major7),
            Chord(root: .c, quality: .major7),
        ])
    }

    @Test func popLoopUsesDiatonicQualities() {
        let loop = ProgressionTemplate.popLoop(in: .g)
        #expect(loop.events.map(\.chord) == [
            Chord(root: .g, quality: .major),
            Chord(root: .d, quality: .major),
            Chord(root: .e, quality: .minor),
            Chord(root: .c, quality: .major),
        ])
    }

    @Test func barLengthTracksTempo() {
        #expect(ProgressionTemplate.barMs(bpm: 120) == 2000)
        #expect(ProgressionTemplate.barMs(bpm: 60) == 4000)
        #expect(ProgressionTemplate.barMs(bpm: 90) == 2667)
    }
}
