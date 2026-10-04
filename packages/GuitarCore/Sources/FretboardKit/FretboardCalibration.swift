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
    /// Used only when no `edgePoint` was captured.
    public var surfaceNormalHint: SIMD3<Float>

    /// Optional third calibration point on the fretboard surface toward the
    /// highest-pitched string's edge (any fret). Three measured points pin
    /// the board's plane exactly — eliminating the roll-around-the-neck
    /// error the head-direction hint is prone to.
    public var edgePoint: SIMD3<Float>?

    public init(
        nutPoint: SIMD3<Float>,
        twelfthFretPoint: SIMD3<Float>,
        surfaceNormalHint: SIMD3<Float>,
        edgePoint: SIMD3<Float>? = nil
    ) {
        self.nutPoint = nutPoint
        self.twelfthFretPoint = twelfthFretPoint
        self.surfaceNormalHint = surfaceNormalHint
        self.edgePoint = edgePoint
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
    ///
    /// With an `edgePoint`, the board plane is measured from three real
    /// points: +Z is the in-plane direction from the neck axis toward the
    /// edge point (high-string side), and +Y = Z × X faces out of the board.
    /// Without one, the head-position hint decides roll (less accurate).
    public var transform: simd_float4x4? {
        let neckVector = twelfthFretPoint - nutPoint
        let neckLength = simd_length(neckVector)
        guard neckLength > 1e-4 else { return nil }

        let xAxis = neckVector / neckLength // along the neck, nut → bridge

        if let edgePoint {
            // In-plane component of nut→edge, perpendicular to the neck.
            var zAxis = (edgePoint - nutPoint)
            zAxis -= xAxis * simd_dot(zAxis, xAxis)
            let zLength = simd_length(zAxis)
            guard zLength > 1e-3 else { return nil } // edge pinch on the neck line
            zAxis /= zLength
            var yAxis = simd_cross(zAxis, xAxis) // right-handed: z × x = y

            // The player faced the board during calibration; if the computed
            // normal points away from them, they pinched the low-string edge
            // — flip both axes so the overlay still faces out of the wood.
            if simd_dot(yAxis, surfaceNormalHint) < 0 {
                zAxis = -zAxis
                yAxis = -yAxis
            }

            return simd_float4x4(
                SIMD4<Float>(xAxis, 0),
                SIMD4<Float>(yAxis, 0),
                SIMD4<Float>(zAxis, 0),
                SIMD4<Float>(nutPoint, 1)
            )
        }

        // Fallback: re-orthogonalize the normal hint against the neck axis.
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
