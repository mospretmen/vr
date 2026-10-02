import Testing
@testable import MusicTheory

@Suite("Modes & spelled degrees")
struct ModesTests {
    @Test func degreeLabelsSpellAlterations() {
        #expect(Modes.degreeLabels(of: .major) == ["1", "2", "3", "4", "5", "6", "7"])
        #expect(Modes.degreeLabels(of: .dorian) == ["1", "2", "♭3", "4", "5", "6", "♭7"])
        #expect(Modes.degreeLabels(of: .phrygian) == ["1", "♭2", "♭3", "4", "5", "♭6", "♭7"])
        #expect(Modes.degreeLabels(of: .mixolydian) == ["1", "2", "3", "4", "5", "6", "♭7"])
        #expect(Modes.degreeLabels(of: .minorPentatonic) == ["1", "♭3", "4", "5", "♭7"])
    }

    @Test func lydianSharpFourIsSpelledFlatFive() {
        // Deliberate chart convention: the table spells interval 6 as ♭5.
        #expect(Modes.degreeLabels(of: .lydian) == ["1", "2", "3", "♭5", "5", "6", "7"])
    }

    @Test func alterationsRelativeToMajor() {
        #expect(Modes.alterations(of: .major).isEmpty)
        #expect(Modes.alterations(of: .dorian) == ["♭3", "♭7"])
        #expect(Modes.alterations(of: .naturalMinor) == ["♭3", "♭6", "♭7"])
    }

    @Test func majorDegreeIdentifiesAllSevenModes() {
        let expected: [(ScaleType, Int)] = [
            (.major, 1), (.dorian, 2), (.phrygian, 3), (.lydian, 4),
            (.mixolydian, 5), (.naturalMinor, 6), (.locrian, 7),
        ]
        for (type, degree) in expected {
            #expect(Modes.majorDegree(of: type) == degree, "\(type.name)")
        }
        #expect(Modes.majorDegree(of: .harmonicMinor) == nil)
        #expect(Modes.majorDegree(of: .blues) == nil)
    }

    @Test func parentMajorRecovery() {
        #expect(Modes.parentMajor(of: Scale(root: .a, type: .dorian))
                == Scale(root: .g, type: .major))
        #expect(Modes.parentMajor(of: Scale(root: .e, type: .phrygian))
                == Scale(root: .c, type: .major))
        #expect(Modes.parentMajor(of: Scale(root: .a, type: .naturalMinor))
                == Scale(root: .c, type: .major))
        #expect(Modes.parentMajor(of: Scale(root: .a, type: .blues)) == nil)
    }

    @Test func summaryLine() {
        #expect(Modes.summary(of: Scale(root: .a, type: .dorian))
                == "2nd mode of G Major (Ionian) · ♭3 ♭7")
        #expect(Modes.summary(of: Scale(root: .c, type: .major)) == nil) // not interesting
        #expect(Modes.summary(of: Scale(root: .a, type: .blues)) == nil)
    }

    @Test func advancedScalesSpellAndClassifyCorrectly() {
        // E Phrygian Dominant: E F G♯ A B C D.
        let phrygDom = Scale(root: .e, type: .phrygianDominant)
        #expect(phrygDom.pitchClasses == [.e, .f, .gSharp, .a, .b, .c, .d])
        #expect(Modes.alterations(of: .phrygianDominant) == ["♭2", "♭6", "♭7"])
        #expect(Modes.majorDegree(of: .phrygianDominant) == nil) // not diatonic

        #expect(Modes.alterations(of: .lydianDominant) == ["♭5", "♭7"]) // ♯4 spelled flat-side
        #expect(ScaleType.bebopDominant.intervals.count == 8)
        // Eight-note scales are excluded from harmonization.
        let ladder = HarmonizedScale.triadLadder(
            of: Scale(root: .c, type: .bebopDominant),
            strings: [3, 4, 5],
            on: FretboardModel())
        #expect(ladder.isEmpty)
    }

    @Test func pitchClassDegreeLabelInScale() {
        let aDorian = Scale(root: .a, type: .dorian)
        #expect(Modes.degreeLabel(of: .c, in: aDorian) == "♭3")
        #expect(Modes.degreeLabel(of: .fSharp, in: aDorian) == "6")
        #expect(Modes.degreeLabel(of: .f, in: aDorian) == nil)
    }
}
