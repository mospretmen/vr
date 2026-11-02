import Testing
@testable import MusicTheory

@Suite("The voicing walk")
struct VoicingWalkTests {
    let board = FretboardModel(tuning: .standard, fretCount: 22)

    @Test func walkIsOrderedCleanAndChordTrue() {
        let chord = Chord(root: .c, quality: .major7)
        let walk = VoicingWalk.walk(for: chord)
        #expect(walk.count >= 12)
        // Ordered up the neck.
        let positions = walk.map(\.voicing.neckPosition)
        #expect(positions == positions.sorted())
        // No duplicates, nothing wider than a hand, only chord tones.
        #expect(Set(walk.map(\.voicing)).count == walk.count)
        for item in walk {
            let fretted = item.voicing.frets.compactMap { $0 }.filter { $0 > 0 }
            if let lo = fretted.min(), let hi = fretted.max() {
                #expect(hi - lo <= 4, Comment(rawValue: "\(item.kind) span"))
            }
            let tones = Set(chord.pitchClasses)
            for position in item.voicing.positions {
                #expect(tones.contains(board.note(at: position).pitchClass),
                        Comment(rawValue: "\(item.kind) stray note"))
            }
        }
    }

    @Test func dominantWalkIsDeep() {
        let walk = VoicingWalk.walk(for: Chord(root: .g, quality: .dominant7))
        #expect(walk.count >= 15)
    }
}
