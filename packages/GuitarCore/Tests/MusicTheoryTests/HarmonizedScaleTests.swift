import Testing
@testable import MusicTheory

@Suite("Harmonized scale ladder")
struct HarmonizedScaleTests {
    let board = FretboardModel(tuning: .standard, fretCount: 22)

    @Test func cMajorLadderOnTopStringsClimbsTheNeck() {
        let ladder = HarmonizedScale.triadLadder(
            of: Scale(root: .c, type: .major), strings: [3, 4, 5], on: board)

        #expect(ladder.count == 7)
        #expect(ladder.map(\.romanNumeral) == ["I", "ii", "iii", "IV", "V", "vi", "vii°"])
        #expect(ladder.map(\.chord.root) == [.c, .d, .e, .f, .g, .a, .b])

        // The ladder never retreats down the neck.
        let frets = ladder.map(\.voicing.lowestFret)
        #expect(frets == frets.sorted())
        #expect(frets == [0, 1, 3, 5, 7, 8, 10]) // verified by hand

        // Every rung actually spells its own triad.
        for rung in ladder {
            let pcs = Set(rung.voicing.steps.map(\.note.pitchClass))
            #expect(pcs == Set(rung.chord.pitchClasses), Comment(rawValue: rung.romanNumeral))
        }
    }

    @Test func minorKeyNumeralsAreCased() {
        let ladder = HarmonizedScale.triadLadder(
            of: Scale(root: .a, type: .naturalMinor), strings: [2, 3, 4], on: board)
        #expect(ladder.map(\.romanNumeral) == ["i", "ii°", "III", "iv", "v", "VI", "VII"])
    }

    @Test func harmonicMinorRaisesTheFive() {
        let ladder = HarmonizedScale.triadLadder(
            of: Scale(root: .a, type: .harmonicMinor), strings: [3, 4, 5], on: board)
        // Harmonic minor: i ii° III+ iv V VI vii°
        #expect(ladder.map(\.romanNumeral) == ["i", "ii°", "III+", "iv", "V", "VI", "vii°"])
    }

    @Test func pentatonicScalesHaveNoLadder() {
        let ladder = HarmonizedScale.triadLadder(
            of: Scale(root: .a, type: .minorPentatonic), strings: [3, 4, 5], on: board)
        #expect(ladder.isEmpty)
    }
}
