import Testing
@testable import MusicTheory

@Suite("Three notes per string")
struct ThreeNPSTests {
    let board = FretboardModel(tuning: .standard, fretCount: 22)

    @Test func cMajorFromEighthFretIsTheCanonicalShape() throws {
        let exercise = try #require(ExerciseGenerator.threeNotesPerString(
            scale: Scale(root: .c, type: .major), startingAt: 8, on: board))

        // 18 up + 17 down.
        #expect(exercise.steps.count == 35)

        let ascending = exercise.steps.prefix(18)
        let frets = (0..<6).map { string in
            ascending.filter { $0.position.string == string }.map(\.position.fret)
        }
        #expect(frets == [
            [8, 10, 12],  // C D E on low E
            [8, 10, 12],  // F G A on A
            [9, 10, 12],  // B C D on D
            [9, 10, 12],  // E F G on G
            [10, 12, 13], // A B C on B
            [10, 12, 13], // D E F on high E
        ])

        // Strictly ascending pitch, all in-scale, three per string.
        let notes = ascending.map(\.note)
        #expect(zip(notes, notes.dropFirst()).allSatisfy { $0 < $1 })
        let scale = Scale(root: .c, type: .major)
        #expect(notes.allSatisfy { scale.contains($0.pitchClass) })
    }

    @Test func startsOnFirstScaleToneAtOrAboveRequestedFret() throws {
        // A minor pentatonic from fret 4: first tone on low E at/above 4 is A(5).
        let exercise = try #require(ExerciseGenerator.threeNotesPerString(
            scale: Scale(root: .a, type: .minorPentatonic), startingAt: 4, on: board))
        #expect(exercise.steps.first?.position == FretPosition(string: 0, fret: 5))
    }

    @Test func refusesPatternsThatRunOffTheNeck() {
        // Starting near the last fret leaves no room for 18 ascending tones.
        let exercise = ExerciseGenerator.threeNotesPerString(
            scale: Scale(root: .c, type: .major), startingAt: 21, on: board)
        #expect(exercise == nil)
    }
}
