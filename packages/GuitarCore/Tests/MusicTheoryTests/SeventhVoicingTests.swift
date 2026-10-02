import Testing
@testable import MusicTheory

@Suite("Drop-2 seventh voicings")
struct SeventhVoicingTests {
    let board = FretboardModel(tuning: .standard, fretCount: 22)
    let topFour = [2, 3, 4, 5] // D G B E

    @Test func cmaj7OnTopStringsProducesTheClassicShapes() {
        let voicings = SeventhVoicings.drop2(
            of: Chord(root: .c, quality: .major7), strings: topFour, on: board)
        #expect(voicings.count == 4)

        // Ordered up the neck; these are the textbook drop-2 grips.
        #expect(voicings.map { $0.positions.map(\.fret) } == [
            [2, 4, 1, 3],     // E in bass  — 1st inversion
            [5, 5, 5, 7],     // G in bass  — 2nd inversion
            [9, 9, 8, 8],     // B in bass  — 3rd inversion
            [10, 12, 12, 12], // C in bass  — root position
        ])
        #expect(voicings.map(\.inversion) == [.first, .second, .third, .root])
    }

    @Test func bassNoteMatchesTheInversionLabel() {
        let chord = Chord(root: .g, quality: .dominant7)
        for strings in SeventhVoicings.stringSets {
            for voicing in SeventhVoicings.drop2(of: chord, strings: strings, on: board) {
                let bass = voicing.steps[0].note.pitchClass
                #expect(chord.tone(of: bass) == voicing.inversion.bassTone,
                        "strings \(strings), \(voicing.inversion.label)")
            }
        }
    }

    @Test func voicesAlwaysAscendAndSpellTheChord() {
        let chord = Chord(root: .f, quality: .minor7)
        for voicing in SeventhVoicings.drop2(of: chord, strings: [1, 2, 3, 4], on: board) {
            let notes = voicing.steps.map(\.note)
            #expect(zip(notes, notes.dropFirst()).allSatisfy { $0 < $1 })
            #expect(Set(notes.map(\.pitchClass)) == Set(chord.pitchClasses))
        }
    }

    @Test func triadsHaveNoDropTwo() {
        let voicings = SeventhVoicings.drop2(
            of: Chord(root: .c, quality: .major), strings: topFour, on: board)
        #expect(voicings.isEmpty)
    }

    @Test func halfDiminishedVoicesAllInversions() {
        let voicings = SeventhVoicings.drop2(
            of: Chord(root: .b, quality: .minor7b5), strings: topFour, on: board)
        #expect(voicings.count == 4)
    }
}
