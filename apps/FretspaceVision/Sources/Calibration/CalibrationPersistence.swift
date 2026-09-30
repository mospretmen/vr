import ARKit
import Foundation
import simd
import FretboardKit

/// Persists calibrations across app launches using ARKit world anchors.
///
/// On save: a WorldAnchor is placed at the calibration transform (visionOS
/// persists world anchors per app automatically) and the recovered scale
/// length is stored alongside the anchor's UUID in UserDefaults.
/// On the next session: when the system re-localizes and replays the anchor,
/// the full calibration is reconstructed — the player picks up their guitar
/// and the overlay is already there, no pinching required. If the guitar
/// moved, they simply recalibrate.
@MainActor
final class CalibrationPersistence {
    private static let storageKey = "fretspace.calibrationAnchor.v1"

    private struct Stored: Codable {
        var anchorID: UUID
        var scaleLength: Double
    }

    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private var running = false

    /// Restored calibrations, yielded when a stored anchor re-localizes.
    /// Also (re)starts world tracking; call once per immersive session.
    func restoredCalibrations() -> AsyncStream<FretboardCalibration> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    try await session.run([worldTracking])
                    running = true
                    for await update in worldTracking.anchorUpdates {
                        guard update.event == .added || update.event == .updated,
                              update.anchor.isTracked,
                              let calibration = self.reconstruct(from: update.anchor)
                        else { continue }
                        AppLog.calibration.info("Restored calibration from world anchor")
                        continuation.yield(calibration)
                    }
                } catch {
                    AppLog.calibration.error("World tracking unavailable for persistence: \(error)")
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Anchors the calibration in the world and remembers it for next launch.
    func save(_ calibration: FretboardCalibration) async {
        guard running, let transform = calibration.transform else { return }
        do {
            // Replace any previous anchor so exactly one calibration persists.
            if let previous = stored() {
                try? await worldTracking.removeAnchor(forID: previous.anchorID)
            }
            let anchor = WorldAnchor(originFromAnchorTransform: transform)
            try await worldTracking.addAnchor(anchor)

            let record = Stored(anchorID: anchor.id, scaleLength: calibration.scaleLength)
            UserDefaults.standard.set(try JSONEncoder().encode(record),
                                      forKey: Self.storageKey)
            AppLog.calibration.info("Calibration anchored for future sessions")
        } catch {
            // Persistence is a convenience; the live session keeps working.
            AppLog.calibration.error("Failed to persist calibration anchor: \(error)")
        }
    }

    func forget() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: - Private

    private func stored() -> Stored? {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private func reconstruct(from anchor: WorldAnchor) -> FretboardCalibration? {
        guard let record = stored(), record.anchorID == anchor.id else { return nil }
        let transform = anchor.originFromAnchorTransform
        let nut = SIMD3<Float>(transform.columns.3.x,
                               transform.columns.3.y,
                               transform.columns.3.z)
        let xAxis = SIMD3<Float>(transform.columns.0.x,
                                 transform.columns.0.y,
                                 transform.columns.0.z)
        let yAxis = SIMD3<Float>(transform.columns.1.x,
                                 transform.columns.1.y,
                                 transform.columns.1.z)
        let halfScale = Float(record.scaleLength / 2)
        return FretboardCalibration(
            nutPoint: nut,
            twelfthFretPoint: nut + xAxis * halfScale,
            surfaceNormalHint: yAxis
        )
    }
}
