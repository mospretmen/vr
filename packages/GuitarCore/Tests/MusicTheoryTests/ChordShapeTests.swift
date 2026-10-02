import Testing
@testable import MusicTheory

@Suite("Open chord shapes")
struct ChordShapeTests {
    let board = FretboardModel(tuning: .standard, fretCount: 22)

    @Test func everyShapeSpellsItsChord() {
        for shape in OpenChords.all {
            let sounding = Set(shape.positions.map { board.note(at: $0).pitchClass })
            let chordTones = Set(shape.chord.pitchClasses)

            // No wrong notes, root always present, at least a triad's worth
            // of distinct tones (open grips may omit the 5th, e.g. open C7).
            #expect(sounding.isSubset(of: chordTones), Comment(rawValue: shape.name))
            #expect(sounding.contains(shape.chord.root), Comment(rawValue: shape.name))
            #expect(sounding.count >= 3, Comment(rawValue: shape.name))
        }
    }

    @Test func seventhShapesActuallySoundTheSeventh() {
        for shape in OpenChords.all where shape.chord.quality.intervals.count == 4 {
            let seventh = shape.chord.root.transposed(by: shape.chord.quality.intervals[3])
            let sounding = Set(shape.positions.map { board.note(at: $0).pitchClass })
            #expect(sounding.contains(seventh), Comment(rawValue: shape.name))
        }
    }

    @Test func shapesHaveOneEntryPerString() {
        for shape in OpenChords.all {
            #expect(shape.frets.count == 6, Comment(rawValue: shape.name))
            #expect(shape.positions.count >= 3, Comment(rawValue: shape.name))
        }
    }

    @Test func lookupByChord() {
        let shapes = OpenChords.shapes(for: Chord(root: .e, quality: .minor))
        #expect(shapes.map(\.name) == ["Open Em"])
        #expect(OpenChords.shapes(for: Chord(root: .fSharp, quality: .minor)).isEmpty)
    }

    @Test func openCShapeExactNotes() {
        let shape = OpenChords.shapes(for: Chord(root: .c, quality: .major))[0]
        let notes = shape.positions.map { board.note(at: $0) }
        #expect(notes == [
            Note(.c, octave: 3), Note(.e, octave: 3), Note(.g, octave: 3),
            Note(.c, octave: 4), Note(.e, octave: 4),
        ])
    }
}
