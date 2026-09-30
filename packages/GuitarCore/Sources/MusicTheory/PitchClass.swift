import Foundation

/// One of the twelve pitch classes, independent of octave.
public enum PitchClass: Int, CaseIterable, Codable, Sendable, Hashable {
    case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

    /// Preferred display style when a pitch class has two common names.
    public enum Spelling: Sendable {
        case sharps, flats
    }

    public func name(_ spelling: Spelling = .sharps) -> String {
        switch spelling {
        case .sharps:
            return ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][rawValue]
        case .flats:
            return ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"][rawValue]
        }
    }

    /// The pitch class `semitones` above this one (negative values move down).
    public func transposed(by semitones: Int) -> PitchClass {
        PitchClass(rawValue: ((rawValue + semitones) % 12 + 12) % 12)!
    }

    /// Semitones from this pitch class up to `other` (0...11).
    public func semitones(to other: PitchClass) -> Int {
        ((other.rawValue - rawValue) % 12 + 12) % 12
    }
}

/// A concrete pitch: pitch class plus octave (scientific pitch notation, C4 = middle C).
public struct Note: Codable, Sendable, Hashable, Comparable {
    public var pitchClass: PitchClass
    public var octave: Int

    public init(_ pitchClass: PitchClass, octave: Int) {
        self.pitchClass = pitchClass
        self.octave = octave
    }

    /// MIDI note number (C4 = 60, A4 = 69).
    public var midi: Int { (octave + 1) * 12 + pitchClass.rawValue }

    public init(midi: Int) {
        self.pitchClass = PitchClass(rawValue: ((midi % 12) + 12) % 12)!
        self.octave = midi / 12 - 1
    }

    /// Frequency in Hz, A4 = 440.
    public var frequency: Double {
        440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }

    public func transposed(by semitones: Int) -> Note {
        Note(midi: midi + semitones)
    }

    public static func < (lhs: Note, rhs: Note) -> Bool { lhs.midi < rhs.midi }

    public func name(_ spelling: PitchClass.Spelling = .sharps) -> String {
        "\(pitchClass.name(spelling))\(octave)"
    }
}
