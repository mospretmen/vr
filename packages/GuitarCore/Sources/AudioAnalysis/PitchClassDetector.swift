import MusicTheory

/// Single-note detection from a chromagram — the front-end for "play the
/// target note to advance" exercises. Deliberately stricter than the chord
/// matcher: one bin must clearly dominate before we call it a note.
public enum PitchClassDetector {
    /// The loudest bin must carry at least this ratio of the runner-up's
    /// energy to count as a single sounding note (rejects chords/noise).
    public static let dominanceRatio = 1.8
    /// Below this total energy the frame is silence.
    public static let energyGate = 1e-6

    public static func dominantPitchClass(in chroma: Chromagram) -> PitchClass? {
        guard chroma.totalEnergy > energyGate else { return nil }
        let ranked = chroma.energies.enumerated().sorted { $0.element > $1.element }
        let top = ranked[0], second = ranked[1]
        guard top.element > 0, top.element >= second.element * dominanceRatio else {
            return nil
        }
        return PitchClass(rawValue: top.offset)
    }
}

/// Debounces frame-level detections into a single "you hit the target"
/// event: the target pitch class must dominate `holdFrames` consecutive
/// frames, then the tracker latches until the target changes (one hit per
/// target, no re-triggering while the note rings out).
public struct NoteHitTracker: Sendable {
    public private(set) var target: PitchClass?
    private var streak = 0
    private var latched = false
    private let holdFrames: Int

    public init(holdFrames: Int = 2) {
        self.holdFrames = holdFrames
    }

    public mutating func setTarget(_ pitchClass: PitchClass?) {
        guard pitchClass != target else { return }
        target = pitchClass
        streak = 0
        latched = false
    }

    /// Feed one frame; returns true exactly once when the target is hit.
    public mutating func feed(_ chroma: Chromagram) -> Bool {
        guard let target, !latched else { return false }
        if PitchClassDetector.dominantPitchClass(in: chroma) == target {
            streak += 1
            if streak >= holdFrames {
                latched = true
                return true
            }
        } else {
            streak = 0
        }
        return false
    }
}
