/// THE voicing walk — one ordered sequence of every real voicing of a
/// chord, sorted by neck position so "next" always means the closest grip
/// up the neck. Template shapes first-class, drop-2 on the adjacent
/// 4-string sets, drop-3 on the skipped sets, deduped. The caption names
/// what each voicing is; players never pick systems. Mirrors the web
/// engine (demoVoicings.voicingWalk) — the two must stay in step.
public struct WalkVoicing: Sendable, Hashable {
    public let voicing: Voicing
    /// What this voicing is — a caption, not a control.
    public let kind: String

    public init(voicing: Voicing, kind: String) {
        self.voicing = voicing
        self.kind = kind
    }
}

public enum VoicingWalk {
    /// Drop-3 lives on the skipped-string sets, as the books print them.
    public static let drop3Sets: [[Int]] = [[0, 2, 3, 4], [1, 3, 4, 5]]

    private static let bassNames = ["bass root", "bass 3rd", "bass 5th", "bass 7th"]

    public static func walk(
        for chord: Chord,
        on model: FretboardModel = FretboardModel(tuning: .standard)
    ) -> [WalkVoicing] {
        var items: [WalkVoicing] = []
        var seen = Set<Voicing>()
        func push(_ voicing: Voicing, _ kind: String) {
            guard seen.insert(voicing).inserted else { return }
            items.append(WalkVoicing(voicing: voicing, kind: kind))
        }

        for grip in ChordGripTemplates.grips(for: chord) {
            push(grip, "shape")
        }

        let tones = chord.quality.intervals.prefix(4).map { chord.root.transposed(by: $0) }
        if Set(tones).count == 4 {
            for (si, strings) in SeventhVoicings.stringSets.enumerated() {
                for voicing in SeventhVoicings.drop2(of: chord, strings: strings, on: model, maxSpan: 4) {
                    push(Voicing(frets: fretArray(voicing.positions)),
                         "drop-2 · \(bassNames[voicing.inversion.rawValue]) · strings \(setLabel(si, drop3: false))")
                }
            }
            let (r, t3, t5, t7) = (tones[0], tones[1], tones[2], tones[3])
            // Drop-3 orderings by bass tone (3rd-from-top dropped an octave).
            let orderings: [(Int, [PitchClass])] = [
                (0, [r, t7, t3, t5]),
                (1, [t3, r, t5, t7]),
                (2, [t5, t3, t7, r]),
                (3, [t7, t5, r, t3]),
            ]
            for (si, strings) in drop3Sets.enumerated() {
                for (inversion, ordering) in orderings {
                    if let steps = TriadVoicings.lowestVoicing(
                        of: ordering, strings: strings, on: model, maxSpan: 4) {
                        push(Voicing(frets: fretArray(steps.map(\.position))),
                             "drop-3 · \(bassNames[inversion]) · strings \(setLabel(si, drop3: true))")
                    }
                }
            }
        }

        return items.sorted { $0.voicing.neckPosition < $1.voicing.neckPosition }
    }

    private static func fretArray(_ positions: [FretPosition]) -> [Int?] {
        var frets: [Int?] = Array(repeating: nil, count: 6)
        for position in positions {
            frets[position.string] = position.fret
        }
        return frets
    }

    private static func setLabel(_ index: Int, drop3: Bool) -> String {
        drop3 ? ["6·432", "5·321"][index] : ["6–3", "5–2", "4–1"][index]
    }
}
