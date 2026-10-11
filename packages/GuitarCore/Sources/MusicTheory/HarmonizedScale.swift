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


extension HarmonizedScale {
    /// The diatonic SEVENTH chord on every degree of a seven-note scale —
    /// derived the textbook way (stack the scale in thirds, name the
    /// result): C melodic minor → Cm(maj7) Dm7 E♭maj7♯5 F7 G7 Am7♭5 Bm7♭5.
    public static func seventhChords(of scale: Scale) -> [Chord] {
        let pcs = scale.pitchClasses
        guard pcs.count == 7 else { return [] }
        return pcs.indices.map { degree in
            let root = pcs[degree]
            let intervals = [0, 2, 4, 6].map {
                root.semitones(to: pcs[(degree + $0) % 7])
            }
            return Chord(root: root, quality: Self.seventhQuality(intervals))
        }
    }

    private static func seventhQuality(_ intervals: [Int]) -> ChordQuality {
        switch intervals {
        case [0, 4, 7, 11]: return .major7
        case [0, 4, 7, 10]: return .dominant7
        case [0, 3, 7, 10]: return .minor7
        case [0, 3, 6, 10]: return .minor7b5
        case [0, 3, 6, 9]: return .diminished7
        case [0, 3, 7, 11]:
            return ChordQuality(name: "Minor-major 7", symbol: "m(maj7)",
                                intervals: [0, 3, 7, 11])
        case [0, 4, 8, 11]:
            return ChordQuality(name: "Major 7 ♯5", symbol: "maj7♯5",
                                intervals: [0, 4, 8, 11])
        case [0, 4, 8, 10]:
            return ChordQuality(name: "Dominant 7 ♯5", symbol: "7♯5",
                                intervals: [0, 4, 8, 10])
        default:
            return ChordQuality(name: "Custom", symbol: "7?",
                                intervals: intervals.sorted())
        }
    }
}
