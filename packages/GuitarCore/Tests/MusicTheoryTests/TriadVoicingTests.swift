import Testing
@testable import MusicTheory

@Suite("Triad voicings")
struct TriadVoicingTests {
    let board = FretboardModel(tuning: .standard, fretCount: 22)

    @Test func cMajorOnTopStringsLabelsInversionsCorrectly() {
        let voicings = TriadVoicings.inversions(
            of: Chord(root: .c, quality: .major), strings: [3, 4, 5], on: board)
        #expect(voicings.count == 3)

        // Up the neck: (0,1,0) is the 2nd inversion (G in the bass),
        // (5,5,3) root position, (9,8,8) 1st inversion (E in the bass).
        #expect(voicings.map(\.inversion) == [.second, .root, .first])
        #expect(voicings.map { $0.positions.map(\.fret) } == [[0, 1, 0], [5, 5, 3], [9, 8, 8]])

        // The bass note of each voicing matches the inversion's chord tone.
        for voicing in voicings {
            let bass = voicing.steps[0].note.pitchClass
            #expect(voicing.chord.tone(of: bass) == voicing.inversion.bassTone)
        }
    }

    @Test func diminishedAndAugmentedVoicePlausibly() {
        for quality in [ChordQuality.diminished, .augmented] {
            let voicings = TriadVoicings.inversions(
                of: Chord(root: .b, quality: quality), strings: [2, 3, 4], on: board)
            #expect(voicings.count == 3, "\(quality.name) should voice all inversions")
            for voicing in voicings {
                let notes = voicing.steps.map(\.note)
                #expect(notes[0] < notes[1] && notes[1] < notes[2])
            }
        }
    }

    @Test func voicingsOrderedUpTheNeckOnEveryStringSet() {
        for strings in TriadVoicings.stringSets {
            let voicings = TriadVoicings.inversions(
                of: Chord(root: .g, quality: .minor), strings: strings, on: board)
            let lows = voicings.map(\.lowestFret)
            #expect(lows == lows.sorted(), "strings \(strings)")
        }
    }

    @Test func degenerateQualityReturnsEmpty() {
        let power = ChordQuality(name: "Power", symbol: "5", intervals: [0, 7, 12])
        let voicings = TriadVoicings.inversions(
            of: Chord(root: .e, quality: power), strings: [0, 1, 2], on: board)
        #expect(voicings.isEmpty) // 0 and 12 are the same pitch class
    }

    @Test func exerciseGeneratorStillProducesTheSameDrill() {
        // Regression guard for the refactor: the drill is the voicings flattened.
        let drill = ExerciseGenerator.triadInversions(
            chord: Chord(root: .c, quality: .major), strings: [3, 4, 5], on: board)
        let voicings = TriadVoicings.inversions(
            of: Chord(root: .c, quality: .major), strings: [3, 4, 5], on: board)
        #expect(drill.steps == voicings.flatMap(\.steps))
    }
}
