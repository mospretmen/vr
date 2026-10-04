import SwiftUI
import RealityKit
import MusicTheory
import FretboardKit

/// The mixed-immersion scene: renders the fretboard overlay locked onto the
/// player's guitar, and hosts the calibration + adjust flows.
struct ImmersiveView: View {
    @Environment(AppModel.self) private var model

    /// Anchors the overlay subtree; its transform is the calibration result.
    @State private var overlayAnchor = Entity()
    /// World-space helpers that must survive overlay rebuilds: the live
    /// pinch cursor and the adjust-mode grab handles.
    @State private var helperAnchor = Entity()
    /// The floating performance fretboard (independent of calibration).
    @State private var stageAnchor = Entity()
    @State private var cursor = Entity()
    @State private var pinchTracker = HandPinchTracker()
    @State private var persistence = CalibrationPersistence()
    @State private var activeHandle: CalibrationHandle?

    var body: some View {
        RealityView { content in
            overlayAnchor.name = "overlayAnchor"
            helperAnchor.name = "helperAnchor"
            cursor = Self.makeCursor()
            cursor.isEnabled = false
            helperAnchor.addChild(cursor)
            stageAnchor.name = "stageAnchor"
            stageAnchor.position = StageBoardEntity.defaultPosition
            content.add(overlayAnchor)
            content.add(helperAnchor)
            content.add(stageAnchor)
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
            _ = model.adjustingCalibration
            _ = model.boardPlacement
            _ = model.stageGuideTones
            _ = model.stageAvoidDimming
            _ = model.listen.detectedPitchClass
            rebuildOverlay()
        }
        .task {
            pinchTracker.onError = { model.presentedError = $0 }
            for await event in pinchTracker.pinchEvents() {
                handle(event)
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

    // MARK: - Pinch handling

    @MainActor
    private func handle(_ event: HandPinchTracker.PinchEvent) {
        switch event {
        case .moved(let position):
            if model.calibration.isPlacing {
                showCursor(at: position)
            } else if model.adjustingCalibration {
                dragHandle(to: position)
            }

        case .registered(let position, let devicePosition):
            cursor.isEnabled = false
            if model.calibration.isPlacing {
                model.recordCalibrationPoint(position, devicePosition: devicePosition)
                if case .calibrated(let calibration) = model.calibration {
                    Task { await persistence.save(calibration) }
                }
            } else if model.adjustingCalibration, activeHandle != nil {
                activeHandle = nil
                model.finishAdjustDrag()
                if case .calibrated(let calibration) = model.calibration {
                    Task { await persistence.save(calibration) }
                }
            }

        case .cancelled:
            cursor.isEnabled = false
            if activeHandle != nil {
                activeHandle = nil
                model.finishAdjustDrag() // rebuild from wherever it ended up
            }
        }
    }

    @MainActor
    private func showCursor(at position: SIMD3<Float>) {
        cursor.position = position
        cursor.isEnabled = true
    }

    /// Adjust mode: the first sample grabs the nearest handle (within 5 cm);
    /// subsequent samples move that calibration point live. The transform
    /// updates every sample (cheap); the full marker rebuild waits for release.
    @MainActor
    private func dragHandle(to position: SIMD3<Float>) {
        if activeHandle == nil {
            activeHandle = model.calibrationHandles
                .map { ($0.handle, simd_distance($0.position, position)) }
                .filter { $0.1 < 0.05 }
                .min { $0.1 < $1.1 }?.0
        }
        guard let handle = activeHandle else { return }

        showCursor(at: position)
        model.moveCalibrationPoint(handle, to: position)
        if case .calibrated(let calibration) = model.calibration,
           let transform = calibration.transform {
            overlayAnchor.setTransformMatrix(transform, relativeTo: nil)
        }
        refreshHandles()
    }

    // MARK: - Rendering

    @MainActor
    private func rebuildOverlay() {
        rebuildStageBoard()
        overlayAnchor.children.removeAll()
        refreshHandles()

        // On-guitar overlay renders only in its placement mode — the two
        // boards are never shown together.
        guard model.boardPlacement == .onGuitar else { return }

        guard case .calibrated(let calibration) = model.calibration,
              let transform = calibration.transform else {
            showCalibrationFeedback()
            return
        }

        let overlay = FretboardOverlayBuilder.build(
            highlights: model.highlights,
            geometry: model.geometry,
            labelStyle: model.labelStyle,
            showStringLines: model.showStringLines,
            showFretLines: model.showFretLines,
            connections: model.connectionGroups,
            scale: model.activeScale,
            emphasizeAlterations: model.emphasizeAlterations
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

    /// The floating performance board — shows whatever the current display
    /// mode is studying, synced to the active harmony.
    @MainActor
    private func rebuildStageBoard() {
        stageAnchor.children.removeAll()
        guard model.boardPlacement == .floating else { return }

        let chordContext = model.stageShowsChordContext
        let board = StageBoardEntity.build(
            content: .init(
                highlights: model.highlights,
                connections: model.connectionGroups,
                guideTones: chordContext ? model.guideTonePitchClasses : [],
                avoidNotes: chordContext ? model.avoidPitchClasses : [],
                emphasizeGuideTones: model.stageGuideTones && chordContext,
                dimAvoidNotes: model.stageAvoidDimming && chordContext,
                labelStyle: model.labelStyle,
                scale: model.activeScale,
                litPitchClass: model.listen.detectedPitchClass
            ),
            // 15 frets keeps the stage board airy; the full neck lives in
            // the chart panel when needed.
            geometry: FretboardGeometry(stringCount: model.tuning.stringCount,
                                        fretCount: min(model.fretCount, 15))
        )
        stageAnchor.addChild(board)
    }

    /// Mid-calibration feedback: confirmed points stay visible as glowing
    /// dots while the user lines up the next pinch.
    @MainActor
    private func showCalibrationFeedback() {
        overlayAnchor.setTransformMatrix(matrix_identity_float4x4, relativeTo: nil)

        var confirmed: [SIMD3<Float>] = []
        switch model.calibration {
        case .placingTwelfthFret(let nut):
            confirmed = [nut]
        case .placingEdge(let nut, let twelfth):
            confirmed = [nut, twelfth]
        default:
            return
        }

        for point in confirmed {
            let dot = Self.makeDot(radius: 0.008, color: .orange)
            dot.position = point
            overlayAnchor.addChild(dot)
        }
    }

    /// Adjust-mode grab handles, in world space (helperAnchor is identity).
    @MainActor
    private func refreshHandles() {
        helperAnchor.children
            .filter { $0.name == "handle" }
            .forEach { $0.removeFromParent() }

        guard model.adjustingCalibration else { return }
        for item in model.calibrationHandles {
            let handle = Self.makeDot(radius: 0.011, color: .cyan, opacity: 0.6)
            handle.name = "handle"
            handle.position = item.position
            helperAnchor.addChild(handle)
        }
    }

    // MARK: - Entity factories

    private static func makeCursor() -> Entity {
        makeDot(radius: 0.005, color: .white, opacity: 0.9)
    }

    private static func makeDot(
        radius: Float, color: UIColor, opacity: Float = 0.95
    ) -> ModelEntity {
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
    }
}
