/// Drop-2 seventh-chord voicings: the workhorse four-note shapes of jazz
/// and R&B comping. A drop-2 voicing takes a close-position inversion and
/// drops its second-highest voice an octave, which lands every inversion
/// neatly on four adjacent strings.
public struct SeventhVoicing: Codable, Sendable, Hashable {
    /// Named by the chord tone in the bass (how players name voicings):
    /// root position has the root in the bass, 1st inversion the third, etc.
    public enum Inversion: Int, Codable, Sendable, CaseIterable, Identifiable {
        case root = 0, first, second, third

        public var id: Int { rawValue }

        public var label: String {
            switch self {
            case .root: "Root position"
            case .first: "1st inversion"
            case .second: "2nd inversion"
            case .third: "3rd inversion"
            }
        }

        public var bassTone: ChordTone {
            switch self {
            case .root: .root
            case .first: .third
            case .second: .fifth
            case .third: .seventh
            }
        }
    }

    public let chord: Chord
    public let inversion: Inversion
    /// Bottom-to-top (ascending pitch), one step per string.
    public let steps: [ExerciseStep]

    public init(chord: Chord, inversion: Inversion, steps: [ExerciseStep]) {
        self.chord = chord
        self.inversion = inversion
        self.steps = steps
    }

    public var positions: [FretPosition] { steps.map(\.position) }
    public var lowestFret: Int { steps.map(\.position.fret).min() ?? 0 }
}

public enum SeventhVoicings {
    /// The canonical 4-string sets, low to high.
    public static let stringSets: [[Int]] = [[0, 1, 2, 3], [1, 2, 3, 4], [2, 3, 4, 5]]

    /// All four drop-2 inversions of a seventh chord on a 4-string set,
    /// each at its lowest playable spot, ordered up the neck. Returns []
    /// for qualities without four distinct tones (triads).
    public static func drop2(
        of chord: Chord,
        strings: [Int],
        on model: FretboardModel,
        maxSpan: Int = 5
    ) -> [SeventhVoicing] {
        precondition(strings.count == 4, "Drop-2 voicings use exactly four strings")
        let tones = chord.quality.intervals.prefix(4).map { chord.root.transposed(by: $0) }
        guard Set(tones).count == 4 else { return [] }
        let (r, t3, t5, t7) = (tones[0], tones[1], tones[2], tones[3])

        // Each close-position inversion with its 2nd-highest voice dropped
        // an octave into the bass, labeled by the resulting bass tone:
        //   close 5-7-1-3 → drop the 1 → 1-5-7-3  (root in bass)
        //   close 7-1-3-5 → drop the 3 → 3-7-1-5  (3rd in bass)
        //   close 1-3-5-7 → drop the 5 → 5-1-3-7  (5th in bass)
        //   close 3-5-7-1 → drop the 7 → 7-3-5-1  (7th in bass)
        let orderings: [(SeventhVoicing.Inversion, [PitchClass])] = [
            (.root,   [r,  t5, t7, t3]),
            (.first,  [t3, t7, r,  t5]),
            (.second, [t5, r,  t3, t7]),
            (.third,  [t7, t3, t5, r]),
        ]

        var voicings: [SeventhVoicing] = []
        for (inversion, ordering) in orderings {
            if let steps = TriadVoicings.lowestVoicing(
                of: ordering, strings: strings, on: model, maxSpan: maxSpan) {
                voicings.append(SeventhVoicing(chord: chord, inversion: inversion, steps: steps))
            }
        }
        return voicings.sorted { $0.lowestFret < $1.lowestFret }
    }
}
