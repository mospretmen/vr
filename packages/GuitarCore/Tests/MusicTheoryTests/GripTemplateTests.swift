import Testing
@testable import MusicTheory

/// Every movable template grip, instantiated anywhere on the neck, must
/// sound only chord tones and always include the root — the truth gate
/// that keeps the CAGED catalog chart-honest.
@Suite("Grip template catalog")
struct GripTemplateTests {
    let board = FretboardModel(tuning: .standard, fretCount: 22)

    @Test func everyTemplateGripSpellsItsChord() {
        let qualities: [ChordQuality] = ChordQuality.all.filter { quality in
            ChordGripTemplates.grips(for: Chord(root: .c, quality: quality)).isEmpty == false
        }
        for quality in qualities {
            for root in PitchClass.allCases {
                let chord = Chord(root: root, quality: quality)
                for grip in ChordGripTemplates.grips(for: chord) {
                    let sounding = grip.frets.enumerated().compactMap { string, fret in
                        fret.map { board.note(at: FretPosition(string: string, fret: $0)).pitchClass }
                    }
                    let tones = Set(chord.pitchClasses)
                    #expect(Set(sounding).isSubset(of: tones),
                            Comment(rawValue: "\(chord.symbol) grip \(grip.frets)"))
                    #expect(sounding.contains(chord.root),
                            Comment(rawValue: "\(chord.symbol) grip \(grip.frets) missing root"))
                }
            }
        }
    }

    @Test func cagedShapesArePresentForTheCoreQualities() {
        // G7 must now offer at least 4 distinct template positions.
        let g7 = ChordGripTemplates.grips(for: Chord(root: .g, quality: .dominant7))
        #expect(g7.count >= 4)
        // The C7-shape of G7 anchors at fret 10: x(10)9(10)8(7).
        #expect(g7.contains { $0.frets == [nil, 10, 9, 10, 8, 7] })
    }
}
