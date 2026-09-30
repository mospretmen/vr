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
            // Only listen for pinches while a calibration flow is active.
            for await pinch in pinchTracker.pinchEvents() {
                switch model.calibration {
                case .placingNut, .placingTwelfthFret:
                    model.recordCalibrationPoint(pinch.position, devicePosition: pinch.devicePosition)
                case .notCalibrated, .calibrated:
                    continue
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
            showFretLines: model.showFretLines
        )
        overlayAnchor.setTransformMatrix(transform, relativeTo: nil)
        overlayAnchor.addChild(overlay)

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
