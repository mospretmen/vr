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

    /// Spelled degree labels for a scale type, in degree order.
    public static func degreeLabels(of type: ScaleType) -> [String] {
        type.intervals.map(degreeLabel(forInterval:))
    }

    /// Spelled degree of a pitch class within a scale ("♭7"), nil if outside.
    public static func degreeLabel(of pitchClass: PitchClass, in scale: Scale) -> String? {
        guard scale.contains(pitchClass) else { return nil }
        return degreeLabel(forInterval: scale.root.semitones(to: pitchClass))
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
