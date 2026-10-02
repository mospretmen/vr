/// A scale formula: an ordered set of semitone offsets from the root, always starting at 0.
public struct ScaleType: Codable, Sendable, Hashable {
    public let name: String
    /// Semitone offsets from the root, e.g. major = [0, 2, 4, 5, 7, 9, 11].
    public let intervals: [Int]

    public init(name: String, intervals: [Int]) {
        precondition(intervals.first == 0, "Scale intervals must start at the root (0)")
        self.name = name
        self.intervals = intervals
    }

    // MARK: - Diatonic modes
    public static let major          = ScaleType(name: "Major (Ionian)",  intervals: [0, 2, 4, 5, 7, 9, 11])
    public static let dorian         = ScaleType(name: "Dorian",          intervals: [0, 2, 3, 5, 7, 9, 10])
    public static let phrygian       = ScaleType(name: "Phrygian",        intervals: [0, 1, 3, 5, 7, 8, 10])
    public static let lydian         = ScaleType(name: "Lydian",          intervals: [0, 2, 4, 6, 7, 9, 11])
    public static let mixolydian     = ScaleType(name: "Mixolydian",      intervals: [0, 2, 4, 5, 7, 9, 10])
    public static let naturalMinor   = ScaleType(name: "Minor (Aeolian)", intervals: [0, 2, 3, 5, 7, 8, 10])
    public static let locrian        = ScaleType(name: "Locrian",         intervals: [0, 1, 3, 5, 6, 8, 10])

    // MARK: - Pentatonic & blues
    public static let majorPentatonic = ScaleType(name: "Major Pentatonic", intervals: [0, 2, 4, 7, 9])
    public static let minorPentatonic = ScaleType(name: "Minor Pentatonic", intervals: [0, 3, 5, 7, 10])
    public static let blues           = ScaleType(name: "Blues",            intervals: [0, 3, 5, 6, 7, 10])

    // MARK: - Minor variants
    public static let harmonicMinor = ScaleType(name: "Harmonic Minor", intervals: [0, 2, 3, 5, 7, 8, 11])
    public static let melodicMinor  = ScaleType(name: "Melodic Minor",  intervals: [0, 2, 3, 5, 7, 9, 11])

    // MARK: - Advanced colors
    /// 5th mode of harmonic minor — flamenco/metal staple over V chords.
    public static let phrygianDominant = ScaleType(name: "Phrygian Dominant", intervals: [0, 1, 4, 5, 7, 8, 10])
    /// 4th mode of melodic minor — the lydian ♭7 sound over dominants.
    public static let lydianDominant = ScaleType(name: "Lydian Dominant", intervals: [0, 2, 4, 6, 7, 9, 10])
    /// Mixolydian plus the chromatic passing major 7 (eight notes).
    public static let bebopDominant = ScaleType(name: "Bebop Dominant", intervals: [0, 2, 4, 5, 7, 9, 10, 11])

    /// The catalog shown in pickers, in display order.
    public static let all: [ScaleType] = [
        .major, .dorian, .phrygian, .lydian, .mixolydian, .naturalMinor, .locrian,
        .majorPentatonic, .minorPentatonic, .blues,
        .harmonicMinor, .melodicMinor,
        .phrygianDominant, .lydianDominant, .bebopDominant,
    ]
}

/// A scale rooted at a specific pitch class.
public struct Scale: Codable, Sendable, Hashable {
    public var root: PitchClass
    public var type: ScaleType

    public init(root: PitchClass, type: ScaleType) {
        self.root = root
        self.type = type
    }

    /// The pitch classes of the scale, in degree order starting from the root.
    public var pitchClasses: [PitchClass] {
        type.intervals.map { root.transposed(by: $0) }
    }

    public func contains(_ pitchClass: PitchClass) -> Bool {
        type.intervals.contains(root.semitones(to: pitchClass))
    }

    /// 1-based scale degree of `pitchClass`, or nil if it's not in the scale.
    public func degree(of pitchClass: PitchClass) -> Int? {
        type.intervals.firstIndex(of: root.semitones(to: pitchClass)).map { $0 + 1 }
    }

    public var name: String { "\(root.name()) \(type.name)" }
}
