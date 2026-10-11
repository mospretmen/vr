/// Barry Harris's 6th-diminished system: an eight-note scale whose
/// harmonization alternates the 6 chord and the diminished on the 7th —
/// C6 · B°7 · C6/E · B°7/D · … — turning a static chord into MOVEMENT.
public enum SixthDiminished {
    /// The major (or minor) 6th-diminished scale: the 6 chord's scale plus
    /// the ♭6 passing tone, eight notes.
    public static func scale(root: PitchClass, minor: Bool = false) -> [PitchClass] {
        let intervals = minor ? [0, 2, 3, 5, 7, 8, 9, 11]
                              : [0, 2, 4, 5, 7, 8, 9, 11]
        return intervals.map { root.transposed(by: $0) }
    }

    /// One rung of the ladder: which chord sounds, over which bass.
    public struct Step: Sendable, Hashable {
        public let chord: Chord
        public let bass: PitchClass
        /// Even steps are the 6 chord, odd steps the diminished.
        public let isDiminished: Bool
    }

    /// The full eight-rung ladder up one octave: basses walk the scale,
    /// chords alternate 6 ↔ °7. Playing it IS the Barry Harris movement.
    public static func ladder(root: PitchClass, minor: Bool = false) -> [Step] {
        let six = Chord(root: root,
                        quality: minor
                            ? ChordQuality(name: "m6", symbol: "m6", intervals: [0, 3, 7, 9])
                            : ChordQuality(name: "6", symbol: "6", intervals: [0, 4, 7, 9]))
        let dim = Chord(root: root.transposed(by: 11), quality: .diminished7)
        return scale(root: root, minor: minor).enumerated().map { index, bass in
            Step(chord: index.isMultiple(of: 2) ? six : dim,
                 bass: bass,
                 isDiminished: !index.isMultiple(of: 2))
        }
    }
}
