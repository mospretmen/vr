import Foundation
import MusicTheory

/// Twelve-bin pitch-class energy vector — the standard front-end for chord
/// recognition. The app-side audio pipeline (mic tap → FFT → bin folding)
/// produces these ~20×/second; everything downstream of that is pure logic
/// living here so it can be tested without audio hardware.
public struct Chromagram: Sendable, Equatable {
    /// Energy per pitch class, indexed by `PitchClass.rawValue` (C = 0).
    public var energies: [Double]

    public init(energies: [Double]) {
        precondition(energies.count == 12, "Chromagram needs exactly 12 bins")
        self.energies = energies
    }

    public static let silence = Chromagram(energies: Array(repeating: 0, count: 12))

    public subscript(_ pitchClass: PitchClass) -> Double {
        get { energies[pitchClass.rawValue] }
        set { energies[pitchClass.rawValue] = newValue }
    }

    public var totalEnergy: Double { energies.reduce(0, +) }

    /// L2-normalized copy (zero vector stays zero).
    public var normalized: Chromagram {
        let magnitude = sqrt(energies.map { $0 * $0 }.reduce(0, +))
        guard magnitude > 0 else { return self }
        return Chromagram(energies: energies.map { $0 / magnitude })
    }

    /// Convenience for tests and synthetic signals: unit energy on the given
    /// pitch classes, optionally weighted.
    public static func synthetic(_ pitchClasses: [PitchClass], weights: [Double]? = nil) -> Chromagram {
        var chroma = Chromagram.silence
        for (i, pc) in pitchClasses.enumerated() {
            chroma[pc] += weights?[i] ?? 1.0
        }
        return chroma
    }
}
