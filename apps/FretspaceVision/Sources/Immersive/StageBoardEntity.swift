import RealityKit
import SwiftUI
import MusicTheory
import FretboardKit

/// The floating performance fretboard: a large diagram-view board (nut on
/// the left, low string at the bottom — like every jazz chart) hanging in
/// space, lit by the active harmony. Completely independent of guitar
/// calibration; the player glances at it like a teleprompter.
@MainActor
enum StageBoardEntity {
    /// Visible board length in meters (22 frets scale up to this).
    static let boardLength: Float = 1.15
    /// Default spawn: eye-ish height, comfortably in front of the start pose.
    static let defaultPosition = SIMD3<Float>(0, 1.35, -1.5)

    /// Panel-plane mapping of a marker: local board (x, z) → panel (x, y),
    /// with a small +z pop toward the viewer.
    private static func panelPosition(
        _ position: FretPosition, geometry: FretboardGeometry, pop: Float
    ) -> SIMD3<Float> {
        let local = geometry.markerPosition(for: position)
        return SIMD3<Float>(local.x, local.z, pop)
    }

    static func build(
        highlights: [FretboardHighlight],
        geometry: FretboardGeometry,
        guideTones: Set<PitchClass>,
        avoidNotes: Set<PitchClass>,
        emphasizeGuideTones: Bool,
        dimAvoidNotes: Bool,
        labelStyle: LabelStyle,
        scale: Scale?
    ) -> Entity {
        let root = Entity()
        root.name = "stageBoard"

        let neckLength = Float(geometry.fretDistance(geometry.fretCount))
        let span = Float(abs(geometry.stringZ(string: 0, atX: 0)) * 2)

        root.addChild(backdrop(length: neckLength, span: span))
        root.addChild(boardLines(geometry: geometry, length: neckLength, span: span))
        root.addChild(markers(
            highlights: highlights, geometry: geometry,
            guideTones: guideTones, avoidNotes: avoidNotes,
            emphasizeGuideTones: emphasizeGuideTones, dimAvoidNotes: dimAvoidNotes,
            labelStyle: labelStyle, scale: scale
        ))

        // Scale the whole diagram up to stage size, centered on its middle.
        let factor = boardLength / neckLength
        root.scale = SIMD3<Float>(repeating: factor)
        // Shift so the board's center (not the nut) sits at the entity origin.
        root.position = SIMD3<Float>(-neckLength * factor / 2, 0, 0)

        let holder = Entity()
        holder.name = "stageBoardHolder"
        holder.addChild(root)
        return holder
    }

    // MARK: - Board cosmetics

    private static func backdrop(length: Float, span: Float) -> ModelEntity {
        let height = span * 1.5
        var material = UnlitMaterial(color: UIColor(white: 0.08, alpha: 1))
        material.blending = .transparent(opacity: 0.88)
        let panel = ModelEntity(
            mesh: .generateBox(width: length * 1.04, height: height, depth: 0.004,
                               cornerRadius: 0.012),
            materials: [material]
        )
        panel.position = SIMD3<Float>(length / 2, 0, -0.004)
        return panel
    }

    private static func boardLines(
        geometry: FretboardGeometry, length: Float, span: Float
    ) -> Entity {
        let container = Entity()
        container.name = "boardLines"
        let lineHeight = span * 1.18

        // Frets: vertical bars, the nut emphasized.
        for fret in 0...geometry.fretCount {
            let x = Float(geometry.fretDistance(fret))
            let isNut = fret == 0
            let material = UnlitMaterial(
                color: UIColor.white.withAlphaComponent(isNut ? 0.85 : 0.28))
            let bar = ModelEntity(
                mesh: .generateBox(width: isNut ? 0.004 : 0.0015,
                                   height: lineHeight, depth: 0.001),
                materials: [material]
            )
            bar.position = SIMD3<Float>(x, 0, 0)
            container.addChild(bar)
        }

        // Strings: horizontal lines, thicker toward the low string (bottom).
        for string in 0..<geometry.stringCount {
            let y = Float(geometry.stringZ(string: string, atX: 0))
            let gauge = 0.0022 - Float(string) * 0.0002
            let material = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.4))
            let line = ModelEntity(
                mesh: .generateBox(width: length, height: gauge, depth: 0.0012),
                materials: [material]
            )
            line.position = SIMD3<Float>(length / 2, y, 0.0008)
            container.addChild(line)
        }

        // Inlays.
        let inlayMaterial = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.14))
        for fret in [3, 5, 7, 9, 12, 15, 17, 19, 21] where fret <= geometry.fretCount {
            let x = Float((geometry.fretDistance(fret - 1) + geometry.fretDistance(fret)) / 2)
            let offsets: [Float] = fret == 12 ? [-span * 0.3, span * 0.3] : [0]
            for dy in offsets {
                let dot = ModelEntity(mesh: .generateSphere(radius: 0.004),
                                      materials: [inlayMaterial])
                dot.position = SIMD3<Float>(x, dy, 0)
                container.addChild(dot)
            }
        }
        return container
    }

    // MARK: - Markers

    private static func markers(
        highlights: [FretboardHighlight],
        geometry: FretboardGeometry,
        guideTones: Set<PitchClass>,
        avoidNotes: Set<PitchClass>,
        emphasizeGuideTones: Bool,
        dimAvoidNotes: Bool,
        labelStyle: LabelStyle,
        scale: Scale?
    ) -> Entity {
        let container = Entity()
        container.name = "stageMarkers"

        var meshCache: [Float: MeshResource] = [:]
        var materialCache: [Color: UnlitMaterial] = [:]

        for highlight in highlights {
            let pc = highlight.note.pitchClass
            let isGuide = emphasizeGuideTones && guideTones.contains(pc)
            let isAvoid = dimAvoidNotes && avoidNotes.contains(pc)

            var color = OverlayPalette.color(for: highlight.role)
            var radius = OverlayPalette.radius(for: highlight.role)
            var opacity: Float = 0.95
            if isGuide {
                color = Color(red: 1.0, green: 0.78, blue: 0.25) // target gold
                radius *= 1.5
            } else if isAvoid {
                color = Color.white
                radius *= 0.6
                opacity = 0.18
            }

            let mesh = meshCache[radius] ?? {
                let m = MeshResource.generateSphere(radius: radius)
                meshCache[radius] = m
                return m
            }()
            let material = materialCache[color] ?? {
                var m = UnlitMaterial(color: UIColor(color))
                m.blending = .transparent(opacity: .init(floatLiteral: opacity))
                materialCache[color] = m
                return m
            }()

            let marker = ModelEntity(mesh: mesh, materials: [material])
            marker.position = panelPosition(highlight.position, geometry: geometry,
                                            pop: 0.006 + radius * 0.5)
            container.addChild(marker)

            // Labels on the meaningful notes only — guide tones and chord
            // tones; scale-context dots stay clean.
            let wantsLabel: Bool
            switch highlight.role {
            case .chordTone: wantsLabel = true
            default: wantsLabel = isGuide
            }
            if wantsLabel, !isAvoid,
               let text = OverlayPalette.label(for: highlight, style: labelStyle, scale: scale) {
                let label = labelEntity(text: text, radius: radius)
                marker.addChild(label)
            }
        }
        return container
    }

    private static func labelEntity(text: String, radius: Float) -> Entity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.0004,
            font: .systemFont(ofSize: 0.011, weight: .bold),
            alignment: .center
        )
        let entity = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
        let bounds = entity.visualBounds(relativeTo: nil)
        entity.position = SIMD3<Float>(-bounds.extents.x / 2, radius + 0.003, 0.001)
        return entity
    }
}
