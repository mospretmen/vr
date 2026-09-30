import Testing
@testable import MusicTheory

@Suite("Chord identifier")
struct ChordIdentifierTests {
    @Test func namesPlainTriads() {
        #expect(ChordIdentifier.identify([.c, .e, .g]) == [Chord(root: .c, quality: .major)])
        #expect(ChordIdentifier.identify([.a, .c, .e]) == [Chord(root: .a, quality: .minor)])
        #expect(ChordIdentifier.identify([.g, .b, .d, .f]) == [Chord(root: .g, quality: .dominant7)])
    }

    @Test func surfacesEnharmonicAmbiguity() {
        // C-D-G reads as Csus2 and as Gsus4; both are valid.
        let matches = ChordIdentifier.identify([.c, .d, .g])
        #expect(Set(matches) == [
            Chord(root: .c, quality: .sus2),
            Chord(root: .g, quality: .sus4),
        ])
        // Sus2 precedes sus4 in the quality catalog → Csus2 is first reading.
        #expect(matches.first == Chord(root: .c, quality: .sus2))
    }

    @Test func diminishedSeventhHasFourReadings() {
        // Fully diminished is symmetric: every tone is a valid root.
        let matches = ChordIdentifier.identify([.b, .d, .f, .gSharp])
        #expect(matches.count == 4)
        #expect(matches.allSatisfy { $0.quality == .diminished7 })
    }

    @Test func rejectsNonChords() {
        #expect(ChordIdentifier.identify([.c]) == [])
        #expect(ChordIdentifier.identify([.c, .cSharp, .d]) == [])
    }

    @Test func bassNoteBreaksTiesOnTheFretboard() {
        let board = FretboardModel()
        // Am7 voicing at the 5th fret: A(low E,5) G(D,5) C(B,1)? Use open Am7:
        // A(open A) E(D,2) G(G,0) C(B,1) E(high E,0) — bass A → Am7, not C6.
        let positions = [
            FretPosition(string: 1, fret: 0), // A2
            FretPosition(string: 2, fret: 2), // E3
            FretPosition(string: 3, fret: 0), // G3
            FretPosition(string: 4, fret: 1), // C4
        ]
        let chord = ChordIdentifier.identify(positions: positions, on: board)
        #expect(chord == Chord(root: .a, quality: .minor7))
    }
}
