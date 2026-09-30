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
        precondition(strings.count == 3, "Triad drills use exactly three strings")
        let tones = chord.quality.intervals.prefix(3).map { chord.root.transposed(by: $0) }
        guard tones.count == 3 else { return Exercise(name: chord.symbol, steps: []) }

        // Bottom-to-top pitch-class orders: root position, 1st, 2nd inversion.
        let orderings = [
            [tones[0], tones[1], tones[2]],
            [tones[1], tones[2], tones[0]],
            [tones[2], tones[0], tones[1]],
        ]

        var voicings: [[ExerciseStep]] = []
        for ordering in orderings {
            if let voicing = lowestVoicing(of: ordering, strings: strings,
                                           on: model, maxSpan: maxSpan) {
                voicings.append(voicing)
            }
        }
        // Play them in order up the neck regardless of inversion number.
        voicings.sort { ($0.map(\.position.fret).min() ?? 0) < ($1.map(\.position.fret).min() ?? 0) }

        return Exercise(
            name: "\(chord.symbol) triads — strings \(strings.map(String.init).joined(separator: "-"))",
            steps: voicings.flatMap { $0 }
        )
    }

    /// Lowest fret combination putting `pitchClasses[i]` on `strings[i]` with
    /// strictly ascending sounding pitch and a hand-sized fret spread.
    private static func lowestVoicing(
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
