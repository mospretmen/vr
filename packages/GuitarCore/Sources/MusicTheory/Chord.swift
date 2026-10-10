/// A chord formula: semitone offsets from the root.
public struct ChordQuality: Codable, Sendable, Hashable {
    public let name: String
    /// Short suffix for chord symbols, e.g. "m7" in "Am7".
    public let symbol: String
    public let intervals: [Int]

    public init(name: String, symbol: String, intervals: [Int]) {
        precondition(intervals.first == 0, "Chord intervals must start at the root (0)")
        self.name = name
        self.symbol = symbol
        self.intervals = intervals
    }

    // MARK: - Triads
    public static let major      = ChordQuality(name: "Major",      symbol: "",    intervals: [0, 4, 7])
    public static let minor      = ChordQuality(name: "Minor",      symbol: "m",   intervals: [0, 3, 7])
    public static let diminished = ChordQuality(name: "Diminished", symbol: "°",   intervals: [0, 3, 6])
    public static let augmented  = ChordQuality(name: "Augmented",  symbol: "+",   intervals: [0, 4, 8])
    public static let sus2       = ChordQuality(name: "Sus2",       symbol: "sus2", intervals: [0, 2, 7])
    public static let sus4       = ChordQuality(name: "Sus4",       symbol: "sus4", intervals: [0, 5, 7])

    // MARK: - Sevenths
    public static let major7     = ChordQuality(name: "Major 7",         symbol: "maj7", intervals: [0, 4, 7, 11])
    public static let dominant7  = ChordQuality(name: "Dominant 7",      symbol: "7",    intervals: [0, 4, 7, 10])
    public static let minor7     = ChordQuality(name: "Minor 7",         symbol: "m7",   intervals: [0, 3, 7, 10])
    public static let minor7b5   = ChordQuality(name: "Half-diminished", symbol: "m7♭5", intervals: [0, 3, 6, 10])
    public static let diminished7 = ChordQuality(name: "Diminished 7",   symbol: "°7",   intervals: [0, 3, 6, 9])

    public static let all: [ChordQuality] = [
        .major, .minor, .diminished, .augmented, .sus2, .sus4,
        .major7, .dominant7, .minor7, .minor7b5, .diminished7,
    ]
}

/// A chord rooted at a specific pitch class.
public struct Chord: Codable, Sendable, Hashable {
    public var root: PitchClass
    public var quality: ChordQuality

    public init(root: PitchClass, quality: ChordQuality) {
        self.root = root
        self.quality = quality
    }

    public var pitchClasses: [PitchClass] {
        quality.intervals.map { root.transposed(by: $0) }
    }

    public func contains(_ pitchClass: PitchClass) -> Bool {
        quality.intervals.contains(root.semitones(to: pitchClass))
    }

    /// The chord tone role of `pitchClass` within this chord (root, third, fifth, seventh…), or nil.
    /// Roles classify by interval VALUE, not stack position, so chords
    /// without a 5th (7♯9…) and extended tensions all land correctly.
    public func tone(of pitchClass: PitchClass) -> ChordTone? {
        guard let interval = matchedInterval(of: pitchClass) else { return nil }
        switch interval {
        case 0: return .root
        case 2...5: return .third      // sus2/♭3/3/sus4
        case 6...8: return .fifth      // ♭5/5/♯5
        case 9...11: return .seventh   // 6 or ♭♭7/♭7/7
        default: return .extended      // 9ths, 11ths, 13ths
        }
    }

    /// The quality's interval that sounds this pitch class (extended
    /// intervals above the octave match by pitch class), or nil.
    private func matchedInterval(of pitchClass: PitchClass) -> Int? {
        let distance = root.semitones(to: pitchClass)
        return quality.intervals.first { ($0 % 12 + 12) % 12 == distance }
    }

    /// The spelled degree of `pitchClass` within this chord — the label a
    /// chord book prints: R, ♭3, 3, ♭5, 5, ♯5, 6, ♭♭7, ♭7, 7, ♭9, 9, ♯9,
    /// 11, ♯11, ♭13, 13 — or nil if the pitch class isn't a chord tone.
    public func degreeLabel(of pitchClass: PitchClass) -> String? {
        guard let interval = matchedInterval(of: pitchClass) else { return nil }
        switch interval {
        case 0: return "R"
        case 2: return "2"
        case 3: return "♭3"
        case 4: return "3"
        case 5: return "4"
        case 6: return "♭5"
        case 7: return "5"
        case 8: return "♯5"
        case 9: return quality.intervals.contains(6) ? "♭♭7" : "6"
        case 10: return "♭7"
        case 11: return "7"
        case 13: return "♭9"
        case 14: return "9"
        case 15: return "♯9"
        case 17: return "11"
        case 18: return "♯11"
        case 20: return "♭13"
        case 21: return "13"
        default: return nil
        }
    }

    /// Chord symbol, e.g. "Am7", "F♯°".
    public var symbol: String { "\(root.name())\(quality.symbol)" }

    /// Chord symbol with an explicit spelling, e.g. "B♭" vs "A♯".
    public func symbol(_ spelling: PitchClass.Spelling) -> String {
        "\(root.name(spelling))\(quality.symbol)"
    }

    /// The diatonic triads of a scale (one per scale degree), for progressions and exercises.
    public static func diatonicTriads(in scale: Scale) -> [Chord] {
        let pcs = scale.pitchClasses
        guard pcs.count >= 5 else { return [] }
        return pcs.indices.map { i in
            let root = pcs[i]
            let third = pcs[(i + 2) % pcs.count]
            let fifth = pcs[(i + 4) % pcs.count]
            let thirdInterval = root.semitones(to: third)
            let fifthInterval = root.semitones(to: fifth)
            let quality: ChordQuality = switch (thirdInterval, fifthInterval) {
            case (4, 7): .major
            case (3, 7): .minor
            case (3, 6): .diminished
            case (4, 8): .augmented
            default: ChordQuality(name: "Custom", symbol: "?", intervals: [0, thirdInterval, fifthInterval])
            }
            return Chord(root: root, quality: quality)
        }
    }
}

/// Position of a note within a chord, used to drive per-tone coloring in the overlay.
public enum ChordTone: Int, Codable, Sendable, Hashable {
    case root = 0, third, fifth, seventh, extended

    init(index: Int) {
        self = ChordTone(rawValue: min(index, ChordTone.extended.rawValue)) ?? .extended
    }
}
