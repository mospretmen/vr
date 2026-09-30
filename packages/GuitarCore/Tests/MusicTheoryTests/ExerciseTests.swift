import Testing
@testable import MusicTheory

@Suite("Exercise generator")
struct ExerciseTests {
    let board = FretboardModel(tuning: .standard, fretCount: 22)

    @Test func scaleRunGoesUpThenDownWithoutDoublingTheTurnaround() {
        let run = ExerciseGenerator.scaleRun(
            scale: Scale(root: .a, type: .minorPentatonic),
            box: 5, span: 4, on: board
        )
        // Box has 12 notes → 12 up + 11 down.
        #expect(run.steps.count == 23)
        #expect(run.steps.first == run.steps.last) // returns home
        #expect(run.steps.first?.note == Note(.a, octave: 2)) // low string, fret 5

        // The turnaround (highest note) appears exactly once.
        let peak = run.steps.max { $0.note < $1.note }!
        #expect(run.steps.filter { $0 == peak }.count == 1)
        #expect(peak.note == Note(.c, octave: 5)) // high E string, fret 8
    }

    @Test func cMajorTriadsOnTopStringsAreTheClassicShapes() {
        let drill = ExerciseGenerator.triadInversions(
            chord: Chord(root: .c, quality: .major),
            strings: [3, 4, 5], // G, B, high E
            on: board
        )
        #expect(drill.steps.count == 9) // 3 voicings × 3 notes
        let voicings = stride(from: 0, to: 9, by: 3).map {
            Array(drill.steps[$0..<($0 + 3)]).map(\.position.fret)
        }
        // Up the neck: 2nd inversion open shape, root position, 1st inversion.
        #expect(voicings == [[0, 1, 0], [5, 5, 3], [9, 8, 8]])

        // Every voicing spells C–E–G bottom to top in some rotation.
        for start in stride(from: 0, to: 9, by: 3) {
            let pcs = Set(drill.steps[start..<(start + 3)].map(\.note.pitchClass))
            #expect(pcs == [.c, .e, .g])
        }
    }

    @Test func voicingsAlwaysAscendInPitch() {
        let drill = ExerciseGenerator.triadInversions(
            chord: Chord(root: .a, quality: .minor),
            strings: [2, 3, 4], // D, G, B
            on: board
        )
        for start in stride(from: 0, to: drill.steps.count, by: 3) {
            let notes = drill.steps[start..<(start + 3)].map(\.note)
            #expect(notes[0] < notes[1] && notes[1] < notes[2])
        }
    }
}
