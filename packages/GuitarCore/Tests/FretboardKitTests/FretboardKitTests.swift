import Testing
import simd
import MusicTheory
@testable import FretboardKit

@Suite("Fret geometry")
struct FretboardGeometryTests {
    let geo = FretboardGeometry() // 0.648 m scale

    @Test func twelfthFretIsHalfTheScaleLength() {
        #expect(abs(geo.fretDistance(12) - geo.scaleLength / 2) < 1e-9)
    }

    @Test func fretDistancesIncreaseAndShrink() {
        var previousGap = Double.greatestFiniteMagnitude
        for fret in 1...geo.fretCount {
            let gap = geo.fretDistance(fret) - geo.fretDistance(fret - 1)
            #expect(gap > 0)
            #expect(gap < previousGap) // each fret narrower than the last
            previousGap = gap
        }
    }

    @Test func noteMarkersSitBetweenFretWires() {
        for fret in 1...geo.fretCount {
            let x = geo.noteX(fret: fret)
            #expect(x > geo.fretDistance(fret - 1))
            #expect(x < geo.fretDistance(fret))
        }
        #expect(geo.noteX(fret: 0) < 0) // open string marker sits behind the nut
    }

    @Test func stringsAreSymmetricAndTaper() {
        let zLowAtNut = geo.stringZ(string: 0, atX: 0)
        let zHighAtNut = geo.stringZ(string: 5, atX: 0)
        #expect(abs(zLowAtNut + zHighAtNut) < 1e-9) // symmetric about centerline
        let x12 = geo.fretDistance(12)
        #expect(abs(geo.stringZ(string: 5, atX: x12)) > abs(zHighAtNut)) // wider at 12th
    }
}

@Suite("Calibration solver")
struct FretboardCalibrationTests {
    /// A guitar lying in world space: nut at (1, 1, -0.5), neck pointing +X,
    /// fretboard facing +Y (player looking straight down at it).
    let calibration = FretboardCalibration(
        nutPoint: SIMD3<Float>(1, 1, -0.5),
        twelfthFretPoint: SIMD3<Float>(1.324, 1, -0.5),
        surfaceNormalHint: SIMD3<Float>(0, 1, 0)
    )

    @Test func recoversScaleLength() {
        #expect(abs(calibration.scaleLength - 0.648) < 1e-4)
    }

    @Test func transformMapsNutToWorldAnchor() throws {
        let transform = try #require(calibration.transform)
        let mappedNut = transform * SIMD4<Float>(0, 0, 0, 1)
        #expect(simd_distance(SIMD3(mappedNut.x, mappedNut.y, mappedNut.z), calibration.nutPoint) < 1e-5)
    }

    @Test func transformMapsTwelfthFretMarkerNearTheTapPoint() throws {
        let transform = try #require(calibration.transform)
        let geo = calibration.geometry()
        let local = SIMD3<Float>(Float(geo.fretDistance(12)), 0, 0)
        let world4 = transform * SIMD4<Float>(local, 1)
        let world = SIMD3(world4.x, world4.y, world4.z)
        #expect(simd_distance(world, calibration.twelfthFretPoint) < 1e-4)
    }

    @Test func normalHintIsReorthogonalized() throws {
        // A sloppy hint leaning along the neck still yields an orthonormal frame.
        var sloppy = calibration
        sloppy.surfaceNormalHint = simd_normalize(SIMD3<Float>(0.6, 1, 0.1))
        let t = try #require(sloppy.transform)
        let x = SIMD3(t.columns.0.x, t.columns.0.y, t.columns.0.z)
        let y = SIMD3(t.columns.1.x, t.columns.1.y, t.columns.1.z)
        let z = SIMD3(t.columns.2.x, t.columns.2.y, t.columns.2.z)
        #expect(abs(simd_dot(x, y)) < 1e-5)
        #expect(abs(simd_dot(x, z)) < 1e-5)
        #expect(abs(simd_length(y) - 1) < 1e-5)
    }

    @Test func edgePointPinsThePlaneExactly() throws {
        // Board lying flat (surface up). Edge pinch on the high-string side
        // at the 5th-fret area: +Z in world, slightly along the neck.
        var threePoint = calibration
        threePoint.edgePoint = SIMD3<Float>(1.10, 1.0, -0.47)
        // Deliberately bad head hint — must NOT matter beyond sign checking.
        threePoint.surfaceNormalHint = simd_normalize(SIMD3<Float>(0.5, 0.7, 0.4))

        let t = try #require(threePoint.transform)
        let y = SIMD3(t.columns.1.x, t.columns.1.y, t.columns.1.z)
        let z = SIMD3(t.columns.2.x, t.columns.2.y, t.columns.2.z)
        // Normal is exactly world-up (plane through the three points).
        #expect(abs(y.y - 1) < 1e-5)
        #expect(abs(z.z - 1) < 1e-5) // +Z toward the pinched edge
    }

    @Test func wrongEdgeSideIsAutoCorrected() throws {
        // Pinching the LOW-string edge (-Z side) must not flip the board
        // into the wood: the normal still faces the player.
        var threePoint = calibration
        threePoint.edgePoint = SIMD3<Float>(1.10, 1.0, -0.53) // -Z side
        threePoint.surfaceNormalHint = SIMD3<Float>(0, 1, 0)  // player above

        let t = try #require(threePoint.transform)
        let y = SIMD3(t.columns.1.x, t.columns.1.y, t.columns.1.z)
        #expect(y.y > 0.99) // normal still up, not into the guitar
    }

    @Test func edgePinchOnTheNeckLineIsRejected() {
        var bad = calibration
        bad.edgePoint = calibration.nutPoint + SIMD3<Float>(0.1, 0, 0) // on the axis
        #expect(bad.transform == nil)
    }

    @Test func degenerateCalibrationsAreRejected() {
        let samePoint = FretboardCalibration(
            nutPoint: .zero, twelfthFretPoint: .zero, surfaceNormalHint: SIMD3<Float>(0, 1, 0))
        #expect(samePoint.transform == nil)
        #expect(!samePoint.isPlausible)

        let parallelHint = FretboardCalibration(
            nutPoint: .zero,
            twelfthFretPoint: SIMD3<Float>(0.324, 0, 0),
            surfaceNormalHint: SIMD3<Float>(1, 0, 0))
        #expect(parallelHint.transform == nil)
    }

    @Test func markerPositionsLandOnTheBoard() {
        let geo = calibration.geometry()
        let marker = geo.markerPosition(for: FretPosition(string: 0, fret: 5))
        #expect(marker.x > 0 && Double(marker.x) < geo.scaleLength / 2)
        #expect(marker.y == 0)
    }
}
