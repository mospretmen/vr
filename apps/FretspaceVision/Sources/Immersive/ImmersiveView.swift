import SwiftUI
import RealityKit
import MusicTheory
import FretboardKit

/// The mixed-immersion scene: renders the fretboard overlay locked onto the
/// player's guitar, and hosts the calibration flow.
struct ImmersiveView: View {
    @Environment(AppModel.self) private var model

    /// Anchors the overlay subtree; its transform is the calibration result.
    @State private var overlayAnchor = Entity()
    @State private var pinchTracker = HandPinchTracker()
    @State private var persistence = CalibrationPersistence()

    var body: some View {
        RealityView { content in
            overlayAnchor.name = "overlayAnchor"
            content.add(overlayAnchor)
            rebuildOverlay()
        } update: { _ in
            // Re-runs when observed model state changes.
            _ = model.overlayRevision
            _ = model.labelStyle
            _ = model.showStringLines
            _ = model.showFretLines
            _ = model.displayMode
            _ = model.root
            _ = model.scaleType
            _ = model.chordRoot
            _ = model.chordQuality
            _ = model.listen.detectedChord
            _ = model.backing.currentChord
            rebuildOverlay()
        }
        .task {
            pinchTracker.onError = { model.presentedError = $0 }
            // Only listen for pinches while a calibration flow is active.
            for await pinch in pinchTracker.pinchEvents() {
                switch model.calibration {
                case .placingNut, .placingTwelfthFret:
                    model.recordCalibrationPoint(pinch.position, devicePosition: pinch.devicePosition)
                    // A fresh manual calibration supersedes the stored one.
                    if case .calibrated(let calibration) = model.calibration {
                        await persistence.save(calibration)
                    }
                case .notCalibrated, .calibrated:
                    continue
                }
            }
        }
        .task {
            // Re-localized anchor from a previous session restores the
            // overlay with zero setup — unless the user already calibrated.
            for await restored in persistence.restoredCalibrations() {
                if case .notCalibrated = model.calibration {
                    model.calibration = .calibrated(restored)
                    model.overlayDidChange()
                }
            }
        }
        .onAppear { model.immersiveSpaceOpen = true }
        .onDisappear { model.immersiveSpaceOpen = false }
    }

    @MainActor
    private func rebuildOverlay() {
        overlayAnchor.children.removeAll()

        guard case .calibrated(let calibration) = model.calibration,
              let transform = calibration.transform else { return }

        let overlay = FretboardOverlayBuilder.build(
            highlights: model.highlights,
            geometry: model.geometry,
            labelStyle: model.labelStyle,
            showStringLines: model.showStringLines,
            showFretLines: model.showFretLines,
            connections: model.connectionGroups,
            scale: model.activeScale
        )
        overlayAnchor.setTransformMatrix(transform, relativeTo: nil)
        overlayAnchor.addChild(overlay)

        // Markers bloom in instead of popping: brief scale-up from the board.
        let settled = overlay.transform
        var compressed = settled
        compressed.scale = SIMD3<Float>(1, 0.01, 1)
        overlay.transform = compressed
        overlay.move(to: settled, relativeTo: overlayAnchor,
                     duration: 0.25, timingFunction: .easeOut)

        if let chord = model.listen.detectedChord {
            let aura = ChordAuraEntity.make(
                for: chord,
                geometry: model.geometry,
                intensity: Float(max(model.listen.confidence, 0.4))
            )
            overlayAnchor.addChild(aura)
        }
    }
}
