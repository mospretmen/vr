import Foundation
import MusicTheory

/// Template-matching chord recognizer: scores a chromagram against weighted
/// binary templates for every (root × quality) candidate and returns the best
/// match above a confidence threshold.
///
/// This is the deterministic baseline for Phase 3 "listen" mode. If it proves
/// insufficient on real guitar signal (voicing overtones are messy), the
/// upgrade path is a small on-device CoreML classifier behind this same
/// interface — see docs/ROADMAP.md.
public enum ChordMatcher {
    public struct Match: Sendable, Equatable {
        public let chord: Chord
        /// Cosine similarity in [0, 1].
        public let score: Double
    }

    /// Qualities worth distinguishing from raw audio. Sus/dim7 variants are
    /// omitted from the default set: they confuse the matcher more than they
    /// help a practice overlay.
    public static let defaultCandidates: [ChordQuality] = [
        .major, .minor, .dominant7, .minor7, .major7, .diminished,
    ]

    /// Minimum energy below which input is treated as silence.
    public static let energyGate = 1e-6
    /// Minimum cosine similarity to report a chord at all.
    public static let confidenceThreshold = 0.7

    public static func match(
        _ chroma: Chromagram,
        candidates qualities: [ChordQuality] = defaultCandidates
    ) -> Match? {
        guard chroma.totalEnergy > energyGate else { return nil }
        let input = chroma.normalized

        var best: Match? = nil
        for root in PitchClass.allCases {
            for quality in qualities {
                let chord = Chord(root: root, quality: quality)
                let score = similarity(input, template(for: chord))
                if score > (best?.score ?? 0) {
                    best = Match(chord: chord, score: score)
                }
            }
        }
        guard let best, best.score >= confidenceThreshold else { return nil }
        return best
    }

    /// Weighted template: root slightly emphasized (it dominates guitar
    /// voicings, which usually double it), other chord tones equal.
    static func template(for chord: Chord) -> Chromagram {
        var chroma = Chromagram.silence
        for (i, interval) in chord.quality.intervals.enumerated() {
            let pc = chord.root.transposed(by: interval)
            chroma[pc] = i == 0 ? 1.3 : 1.0
        }
        return chroma.normalized
    }

    static func similarity(_ a: Chromagram, _ b: Chromagram) -> Double {
        zip(a.normalized.energies, b.normalized.energies).map(*).reduce(0, +)
    }
}

/// Smooths frame-by-frame matches into stable chord decisions: a new chord is
/// reported only after it wins `holdFrames` consecutive frames, killing the
/// flicker every raw per-frame recognizer produces.
public struct ChordDecisionSmoother: Sendable {
    public private(set) var current: Chord?
    private var candidate: Chord?
    private var candidateStreak = 0
    private let holdFrames: Int

    public init(holdFrames: Int = 3) {
        self.holdFrames = holdFrames
    }

    /// Feed one frame's match (nil = silence/uncertain); returns the stable chord.
    @discardableResult
    public mutating func feed(_ match: ChordMatcher.Match?) -> Chord? {
        guard let next = match?.chord else {
            candidate = nil
            candidateStreak = 0
            return current
        }
        if next == current {
            candidate = nil
            candidateStreak = 0
            return current
        }
        if next == candidate {
            candidateStreak += 1
        } else {
            candidate = next
            candidateStreak = 1
        }
        if candidateStreak >= holdFrames {
            current = next
            candidate = nil
            candidateStreak = 0
        }
        return current
    }

    public mutating func reset() {
        current = nil
        candidate = nil
        candidateStreak = 0
    }
}
