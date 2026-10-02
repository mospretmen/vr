/// One target in an exercise: play this position, hear this note.
public struct ExerciseStep: Codable, Sendable, Hashable {
    public let position: FretPosition
    public let note: Note

    public init(position: FretPosition, note: Note) {
        self.position = position
        self.note = note
    }
}

/// An ordered drill the overlay walks through step by step. Steps may repeat
/// positions (e.g. the turnaround of an up-and-down scale run).
public struct Exercise: Codable, Sendable, Hashable {
    public let name: String
    public let steps: [ExerciseStep]

    public init(name: String, steps: [ExerciseStep]) {
        self.name = name
        self.steps = steps
    }
}

public enum ExerciseGenerator {
    /// Ascending-then-descending run through a scale position box, ordered
    /// low string/low fret → high, then back down (turnaround note not doubled).
    public static func scaleRun(
        scale: Scale,
        box startFret: Int,
        span: Int = 5,
        on model: FretboardModel
    ) -> Exercise {
        let ascending = model.positionBox(for: scale, startingAt: startFret, span: span)
            .map { ExerciseStep(position: $0.position, note: $0.note) }
            .sorted { ($0.position.string, $0.position.fret) < ($1.position.string, $1.position.fret) }
        let descending = ascending.dropLast().reversed()
        return Exercise(
            name: "\(scale.name) run — box at fret \(startFret)",
            steps: ascending + descending
        )
    }

    /// The three triad inversions of a chord on a set of three adjacent
    /// strings, each voiced at its lowest playable spot, ordered up the neck.
    /// The classic "triads across the neck" drill.
    public static func triadInversions(
        chord: Chord,
        strings: [Int],
        on model: FretboardModel,
        maxSpan: Int = 4
    ) -> Exercise {
        let voicings = TriadVoicings.inversions(of: chord, strings: strings,
                                                on: model, maxSpan: maxSpan)
        return Exercise(
            name: "\(chord.symbol) triads — strings \(strings.map(String.init).joined(separator: "-"))",
            steps: voicings.flatMap(\.steps)
        )
    }

    /// Three-notes-per-string pattern: 18 consecutive scale tones laid out
    /// three to a string, starting from the first scale tone at or above
    /// `startFret` on the lowest string. The modern-technique counterpart to
    /// position boxes — wider stretches, symmetric picking.
    public static func threeNotesPerString(
        scale: Scale,
        startingAt startFret: Int,
        on model: FretboardModel
    ) -> Exercise? {
        let lowString = model.tuning.openStrings[0]

        // First scale tone on the low string at or above startFret.
        guard let firstFret = (startFret...model.fretCount).first(where: {
            scale.contains(lowString.transposed(by: $0).pitchClass)
        }) else { return nil }

        // Stream of consecutive ascending scale tones from that note.
        var tones: [Note] = [lowString.transposed(by: firstFret)]
        while tones.count < model.tuning.stringCount * 3 {
            var next = tones.last!.transposed(by: 1)
            while !scale.contains(next.pitchClass) {
                next = next.transposed(by: 1)
            }
            tones.append(next)
        }

        var steps: [ExerciseStep] = []
        for (index, note) in tones.enumerated() {
            let string = index / 3
            let fret = note.midi - model.tuning.openStrings[string].midi
            guard fret >= 0, fret <= model.fretCount else { return nil }
            steps.append(ExerciseStep(position: FretPosition(string: string, fret: fret),
                                      note: note))
        }
        let descending = steps.dropLast().reversed()
        return Exercise(
            name: "\(scale.name) 3NPS — fret \(firstFret)",
            steps: steps + descending
        )
    }

}
