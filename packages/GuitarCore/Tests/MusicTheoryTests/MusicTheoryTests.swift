import Testing
@testable import MusicTheory

@Suite("PitchClass & Note")
struct PitchClassTests {
    @Test func transposeWrapsAroundOctave() {
        #expect(PitchClass.b.transposed(by: 1) == .c)
        #expect(PitchClass.c.transposed(by: -1) == .b)
        #expect(PitchClass.e.transposed(by: 12) == .e)
        #expect(PitchClass.g.transposed(by: -25) == .fSharp)
    }

    @Test func semitoneDistanceIsAlwaysUpward() {
        #expect(PitchClass.c.semitones(to: .b) == 11)
        #expect(PitchClass.b.semitones(to: .c) == 1)
        #expect(PitchClass.a.semitones(to: .a) == 0)
    }

    @Test func midiRoundTrip() {
        let middleC = Note(.c, octave: 4)
        #expect(middleC.midi == 60)
        #expect(Note(midi: 60) == middleC)
        let a4 = Note(.a, octave: 4)
        #expect(a4.midi == 69)
        #expect(abs(a4.frequency - 440.0) < 0.001)
    }

    @Test func spelling() {
        #expect(PitchClass.cSharp.name(.sharps) == "C♯")
        #expect(PitchClass.cSharp.name(.flats) == "D♭")
    }
}

@Suite("Scales")
struct ScaleTests {
    @Test func cMajorContainsOnlyNaturals() {
        let cMajor = Scale(root: .c, type: .major)
        #expect(cMajor.pitchClasses == [.c, .d, .e, .f, .g, .a, .b])
        #expect(cMajor.contains(.e))
        #expect(!cMajor.contains(.fSharp))
    }

    @Test func aMinorPentatonic() {
        let scale = Scale(root: .a, type: .minorPentatonic)
        #expect(scale.pitchClasses == [.a, .c, .d, .e, .g])
    }

    @Test func degreesAreOneBased() {
        let gMajor = Scale(root: .g, type: .major)
        #expect(gMajor.degree(of: .g) == 1)
        #expect(gMajor.degree(of: .fSharp) == 7)
        #expect(gMajor.degree(of: .f) == nil)
    }

    @Test func relativeModesShareNotes() {
        let cMajor = Scale(root: .c, type: .major)
        let dDorian = Scale(root: .d, type: .dorian)
        #expect(Set(cMajor.pitchClasses) == Set(dDorian.pitchClasses))
    }
}

@Suite("Chords")
struct ChordTests {
    @Test func basicTriads() {
        #expect(Chord(root: .c, quality: .major).pitchClasses == [.c, .e, .g])
        #expect(Chord(root: .a, quality: .minor).pitchClasses == [.a, .c, .e])
        #expect(Chord(root: .b, quality: .diminished).pitchClasses == [.b, .d, .f])
    }

    @Test func chordToneRoles() {
        let g7 = Chord(root: .g, quality: .dominant7)
        #expect(g7.tone(of: .g) == .root)
        #expect(g7.tone(of: .b) == .third)
        #expect(g7.tone(of: .d) == .fifth)
        #expect(g7.tone(of: .f) == .seventh)
        #expect(g7.tone(of: .a) == nil)
    }

    @Test func symbols() {
        #expect(Chord(root: .a, quality: .minor7).symbol == "Am7")
        #expect(Chord(root: .fSharp, quality: .diminished).symbol == "F♯°")
    }

    @Test func diatonicTriadsOfCMajor() {
        let triads = Chord.diatonicTriads(in: Scale(root: .c, type: .major))
        let qualities = triads.map(\.quality)
        #expect(qualities == [.major, .minor, .minor, .major, .major, .minor, .diminished])
        #expect(triads.map(\.root) == [.c, .d, .e, .f, .g, .a, .b])
    }
}

@Suite("Fretboard mapping")
struct FretboardModelTests {
    let board = FretboardModel(tuning: .standard, fretCount: 22)

    @Test func openStringsMatchStandardTuning() {
        #expect(board.note(at: FretPosition(string: 0, fret: 0)) == Note(.e, octave: 2))
        #expect(board.note(at: FretPosition(string: 5, fret: 0)) == Note(.e, octave: 4))
    }

    @Test func fifthFretTuningReference() {
        // Fret 5 of each string equals the next open string (except G→B, fret 4).
        for string in [0, 1, 2, 4] {
            #expect(board.note(at: FretPosition(string: string, fret: 5))
                    == board.note(at: FretPosition(string: string + 1, fret: 0)))
        }
        #expect(board.note(at: FretPosition(string: 3, fret: 4))
                == board.note(at: FretPosition(string: 4, fret: 0)))
    }

    @Test func scaleHighlightsCoverEveryStringAndDegreesAreTagged() {
        let scale = Scale(root: .a, type: .minorPentatonic)
        let highlights = board.highlights(for: scale)
        // Frets 0–22 span each pitch class twice per string when its offset from
        // the open string is ≤ 10; every A-minor-pentatonic note qualifies on
        // every standard-tuned string → 5 notes × 2 × 6 strings.
        #expect(highlights.count == 60)
        for h in highlights {
            #expect(scale.contains(h.note.pitchClass))
            guard case .scaleDegree(let d) = h.role else { Issue.record("wrong role"); return }
            #expect((1...5).contains(d))
        }
    }

    @Test func chordWithinScaleUsesChordRoleForSharedNotes() {
        let scale = Scale(root: .c, type: .major)
        let chord = Chord(root: .c, quality: .major)
        let highlights = board.highlights(for: chord, within: scale)
        for h in highlights where chord.contains(h.note.pitchClass) {
            guard case .chordTone = h.role else {
                Issue.record("chord tones must take priority over scale degrees")
                return
            }
        }
    }
}
