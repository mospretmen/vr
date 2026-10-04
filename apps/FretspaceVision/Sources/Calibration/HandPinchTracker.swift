import ARKit
import QuartzCore
import simd

/// Watches hand tracking and streams pinch *gestures* with enough fidelity
/// for precise placement:
///  - `.moved` fires continuously while the fingers are pinched (live cursor)
///  - `.registered` fires on release with the time-averaged position of the
///    whole hold — steadier than any single hand-tracking sample — provided
///    the pinch was held long enough to be deliberate.
///
/// Used during calibration and adjust mode; stop the stream to save power.
@MainActor
final class HandPinchTracker {
    enum PinchEvent: Sendable {
        /// Fingers are pinched at this position right now.
        case moved(position: SIMD3<Float>)
        /// Fingers released after a deliberate hold; position is the average
        /// over the hold window.
        case registered(position: SIMD3<Float>, devicePosition: SIMD3<Float>)
        /// Fingers released too quickly to count (accidental flick).
        case cancelled
    }

    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private let worldTracking = WorldTrackingProvider()

    private static let pinchCloseDistance: Float = 0.015 // meters — touching
    private static let pinchOpenDistance: Float = 0.035  // hysteresis
    /// Shorter holds are treated as accidental.
    private static let minimumHold: TimeInterval = 0.35

    // Per-hand pinch accumulation (left/right tracked independently;
    // whichever completes a deliberate hold first wins).
    private struct Hold {
        var sum = SIMD3<Float>.zero
        var count: Float = 0
        var startedAt: TimeInterval = 0
    }
    private var holds: [HandAnchor.Chirality: Hold] = [:]

    /// Failures the user must act on (permission revoked, tracking dead).
    var onError: (@MainActor (UserFacingError) -> Void)?

    /// Runs until cancelled, streaming pinch gestures from either hand.
    func pinchEvents() -> AsyncStream<PinchEvent> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    try await session.run([handTracking, worldTracking])
                    AppLog.calibration.info("Hand tracking session started")
                    for await update in handTracking.anchorUpdates {
                        guard update.event == .updated else { continue }
                        for event in self.process(anchor: update.anchor) {
                            continuation.yield(event)
                        }
                    }
                } catch {
                    AppLog.calibration.error("Hand tracking session failed: \(error)")
                    self.onError?(.handTrackingUnavailable)
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                self.stop()
            }
        }
    }

    nonisolated private func stop() {
        Task { @MainActor in session.stop() }
    }

    private func process(anchor: HandAnchor) -> [PinchEvent] {
        guard anchor.isTracked, let skeleton = anchor.handSkeleton else { return [] }

        let thumbTip = skeleton.joint(.thumbTip)
        let indexTip = skeleton.joint(.indexFingerTip)
        guard thumbTip.isTracked, indexTip.isTracked else { return [] }

        let origin = anchor.originFromAnchorTransform
        let thumbWorld = worldPosition(origin * thumbTip.anchorFromJointTransform)
        let indexWorld = worldPosition(origin * indexTip.anchorFromJointTransform)
        let distance = simd_distance(thumbWorld, indexWorld)
        let midpoint = (thumbWorld + indexWorld) / 2
        let hand = anchor.chirality

        if var hold = holds[hand] {
            if distance > Self.pinchOpenDistance {
                // Release: deliberate hold → registered; flick → cancelled.
                holds[hand] = nil
                let heldFor = CACurrentMediaTime() - hold.startedAt
                guard heldFor >= Self.minimumHold, hold.count > 0 else {
                    return [.cancelled]
                }
                let average = hold.sum / hold.count
                let device = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
                let devicePosition = device.map { worldPosition($0.originFromAnchorTransform) }
                    ?? SIMD3<Float>(0, 1.4, 0)
                return [.registered(position: average, devicePosition: devicePosition)]
            }
            // Still pinched: accumulate and stream the live position.
            hold.sum += midpoint
            hold.count += 1
            holds[hand] = hold
            return [.moved(position: midpoint)]
        }

        if distance < Self.pinchCloseDistance {
            holds[hand] = Hold(sum: midpoint, count: 1, startedAt: CACurrentMediaTime())
            return [.moved(position: midpoint)]
        }
        return []
    }

    private func worldPosition(_ transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}
