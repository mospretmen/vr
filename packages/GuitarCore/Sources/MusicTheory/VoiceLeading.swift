/// How the voices travel when one chord moves to another: each tone of the
/// departing chord is routed to a tone of the arriving chord with minimal
/// total motion — common tones hold, leading tones resolve by half step.

/// One voice's journey: C→C is a held common tone, B→C a half-step pull.
public struct VoiceMove: Codable, Sendable, Hashable {
    public let from: PitchClass
    public let to: PitchClass
    /// Signed shortest motion in semitones, -5…+6 (0 = common tone).
    public let semitones: Int

    public var isCommonTone: Bool { semitones == 0 }
    public var isHalfStep: Bool { abs(semitones) == 1 }

    /// "B → C (+1)" / "G stays".
    public var summary: String {
        if isCommonTone { return "\(from.name()) stays" }
        let sign = semitones > 0 ? "+" : "−"
        return "\(from.name()) → \(to.name()) (\(sign)\(abs(semitones)))"
    }
}

public enum VoiceLeading {
    /// The minimal-motion routing from every tone of `from` to a tone of
    /// `to`. Every departing tone moves somewhere; every arriving tone is
    /// reached (voices may converge when the chords differ in size). Total
    /// absolute motion is minimized, common tones preferred on ties.
    public static func moves(from: Chord, to: Chord) -> [VoiceMove] {
        let a = from.pitchClasses
        let b = to.pitchClasses
        guard !a.isEmpty, !b.isEmpty else { return [] }

        var best: [Int]? = nil      // assignment: a[i] → b[best[i]]
        var bestCost = Int.max
        var bestCommon = -1

        var assignment = [Int](repeating: 0, count: a.count)
        func recurse(_ i: Int, _ used: Set<Int>) {
            if i == a.count {
                // Every arriving tone must be reached when there are
                // enough departing voices to do it.
                let coverage = Set(assignment)
                if a.count >= b.count && coverage.count < b.count { return }
                var cost = 0, common = 0
                for (j, target) in assignment.enumerated() {
                    let d = distance(a[j], b[target])
                    cost += abs(d)
                    if d == 0 { common += 1 }
                }
                if cost < bestCost || (cost == bestCost && common > bestCommon) {
                    bestCost = cost
                    bestCommon = common
                    best = assignment
                }
                return
            }
            for j in b.indices {
                assignment[i] = j
                recurse(i + 1, used.union([j]))
            }
        }
        recurse(0, [])

        guard let best else { return [] }
        return a.indices.map { i in
            VoiceMove(from: a[i], to: b[best[i]],
                      semitones: distance(a[i], b[best[i]]))
        }
    }

    /// Signed shortest path between pitch classes, in -5…+6.
    public static func distance(_ from: PitchClass, _ to: PitchClass) -> Int {
        let up = from.semitones(to: to)        // 0…11
        return up > 6 ? up - 12 : up
    }
}
