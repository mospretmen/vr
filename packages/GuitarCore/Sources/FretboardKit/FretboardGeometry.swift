import Foundation
import simd
import MusicTheory

/// Physical dimensions of a fretboard and the math to place notes on it.
///
/// Local fretboard space (right-handed, meters):
///   - origin: center of the nut, on the fretboard surface
///   - +X: along the neck, from nut toward the bridge
///   - +Y: out of the fretboard surface (toward the player's eyes)
///   - +Z: across the neck, from the lowest-pitched string toward the highest
public struct FretboardGeometry: Codable, Sendable, Hashable {
    /// Scale length in meters (nut to bridge). 0.648 m ≈ 25.5" Fender scale.
    public var scaleLength: Double
    public var stringCount: Int
    public var fretCount: Int
    /// Distance between outer strings at the nut, meters.
    public var stringSpanAtNut: Double
    /// Distance between outer strings at the 12th fret, meters (necks taper wider).
    public var stringSpanAt12: Double
    /// Mirrors string order across the neck centerline for left-handed guitars.
    public var leftHanded: Bool

    public init(
        scaleLength: Double = 0.648,
        stringCount: Int = 6,
        fretCount: Int = 22,
        stringSpanAtNut: Double = 0.035,
        stringSpanAt12: Double = 0.0445,
        leftHanded: Bool = false
    ) {
        self.scaleLength = scaleLength
        self.stringCount = stringCount
        self.fretCount = fretCount
        self.stringSpanAtNut = stringSpanAtNut
        self.stringSpanAt12 = stringSpanAt12
        self.leftHanded = leftHanded
    }

    /// Distance from the nut to fret `n` (equal temperament: d = L·(1 − 2^(−n/12))).
    public func fretDistance(_ fret: Int) -> Double {
        scaleLength * (1.0 - pow(2.0, -Double(fret) / 12.0))
    }

    /// X coordinate where a fingered note is displayed: midway between the
    /// fret wire and the previous one (fret 0 sits just behind the nut).
    public func noteX(fret: Int) -> Double {
        guard fret > 0 else { return -0.008 }
        return (fretDistance(fret - 1) + fretDistance(fret)) / 2.0
    }

    /// Z coordinate of a string at a given distance along the neck,
    /// accounting for the neck's taper.
    public func stringZ(string: Int, atX x: Double) -> Double {
        let x12 = fretDistance(12)
        let span = stringSpanAtNut + (stringSpanAt12 - stringSpanAtNut) * (x / x12)
        guard stringCount > 1 else { return 0 }
        let t = Double(string) / Double(stringCount - 1)
        let z = -span / 2.0 + span * t
        return leftHanded ? -z : z
    }

    /// Position of a note marker in local fretboard space.
    public func markerPosition(for position: FretPosition) -> SIMD3<Float> {
        let x = noteX(fret: position.fret)
        let z = stringZ(string: position.string, atX: x)
        return SIMD3<Float>(Float(x), 0, Float(z))
    }
}
