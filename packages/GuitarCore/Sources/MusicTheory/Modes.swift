/// Mode relationships and spelled scale degrees — the vocabulary players
/// actually learn modes with ("Dorian is minor with a natural 6",
/// "A Dorian lives inside G major"). All derived, nothing stored, so the
/// wire format and existing equality are untouched.
public enum Modes {
    /// Canonical label for a semitone offset from the root, major-scale
    /// degrees unmarked and alterations spelled flat-side (♭5 over ♯4,
    /// matching common practice for scale charts).
    public static func degreeLabel(forInterval interval: Int) -> String {
        let table = ["1", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♭6", "6", "♭7", "7"]
        return table[((interval % 12) + 12) % 12]
    }

    /// Spelled degree labels for a scale type, in degree order. Seven-note
    /// scales label by DEGREE POSITION — Lydian's tritone is ♯4 (a raised
    /// fourth degree), Locrian's is ♭5 — so the numeral always matches the
    /// letter the note is spelled with. Other sizes keep the interval table.
    public static func degreeLabels(of type: ScaleType) -> [String] {
        guard type.intervals.count == 7 else {
            return type.intervals.map(degreeLabel(forInterval:))
        }
        let majorDegrees = [0, 2, 4, 5, 7, 9, 11]
        return type.intervals.enumerated().map { index, interval in
            var diff = interval - majorDegrees[index]
            if diff > 6 { diff -= 12 }
            if diff < -6 { diff += 12 }
            let accidental: String
            switch diff {
            case -2: accidental = "𝄫"
            case -1: accidental = "♭"
            case 1: accidental = "♯"
            case 2: accidental = "𝄪"
            default: accidental = ""
            }
            return accidental + String(index + 1)
        }
    }

    /// Spelled degree of a pitch class within a scale ("♭7"), nil if outside.
    public static func degreeLabel(of pitchClass: PitchClass, in scale: Scale) -> String? {
        let distance = scale.root.semitones(to: pitchClass)
        guard let index = scale.type.intervals.firstIndex(of: distance) else { return nil }
        return degreeLabels(of: scale.type)[index]
    }

    /// The alterations relative to the major scale, e.g. Dorian → ["♭3", "♭7"].
    /// Empty for major itself; for non-seven-note scales it lists whatever
    /// flat/sharp degrees appear.
    public static func alterations(of type: ScaleType) -> [String] {
        degreeLabels(of: type).filter { $0.count > 1 }
    }

    /// If `type` is a mode of the major scale, its 1-based degree
    /// (Ionian 1, Dorian 2 … Locrian 7); nil for non-diatonic scales.
    public static func majorDegree(of type: ScaleType) -> Int? {
        let major = ScaleType.major.intervals
        guard type.intervals.count == 7 else { return nil }
        for rotation in 0..<7 {
            let start = major[rotation]
            let rotated = (0..<7).map { (major[(rotation + $0) % 7] - start + 12) % 12 }
            if rotated == type.intervals { return rotation + 1 }
        }
        return nil
    }

    /// The major scale containing this scale, when it is a diatonic mode:
    /// A Dorian → G major, E Phrygian → C major. nil otherwise.
    public static func parentMajor(of scale: Scale) -> Scale? {
        guard let degree = majorDegree(of: scale.type) else { return nil }
        let offset = ScaleType.major.intervals[degree - 1]
        return Scale(root: scale.root.transposed(by: -offset), type: .major)
    }

    /// One-line study summary: "2nd mode of G Major (Ionian) · ♭3 ♭7".
    public static func summary(of scale: Scale) -> String? {
        guard let degree = majorDegree(of: scale.type), degree != 1,
              let parent = parentMajor(of: scale) else { return nil }
        let ordinals = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th"]
        var line = "\(ordinals[degree - 1]) mode of \(parent.name)"
        let altered = alterations(of: scale.type)
        if !altered.isEmpty {
            line += " · " + altered.joined(separator: " ")
        }
        return line
    }
}


extension Modes {
    /// Canonical names for seven-note interval patterns — the modes of
    /// major, melodic minor, and harmonic minor, as the literature names
    /// them. Keys are intervals-from-root.
    private static let modeCatalog: [[Int]: String] = [
        [0, 2, 4, 5, 7, 9, 11]: "Ionian",
        [0, 2, 3, 5, 7, 9, 10]: "Dorian",
        [0, 1, 3, 5, 7, 8, 10]: "Phrygian",
        [0, 2, 4, 6, 7, 9, 11]: "Lydian",
        [0, 2, 4, 5, 7, 9, 10]: "Mixolydian",
        [0, 2, 3, 5, 7, 8, 10]: "Aeolian",
        [0, 1, 3, 5, 6, 8, 10]: "Locrian",
        [0, 2, 3, 5, 7, 9, 11]: "Melodic minor",
        [0, 1, 3, 5, 7, 9, 10]: "Dorian ♭2",
        [0, 2, 4, 6, 8, 9, 11]: "Lydian augmented",
        [0, 2, 4, 6, 7, 9, 10]: "Lydian dominant",
        [0, 2, 4, 5, 7, 8, 10]: "Mixolydian ♭6",
        [0, 2, 3, 5, 6, 8, 10]: "Locrian ♮2",
        [0, 1, 3, 4, 6, 8, 10]: "Altered",
        [0, 2, 3, 5, 7, 8, 11]: "Harmonic minor",
        [0, 1, 3, 5, 6, 9, 10]: "Locrian ♮6",
        [0, 2, 4, 5, 8, 9, 11]: "Ionian ♯5",
        [0, 2, 3, 6, 7, 9, 10]: "Dorian ♯4",
        [0, 1, 4, 5, 7, 8, 10]: "Phrygian dominant",
        [0, 3, 4, 6, 7, 9, 11]: "Lydian ♯2",
        [0, 1, 3, 4, 6, 8, 9]: "Super Locrian 𝄫7",
    ]

    /// The mode living on each degree of a seven-note scale — degree 2 of
    /// major is Dorian, degree 4 of melodic minor is Lydian dominant.
    /// nil per degree when the rotation has no standard name.
    public static func degreeModeNames(of type: ScaleType) -> [String?] {
        guard type.intervals.count == 7 else { return [] }
        return type.intervals.indices.map { degree in
            let start = type.intervals[degree]
            let rotated = (0..<7)
                .map { (type.intervals[(degree + $0) % 7] - start + 12) % 12 }
            return modeCatalog[rotated]
        }
    }
}
