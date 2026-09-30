import ARKit
import QuartzCore
import simd

/// Watches hand tracking and emits a world-space point whenever the user
/// performs a deliberate pinch (thumb tip meets index tip), along with the
/// headset position at that moment (used as the fretboard-normal hint).
///
/// Used only during calibration; the session is stopped afterward to save power.
@MainActor
final class HandPinchTracker {
    struct PinchEvent: Sendable {
        let position: SIMD3<Float>   // midpoint between thumb and index tips
        let devicePosition: SIMD3<Float>
    }

    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private let worldTracking = WorldTrackingProvider()

    private var pinchActive = false
    private static let pinchCloseDistance: Float = 0.015 // meters — fingers touching
    private static let pinchOpenDistance: Float = 0.035  // hysteresis for release

    /// Runs until cancelled, yielding one event per completed pinch of either hand.
    func pinchEvents() -> AsyncStream<PinchEvent> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    try await session.run([handTracking, worldTracking])
                    for await update in handTracking.anchorUpdates {
                        guard update.event == .updated else { continue }
                        if let event = self.detectPinch(in: update.anchor) {
                            continuation.yield(event)
                        }
                    }
                } catch {
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

    private func detectPinch(in anchor: HandAnchor) -> PinchEvent? {
        guard anchor.isTracked,
              let skeleton = anchor.handSkeleton else { return nil }

        let thumbTip = skeleton.joint(.thumbTip)
        let indexTip = skeleton.joint(.indexFingerTip)
        guard thumbTip.isTracked, indexTip.isTracked else { return nil }

        let origin = anchor.originFromAnchorTransform
        let thumbWorld = worldPosition(origin * thumbTip.anchorFromJointTransform)
        let indexWorld = worldPosition(origin * indexTip.anchorFromJointTransform)
        let distance = simd_distance(thumbWorld, indexWorld)

        // Edge-trigger on close with hysteresis so one pinch = one event.
        if !pinchActive, distance < Self.pinchCloseDistance {
            pinchActive = true
            let device = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
            let devicePosition = device.map { worldPosition($0.originFromAnchorTransform) }
                ?? SIMD3<Float>(0, 1.4, 0)
            return PinchEvent(position: (thumbWorld + indexWorld) / 2,
                              devicePosition: devicePosition)
        }
        if pinchActive, distance > Self.pinchOpenDistance {
            pinchActive = false
        }
        return nil
    }

    private func worldPosition(_ transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}
