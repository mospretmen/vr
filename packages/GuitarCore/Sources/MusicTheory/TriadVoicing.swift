/// A concrete triad voicing: one inversion of a chord played on a specific
/// set of three adjacent strings, with exact fret positions. The unit of
/// study for "triads across the neck" — the overlay renders these as
/// connected shapes, exercises step through them, and the chart labels them.
public struct TriadVoicing: Codable, Sendable, Hashable {
    public enum Inversion: Int, Codable, Sendable, CaseIterable, Identifiable {
        case root = 0, first, second

        public var id: Int { rawValue }

        public var label: String {
            switch self {
            case .root: "Root position"
            case .first: "1st inversion"
            case .second: "2nd inversion"
            }
        }

        /// The chord tone sounding at the bottom of the voicing.
        public var bassTone: ChordTone {
            switch self {
            case .root: .root
            case .first: .third
            case .second: .fifth
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

public enum TriadVoicings {
    /// The canonical 3-string sets, low to high (0 = lowest-pitched string).
    public static let stringSets: [[Int]] = [[0, 1, 2], [1, 2, 3], [2, 3, 4], [3, 4, 5]]

    /// All three inversions of a triad on a string set, each voiced at its
    /// lowest playable spot, ordered up the neck. Qualities with fewer than
    /// three distinct tones (power-chord-ish input) return [].
    public static func inversions(
        of chord: Chord,
        strings: [Int],
        on model: FretboardModel,
        maxSpan: Int = 4
    ) -> [TriadVoicing] {
        precondition(strings.count == 3, "Triad voicings use exactly three strings")
        let tones = chord.quality.intervals.prefix(3).map { chord.root.transposed(by: $0) }
        guard Set(tones).count == 3 else { return [] }

        // Bottom-to-top pitch-class orders per inversion.
        let orderings: [(TriadVoicing.Inversion, [PitchClass])] = [
            (.root, [tones[0], tones[1], tones[2]]),
            (.first, [tones[1], tones[2], tones[0]]),
            (.second, [tones[2], tones[0], tones[1]]),
        ]

        var voicings: [TriadVoicing] = []
        for (inversion, ordering) in orderings {
            if let steps = lowestVoicing(of: ordering, strings: strings,
                                         on: model, maxSpan: maxSpan) {
                voicings.append(TriadVoicing(chord: chord, inversion: inversion, steps: steps))
            }
        }
        return voicings.sorted { $0.lowestFret < $1.lowestFret }
    }

    /// Lowest fret combination putting `pitchClasses[i]` on `strings[i]` with
    /// strictly ascending sounding pitch and a hand-sized fret spread.
    static func lowestVoicing(
        of pitchClasses: [PitchClass],
        strings: [Int],
        on model: FretboardModel,
        maxSpan: Int
    ) -> [ExerciseStep]? {
        func candidateFrets(_ pc: PitchClass, string: Int) -> [Int] {
            (0...model.fretCount).filter {
                model.note(at: FretPosition(string: string, fret: $0)).pitchClass == pc
            }
        }
        let candidates = zip(pitchClasses, strings).map { candidateFrets($0, string: $1) }

        var best: [ExerciseStep]? = nil
        var bestKey = (Int.max, Int.max) // (lowest fret of voicing, spread)
        for f0 in candidates[0] {
            for f1 in candidates[1] {
                for f2 in candidates[2] {
                    let frets = [f0, f1, f2]
                    let fretted = frets.filter { $0 > 0 }
                    let spread = fretted.isEmpty ? 0 : fretted.max()! - fretted.min()! + 1
                    guard spread <= maxSpan else { continue }

                    let steps = zip(frets, strings).map { fret, string in
                        let position = FretPosition(string: string, fret: fret)
                        return ExerciseStep(position: position, note: model.note(at: position))
                    }
                    guard steps[0].note < steps[1].note, steps[1].note < steps[2].note else { continue }

                    let key = (frets.min()!, spread)
                    if key < bestKey {
                        bestKey = key
                        best = steps
                    }
                }
            }
        }
        return best
    }
}
