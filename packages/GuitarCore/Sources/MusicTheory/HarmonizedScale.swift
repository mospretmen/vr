/// Harmonizing a scale up one string set: each scale degree's diatonic
/// triad, voiced so the ladder climbs the neck without jumping back down.
/// The classic "triads up the neck in C" study that welds scale knowledge
/// to chord shapes.
public struct HarmonizedTriad: Codable, Sendable, Hashable {
    /// 1-based scale degree.
    public let degree: Int
    public let chord: Chord
    public let voicing: TriadVoicing

    public init(degree: Int, chord: Chord, voicing: TriadVoicing) {
        self.degree = degree
        self.chord = chord
        self.voicing = voicing
    }

    /// Case-styled roman numeral: I, ii, vii°, III+ …
    public var romanNumeral: String {
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII"]
        guard (1...7).contains(degree) else { return "?" }
        let base = numerals[degree - 1]
        switch chord.quality {
        case .minor: return base.lowercased()
        case .diminished: return base.lowercased() + "°"
        case .augmented: return base + "+"
        default: return base
        }
    }
}

public enum HarmonizedScale {
    /// The triad ladder for a scale on a 3-string set: walks degrees in
    /// order, choosing for each the lowest voicing at or above the current
    /// neck position, so the sequence never retreats. Seven-note scales
    /// produce seven rungs; scales with too few notes return [].
    public static func triadLadder(
        of scale: Scale,
        strings: [Int],
        on model: FretboardModel
    ) -> [HarmonizedTriad] {
        let triads = Chord.diatonicTriads(in: scale)
        guard triads.count == 7 else { return [] }

        var ladder: [HarmonizedTriad] = []
        var position = 0
        for (index, chord) in triads.enumerated() {
            let voicings = TriadVoicings.inversions(of: chord, strings: strings, on: model)
            guard let voicing = voicings.first(where: { $0.lowestFret >= position })
                    ?? voicings.last else { continue }
            ladder.append(HarmonizedTriad(degree: index + 1, chord: chord, voicing: voicing))
            position = voicing.lowestFret
        }
        return ladder
    }
}
