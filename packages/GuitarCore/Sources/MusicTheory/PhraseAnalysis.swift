/// Rule-based harmonic reading of a phrase: which idioms it uses
/// (enclosure, chromatic approach, arpeggio, stepwise run) and how each
/// note relates to the chord it's tagged over. Derived, never guessed.
public enum PhraseAnalysis {
    /// Detected idioms, in playing order, deduplicated.
    public static func devices(notes: [Note], chord: Chord?) -> [String] {
        guard notes.count >= 2 else { return [] }
        var found: [String] = []
        func add(_ s: String) { if !found.contains(s) { found.append(s) } }

        let midis = notes.map(\.midi)
        let isChordTone = notes.map { chord?.contains($0.pitchClass) ?? false }
        func degree(_ i: Int) -> String {
            chord?.degreeLabel(of: notes[i].pitchClass) ?? notes[i].pitchClass.name()
        }

        for i in notes.indices {
            // Enclosure: the two previous notes straddle a landing chord tone.
            if i >= 2, isChordTone[i],
               !isChordTone[i - 1] || !isChordTone[i - 2] {
                let a = midis[i - 2] - midis[i], b = midis[i - 1] - midis[i]
                if a * b < 0, abs(a) <= 3, abs(b) <= 3 {
                    add("enclosure of the \(degree(i))")
                    continue
                }
            }
            // Chromatic approach: half step into a chord tone from outside.
            if i >= 1, isChordTone[i], !isChordTone[i - 1],
               abs(midis[i] - midis[i - 1]) == 1 {
                add("chromatic approach to the \(degree(i))")
            }
        }

        // Arpeggio: 3+ consecutive chord tones, one direction.
        var run = 1
        for i in 1..<notes.count {
            let sameDirection = i < 2
                || (midis[i] - midis[i - 1]).signum() == (midis[i - 1] - midis[max(i - 2, 0)]).signum()
            if isChordTone[i], isChordTone[i - 1], midis[i] != midis[i - 1], sameDirection {
                run += 1
                if run == 3 {
                    add(midis[i] > midis[i - 1] ? "arpeggio up" : "arpeggio down")
                }
            } else {
                run = 1
            }
        }

        // Stepwise run: 4+ notes moving by ≤2 semitones in one direction.
        var steps = 1
        for i in 1..<notes.count {
            let d = midis[i] - midis[i - 1]
            let prev = i >= 2 ? midis[i - 1] - midis[i - 2] : d
            if d != 0, abs(d) <= 2, d.signum() == prev.signum() || i < 2 {
                steps += 1
                if steps == 4 {
                    add(d > 0 ? "stepwise run up" : "stepwise run down")
                }
            } else {
                steps = 1
            }
        }

        if let chord, let last = notes.last, chord.contains(last.pitchClass) {
            add("lands on the \(degree(notes.count - 1))")
        }
        return Array(found.prefix(4))
    }

    /// "R → ♭3 → 4 → ♯4 → 5" — every note read against the chord.
    public static func degreePath(notes: [Note], chord: Chord) -> String {
        notes.map { chord.degreeLabel(of: $0.pitchClass) ?? $0.pitchClass.name() }
            .joined(separator: " → ")
    }
}

public extension Phrase {
    /// The same line slid to a new root: frets shift uniformly, folding an
    /// octave where the neck runs out; nil if any note can't fit.
    func transposed(by semitones: Int, on model: FretboardModel) -> Phrase? {
        guard semitones != 0 else { return self }
        var newSteps: [ExerciseStep] = []
        for step in steps {
            var fret = step.position.fret + semitones
            while fret < 0 { fret += 12 }
            while fret > model.fretCount { fret -= 12 }
            guard fret >= 0 else { return nil }
            let position = FretPosition(string: step.position.string, fret: fret)
            newSteps.append(ExerciseStep(position: position,
                                         note: model.note(at: position)))
        }
        var copy = self
        copy.steps = newSteps
        copy.chord = chord.map { Chord(root: $0.root.transposed(by: semitones),
                                       quality: $0.quality) }
        return copy
    }
}
