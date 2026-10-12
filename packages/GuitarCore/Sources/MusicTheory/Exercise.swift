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

    /// The classic interval drill: walk the scale in diatonic 3rds, 4ths,
    /// 5ths, 6ths or 7ths — degree 1 with degree 1+n, then 2 with 2+n, up
    /// the box and back down. The workhorse pattern vocabulary.
    public static func scaleInIntervals(
        scale: Scale,
        box startFret: Int,
        intervalDegrees: Int,          // 3 = thirds, 4 = fourths … 7 = sevenths
        span: Int = 5,
        on model: FretboardModel
    ) -> Exercise {
        var seenMidis = Set<Int>()
        let box = model.positionBox(for: scale, startingAt: startFret, span: span)
            .sorted { ($0.note.midi, $0.position.string) < ($1.note.midi, $1.position.string) }
            .filter { seenMidis.insert($0.note.midi).inserted } // no unison repeats
        let gap = intervalDegrees - 1
        guard box.count > gap else {
            return Exercise(name: "\(scale.name) in \(intervalDegrees)ths", steps: [])
        }
        var ascending: [ExerciseStep] = []
        for i in 0..<(box.count - gap) {
            ascending.append(ExerciseStep(position: box[i].position, note: box[i].note))
            ascending.append(ExerciseStep(position: box[i + gap].position,
                                          note: box[i + gap].note))
        }
        let descending = ascending.dropLast(2).reversed()
        let names = [3: "3rds", 4: "4ths", 5: "5ths", 6: "6ths", 7: "7ths"]
        return Exercise(
            name: "\(scale.name) in \(names[intervalDegrees] ?? "steps") — fret \(startFret)",
            steps: ascending + Array(descending)
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
