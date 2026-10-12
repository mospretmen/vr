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
        for chord: Chord, tuning: Tuning = .standard, limit: Int = 6,
        bass: ChordTone = .root
    ) -> [Voicing] {
        let board = FretboardModel(tuning: tuning)
        let pcs = Set(chord.pitchClasses)
        let required = requiredTones(of: chord)
        let intervals = chord.quality.intervals
        let bassIndex = min(bass.rawValue, intervals.count - 1)
        let bassPC = chord.root.transposed(by: intervals[bassIndex])
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
                evaluate(frets, chord: chord, board: board, bassPC: bassPC,
                         pcs: pcs, required: required, into: &best)
            }
        }
        // Published template shapes lead — they ARE how guitarists play
        // these chords. The generative search fills neck positions no
        // template covers (and is the only source for inversions and
        // non-standard tunings).
        var grips = bass == .root ? ChordGripTemplates.grips(for: chord, tuning: tuning) : []
        let templatePositions = Set(grips.map(\.neckPosition))
        let generated = best.values
            .filter { !templatePositions.contains($0.voicing.neckPosition) }
            .sorted { ($0.score, $1.voicing.neckPosition) < ($1.score, $0.voicing.neckPosition) }
            .map(\.voicing)
        grips.append(contentsOf: generated)
        var seen = Set<Voicing>()
        grips = grips.filter { seen.insert($0).inserted }
        // Order along the neck; template shapes outrank generated ties.
        let templateSet = Set(ChordGripTemplates.grips(for: chord, tuning: tuning))
        grips.sort {
            ($0.neckPosition, templateSet.contains($0) ? 0 : 1)
                < ($1.neckPosition, templateSet.contains($1) ? 0 : 1)
        }
        return Array(grips.prefix(limit))
    }

    /// Shell voicings for seventh chords: root + the two guide tones (3rd
    /// and 7th), nothing else — the jazz comper's skeleton. Both classic
    /// layouts per bass string: R–7–3 (7th closer to the root) and R–3–7.
    public static func shells(
        for chord: Chord, tuning: Tuning = .standard, maxFret: Int = 12
    ) -> [Voicing] {
        guard chord.quality.intervals.count >= 4 else { return [] }
        let board = FretboardModel(tuning: tuning)
        let third = chord.root.transposed(by: chord.quality.intervals[1])
        let seventh = chord.root.transposed(by: chord.quality.intervals[3])
        let stringCount = tuning.stringCount

        var shells: [Voicing] = []
        for bass in 0...2 {   // root on the 6th, 5th, or 4th string
            for rootFret in 0...(maxFret + 2) {
                let rootPos = FretPosition(string: bass, fret: rootFret)
                guard board.note(at: rootPos).pitchClass == chord.root else { continue }
                // Skip strings: guide tones sit on bass+2 and bass+3.
                for upper in [[seventh, third], [third, seventh]] {
                    var frets = [Int?](repeating: nil, count: stringCount)
                    frets[bass] = rootFret
                    var ok = true
                    for (offset, pc) in zip([2, 3], upper) {
                        let string = bass + offset
                        guard string < stringCount,
                              let fret = (0...(maxFret + 3)).first(where: { f in
                                  board.note(at: FretPosition(string: string, fret: f))
                                      .pitchClass == pc && abs(f - rootFret) <= 3
                              }) else { ok = false; break }
                        frets[string] = fret
                    }
                    if ok { shells.append(Voicing(frets: frets)) }
                }
            }
        }
        // Dedupe and keep them ordered up the neck.
        var seen = Set<Voicing>()
        return shells.filter { seen.insert($0).inserted }
                     .sorted { $0.neckPosition < $1.neckPosition }
    }

    /// Two-note voicings of a chosen pair of chord tones, walked across
    /// the neck — R·3, R·6, the 3·7 guide-tone dyad, and friends. The
    /// first tone is the bass.
    public static func dyads(
        for chord: Chord, toneIndices: (Int, Int),
        tuning: Tuning = .standard, maxFret: Int = 14
    ) -> [Voicing] {
        let board = FretboardModel(tuning: tuning)
        let intervals = chord.quality.intervals
        guard toneIndices.0 < intervals.count, toneIndices.1 < intervals.count
        else { return [] }
        let lowPC = chord.root.transposed(by: intervals[toneIndices.0])
        let highPC = chord.root.transposed(by: intervals[toneIndices.1])
        let stringCount = tuning.stringCount

        var out: [Voicing] = []
        for bass in 0..<(stringCount - 1) {
            for fret in 0...maxFret {
                let bassPos = FretPosition(string: bass, fret: fret)
                guard board.note(at: bassPos).pitchClass == lowPC else { continue }
                let bassMidi = board.note(at: bassPos).midi
                for offset in 1...2 where bass + offset < stringCount {
                    let string = bass + offset
                    guard let partner = (0...maxFret).first(where: { f in
                        let note = board.note(at: FretPosition(string: string, fret: f))
                        return note.pitchClass == highPC && note.midi > bassMidi
                            && abs(f - fret) <= 4
                    }) else { continue }
                    var frets = [Int?](repeating: nil, count: stringCount)
                    frets[bass] = fret
                    frets[string] = partner
                    out.append(Voicing(frets: frets))
                }
            }
        }
        var seen = Set<Voicing>()
        return out.filter { seen.insert($0).inserted }
                  .sorted { $0.neckPosition < $1.neckPosition }
                  .prefix(10).map { $0 }
    }

    // MARK: - Voicing search internals

    /// Root + the quality's defining colors must sound. The plain perfect
    /// 5th may drop from 4+ note chords (altered 5ths always stay), and on
    /// extended chords (9/11/13) the inner extensions are optional too —
    /// a grip keeps root, 3rd, 7th, and the named top color, as players do.
    private static func requiredTones(of chord: Chord) -> Set<PitchClass> {
        let intervals = chord.quality.intervals
        var keep: Set<Int>
        if intervals.count <= 3 {
            keep = Set(intervals.indices)
        } else {
            keep = [0, 1, 3, intervals.count - 1]
            if intervals.count > 2 && intervals[2] != 7 { keep.insert(2) }
        }
        var required: Set<PitchClass> = []
        for index in keep where index < intervals.count {
            required.insert(chord.root.transposed(by: intervals[index]))
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
        _ frets: [Int?], chord: Chord, board: FretboardModel, bassPC: PitchClass,
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
        // The chosen chord tone in the bass (root by default).
        guard board.note(at: sounded[0]).pitchClass == bassPC else { return }
        // Every defining tone present.
        let covered = Set(sounded.map { board.note(at: $0).pitchClass })
        guard covered.isSuperset(of: required) else { return }
        // Fretting-hand span ≤ 3 frets.
        let fretted = sounded.map(\.fret).filter { $0 > 0 }
        let span = fretted.isEmpty ? 0 : fretted.max()! - fretted.min()!
        guard span <= 3 else { return }

        let voicing = Voicing(frets: frets)
        let missingColor = pcs.subtracting(covered).count

        // Voicing conventions, learned from how grips are actually built:
        let notes = sounded.map { board.note(at: $0) }
        let roles = notes.map { chord.tone(of: $0.pitchClass) }
        let big = chord.pitchClasses.count >= 5
        var convention = 0
        if chord.quality.intervals.count >= 4 {
            // 1. Color tones out of the mud (threshold rises on big chords;
            //    the bass is exempt — it IS the chosen inversion).
            let mudline = big ? 48 : 45
            for (index, note) in notes.enumerated() where index > 0 {
                if note.midi < mudline, note.pitchClass != chord.root,
                   roles[index] != .fifth {
                    convention += 4
                }
            }
            // 2. Extensions stack ABOVE the 3rd, not under it.
            if let thirdIndex = roles.firstIndex(of: .third) {
                for index in 0..<thirdIndex where roles[index] == .extended {
                    convention += 2
                }
            }
            // 3. On big chords the 3rd is an interior voice, not the top.
            if big, roles.last == .third { convention += 3 }
        }
        // 4. Doubling is for roots; duplicated color tones crowd the grip.
        var seen: [PitchClass: Int] = [:]
        for note in notes { seen[note.pitchClass, default: 0] += 1 }
        for (pc, count) in seen where pc != chord.root && count > 1 {
            convention += count - 1
        }

        // Missing OPTIONAL tones are cheap (required ones were enforced
        // above) — the canonical m11 barre drops its 9th, as players do.
        let score = missingColor * 2 - sounded.count * 2 + span + convention
            + voicing.neckPosition / 2  // mild preference for lower grips
        let position = voicing.neckPosition
        if let current = best[position], current.score <= score { return }
        best[position] = (score, voicing)
    }
}
