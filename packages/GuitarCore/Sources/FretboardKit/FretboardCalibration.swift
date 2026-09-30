import Foundation
import simd

/// Solves the fretboard-to-world transform from a manual calibration:
/// the user pinch-places two points in world space — the center of the nut
/// and the center of the 12th fret wire — plus a surface-normal hint taken
/// from the headset's view direction at placement time.
///
/// Because the 12th fret is exactly half the scale length, those two points
/// also recover the guitar's true scale length, so the overlay adapts to
/// any instrument (Gibson 24.75", Fender 25.5", bass, etc.) automatically.
public struct FretboardCalibration: Codable, Sendable, Hashable {
    /// World-space position of the nut center.
    public var nutPoint: SIMD3<Float>
    /// World-space position of the 12th-fret center.
    public var twelfthFretPoint: SIMD3<Float>
    /// Approximate direction the fretboard surface faces (e.g. toward the
    /// headset when the user looks down at the neck). Does not need to be
    /// exact or orthogonal; it is re-orthogonalized against the neck axis.
    public var surfaceNormalHint: SIMD3<Float>

    public init(nutPoint: SIMD3<Float>, twelfthFretPoint: SIMD3<Float>, surfaceNormalHint: SIMD3<Float>) {
        self.nutPoint = nutPoint
        self.twelfthFretPoint = twelfthFretPoint
        self.surfaceNormalHint = surfaceNormalHint
    }

    /// Recovered scale length in meters (nut→12th fret is half the scale).
    public var scaleLength: Double {
        Double(simd_distance(nutPoint, twelfthFretPoint)) * 2.0
    }

    /// True when the two points are far enough apart to be a plausible neck
    /// (guards against double-taps in the same spot).
    public var isPlausible: Bool {
        let half = simd_distance(nutPoint, twelfthFretPoint)
        return half > 0.15 && half < 0.60 // 12" ukulele … 47" extra-long bass, half-scale
    }

    /// The rigid transform mapping local fretboard space (see FretboardGeometry)
    /// into world space. Returns nil if the calibration is degenerate.
    public var transform: simd_float4x4? {
        let neckVector = twelfthFretPoint - nutPoint
        let neckLength = simd_length(neckVector)
        guard neckLength > 1e-4 else { return nil }

        let xAxis = neckVector / neckLength // along the neck, nut → bridge

        // Re-orthogonalize the normal hint against the neck axis.
        var yAxis = surfaceNormalHint - xAxis * simd_dot(surfaceNormalHint, xAxis)
        let yLength = simd_length(yAxis)
        guard yLength > 1e-4 else { return nil } // hint parallel to the neck
        yAxis /= yLength

        let zAxis = simd_cross(xAxis, yAxis)

        return simd_float4x4(
            SIMD4<Float>(xAxis, 0),
            SIMD4<Float>(yAxis, 0),
            SIMD4<Float>(zAxis, 0),
            SIMD4<Float>(nutPoint, 1)
        )
    }

    /// Convenience: a geometry sized from this calibration's recovered scale length.
    public func geometry(stringCount: Int = 6, fretCount: Int = 22, leftHanded: Bool = false) -> FretboardGeometry {
        FretboardGeometry(scaleLength: scaleLength, stringCount: stringCount,
                          fretCount: fretCount, leftHanded: leftHanded)
    }
}
