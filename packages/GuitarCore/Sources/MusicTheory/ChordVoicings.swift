/// Playable chord grips and closed triad shapes on a real neck — the bridge
/// from "what chord" to "where your fingers go". Pure search over the tuning,
/// so every tuning gets voicings for free.

/// One playable grip: a fret per string (nil = muted), low string first.
public struct Voicing: Codable, Sendable, Hashable {
    public let frets: [Int?]

    public init(frets: [Int?]) { self.frets = frets }

    public var positions: [FretPosition] {
        frets.enumerated().compactMap { string, fret in
            fret.map { FretPosition(string: string, fret: $0) }
        }
    }

    /// Lowest fretted fret, 0 when the grip is all open strings.
    public var neckPosition: Int {
        frets.compactMap { $0 }.filter { $0 > 0 }.min() ?? 0
    }

    /// "Open" or "fret N", for pickers.
    public var positionLabel: String {
        neckPosition == 0 ? "Open" : "fret \(neckPosition)"
    }
}

public enum ChordVoicings {
    /// Root-position grips for a chord, ordered up the neck, at most one per
    /// neck position. Requires: contiguous sounded strings (≥4), the root in
    /// the bass, every defining tone present (the plain 5th may drop from
    /// 7th chords, as players do), and a fretting span ≤ 3.
    public static func voicings(
        for chord: Chord, tuning: Tuning = .standard, limit: Int = 6
    ) -> [Voicing] {
        let board = FretboardModel(tuning: tuning)
        let pcs = Set(chord.pitchClasses)
        let required = requiredTones(of: chord)
        let stringCount = tuning.stringCount

        var best: [Int: (score: Int, voicing: Voicing)] = [:] // by neck position
        for window in 0...10 {
            let candidates: [[Int?]] = (0..<stringCount).map { string in
                // Open strings only mix into grips near the nut.
                var options: Set<Int> = window <= 2 ? [0] : []
                for fret in window...(window + 3) where fret <= board.fretCount {
                    options.insert(fret)
                }
                var frets: [Int?] = [nil]
                for fret in options.sorted() {
                    let pc = board.note(at: FretPosition(string: string, fret: fret)).pitchClass
                    if pcs.contains(pc) { frets.append(fret) }
                }
                return frets
            }
            enumerate(candidates, upTo: stringCount) { frets in
                evaluate(frets, chord: chord, board: board,
                         pcs: pcs, required: required, into: &best)
            }
        }
        return best.keys.sorted().prefix(limit).compactMap { best[$0]?.voicing }
    }

    // MARK: - Voicing search internals

    /// Root + the quality's defining colors must sound; the plain perfect
    /// 5th may drop from 4-note chords. Altered 5ths always stay.
    private static func requiredTones(of chord: Chord) -> Set<PitchClass> {
        var required: Set<PitchClass> = []
        for (index, interval) in chord.quality.intervals.enumerated() {
            if index == 2 && interval == 7 && chord.quality.intervals.count > 3 { continue }
            required.insert(chord.root.transposed(by: interval))
        }
        return required
    }

    private static func enumerate(
        _ candidates: [[Int?]], upTo count: Int, _ body: ([Int?]) -> Void
    ) {
        var frets: [Int?] = []
        func recurse(_ string: Int) {
            if string == count { body(frets); return }
            for fret in candidates[string] {
                frets.append(fret)
                recurse(string + 1)
                frets.removeLast()
            }
        }
        recurse(0)
    }

    private static func evaluate(
        _ frets: [Int?], chord: Chord, board: FretboardModel,
        pcs: Set<PitchClass>, required: Set<PitchClass>,
        into best: inout [Int: (score: Int, voicing: Voicing)]
    ) {
        let sounded = frets.enumerated().compactMap { string, fret in
            fret.map { FretPosition(string: string, fret: $0) }
        }
        guard sounded.count >= 4 else { return }
        // Sounded strings must be one contiguous block (no interior mutes).
        let strings = sounded.map(\.string)
        guard strings.last! - strings.first! == strings.count - 1 else { return }
        // Root in the bass.
        guard board.note(at: sounded[0]).pitchClass == chord.root else { return }
        // Every defining tone present.
        let covered = Set(sounded.map { board.note(at: $0).pitchClass })
        guard covered.isSuperset(of: required) else { return }
        // Fretting-hand span ≤ 3 frets.
        let fretted = sounded.map(\.fret).filter { $0 > 0 }
        let span = fretted.isEmpty ? 0 : fretted.max()! - fretted.min()!
        guard span <= 3 else { return }

        let voicing = Voicing(frets: frets)
        let missingColor = pcs.subtracting(covered).count
        let score = missingColor * 10 - sounded.count * 2 + span
        let position = voicing.neckPosition
        if let current = best[position], current.score <= score { return }
        best[position] = (score, voicing)
    }
}
