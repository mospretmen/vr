import RealityKit
import SwiftUI
import MusicTheory
import FretboardKit

/// The floating performance fretboard: a clean diagram-view board (nut on
/// the left, low string at the bottom — like every jazz chart) hanging in
/// space. Visual language of a printed fretboard diagram: crisp string and
/// fret lines in open passthrough (no backdrop), flat note disks sitting
/// exactly on the string/fret intersections with their labels ON the disk,
/// fret numbers below for orientation.
@MainActor
enum StageBoardEntity {
    /// Visible board length in meters (22 frets scale up to this).
    static let boardLength: Float = 1.15
    /// Default spawn: eye-ish height, comfortably in front of the start pose.
    static let defaultPosition = SIMD3<Float>(0, 1.35, -1.5)

    struct Content {
        var highlights: [FretboardHighlight]
        var connections: [[FretPosition]]
        var guideTones: Set<PitchClass>
        var avoidNotes: Set<PitchClass>
        var emphasizeGuideTones: Bool
        var dimAvoidNotes: Bool
        var labelStyle: LabelStyle
        var scale: Scale?
        /// Pitch class currently heard in listen mode — glows on the board.
        var litPitchClass: PitchClass?
    }

    /// Panel-plane mapping: local board (x, z) → panel (x, y).
    private static func panelXY(
        _ position: FretPosition, geometry: FretboardGeometry
    ) -> SIMD2<Float> {
        let local = geometry.markerPosition(for: position)
        return SIMD2<Float>(local.x, local.z)
    }

    static func build(content: Content, geometry: FretboardGeometry) -> Entity {
        let root = Entity()
        root.name = "stageBoard"

        let neckLength = Float(geometry.fretDistance(geometry.fretCount))
        let span = Float(abs(geometry.stringZ(string: 0, atX: 0)) * 2)

        root.addChild(boardLines(geometry: geometry, length: neckLength, span: span))
        root.addChild(fretNumbers(geometry: geometry, span: span))
        if !content.connections.isEmpty {
            root.addChild(connectionLines(content.connections, geometry: geometry))
        }
        root.addChild(markers(content: content, geometry: geometry))

        // Scale the whole diagram to stage size, centered on its middle.
        let factor = boardLength / neckLength
        root.scale = SIMD3<Float>(repeating: factor)
        root.position = SIMD3<Float>(-neckLength * factor / 2, 0, 0)

        let holder = Entity()
        holder.name = "stageBoardHolder"
        holder.addChild(root)
        return holder
    }

    // MARK: - Board structure

    private static func boardLines(
        geometry: FretboardGeometry, length: Float, span: Float
    ) -> Entity {
        let container = Entity()
        container.name = "boardLines"
        let lineHeight = span * 1.12

        for fret in 0...geometry.fretCount {
            let x = Float(geometry.fretDistance(fret))
            let isNut = fret == 0
            let material = UnlitMaterial(
                color: UIColor.white.withAlphaComponent(isNut ? 0.9 : 0.32))
            let bar = ModelEntity(
                mesh: .generateBox(width: isNut ? 0.0045 : 0.0016,
                                   height: lineHeight, depth: 0.0008),
                materials: [material]
            )
            bar.position = SIMD3<Float>(x, 0, 0)
            container.addChild(bar)
        }

        for string in 0..<geometry.stringCount {
            let y = Float(geometry.stringZ(string: string, atX: 0))
            let gauge = 0.0024 - Float(string) * 0.00022
            let material = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.5))
            let line = ModelEntity(
                mesh: .generateBox(width: length, height: gauge, depth: 0.0008),
                materials: [material]
            )
            line.position = SIMD3<Float>(length / 2, y, 0.0005)
            container.addChild(line)
        }

        // Subtle inlay dots above the board (clear of the note lanes).
        let inlayMaterial = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.2))
        for fret in [3, 5, 7, 9, 12, 15, 17, 19, 21] where fret <= geometry.fretCount {
            let x = Float(geometry.noteX(fret: fret))
            let count = fret == 12 ? 2 : 1
            for i in 0..<count {
                let dot = ModelEntity(mesh: .generateSphere(radius: 0.0032),
                                      materials: [inlayMaterial])
                dot.scale = SIMD3<Float>(1, 1, 0.2)
                dot.position = SIMD3<Float>(x + Float(i) * 0.008 - Float(count - 1) * 0.004,
                                            span * 0.72, 0.0005)
                container.addChild(dot)
            }
        }
        return container
    }

    /// Fret numbers under the board — the player's orientation anchors.
    private static func fretNumbers(geometry: FretboardGeometry, span: Float) -> Entity {
        let container = Entity()
        container.name = "fretNumbers"
        for fret in [3, 5, 7, 9, 12, 15, 17, 19, 21] where fret <= geometry.fretCount {
            let text = textEntity("\(fret)", size: 0.016,
                                  color: UIColor.white.withAlphaComponent(0.65))
            let bounds = text.visualBounds(relativeTo: nil)
            text.position = SIMD3<Float>(
                Float(geometry.noteX(fret: fret)) - bounds.extents.x / 2,
                -span * 0.95, 0)
            container.addChild(text)
        }
        return container
    }

    // MARK: - Voicing shape connections

    private static func connectionLines(
        _ groups: [[FretPosition]], geometry: FretboardGeometry
    ) -> Entity {
        let container = Entity()
        container.name = "connections"
        let material = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.55))

        for group in groups {
            for (a, b) in zip(group, group.dropFirst()) {
                let pa = panelXY(a, geometry: geometry)
                let pb = panelXY(b, geometry: geometry)
                let delta = pb - pa
                let length = simd_length(delta)
                guard length > 1e-5 else { continue }

                let segment = ModelEntity(
                    mesh: .generateBox(width: length, height: 0.0022, depth: 0.0006),
                    materials: [material]
                )
                segment.position = SIMD3<Float>((pa.x + pb.x) / 2, (pa.y + pb.y) / 2, 0.0015)
                segment.orientation = simd_quatf(angle: atan2(delta.y, delta.x),
                                                 axis: SIMD3<Float>(0, 0, 1))
                container.addChild(segment)
            }
        }
        return container
    }

    // MARK: - Note disks

    private static func markers(content: Content, geometry: FretboardGeometry) -> Entity {
        let container = Entity()
        container.name = "stageMarkers"

        for highlight in content.highlights {
            let pc = highlight.note.pitchClass
            let isGuide = content.emphasizeGuideTones && content.guideTones.contains(pc)
            let isAvoid = content.dimAvoidNotes && content.avoidNotes.contains(pc)
            let isLit = content.litPitchClass == pc

            // Diagram-first palette: strong flat disks, readable text.
            var disk: UIColor
            var textColor: UIColor = .white
            var radius: Float
            var opacity: Float = 1.0
            switch highlight.role {
            case .chordTone where isGuide:
                disk = UIColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 1)
                textColor = .black
                radius = 0.0145
            case .chordTone(.root):
                disk = .systemOrange; radius = 0.012
            case .chordTone(.third):
                disk = .systemCyan; textColor = .black; radius = 0.011
            case .chordTone(.fifth):
                disk = .systemGreen; textColor = .black; radius = 0.011
            case .chordTone:
                disk = .systemPurple; radius = 0.011
            case .scaleDegree(1):
                disk = .systemOrange; radius = 0.011
            case .scaleDegree:
                disk = UIColor(white: 0.32, alpha: 1); radius = 0.0095
            case .exerciseStep(let isCurrent):
                disk = isCurrent ? .systemMint : UIColor(white: 0.32, alpha: 1)
                textColor = isCurrent ? .black : .white
                radius = isCurrent ? 0.0145 : 0.0095
            }
            if isAvoid {
                disk = UIColor(white: 0.25, alpha: 1)
                radius = 0.005
                opacity = 0.35
            }

            let xy = panelXY(highlight.position, geometry: geometry)

            // Heard-note glow: a soft halo behind the disk.
            if isLit {
                var halo = UnlitMaterial(color: .cyan)
                halo.blending = .transparent(opacity: 0.45)
                let ring = ModelEntity(mesh: .generateSphere(radius: radius * 1.7),
                                       materials: [halo])
                ring.scale = SIMD3<Float>(1, 1, 0.1)
                ring.position = SIMD3<Float>(xy.x, xy.y, 0.002)
                container.addChild(ring)
            }

            var material = UnlitMaterial(color: disk)
            material.blending = .transparent(opacity: .init(floatLiteral: opacity))
            let marker = ModelEntity(mesh: .generateSphere(radius: radius),
                                     materials: [material])
            marker.scale = SIMD3<Float>(1, 1, 0.16) // flat disk, no hover
            marker.position = SIMD3<Float>(xy.x, xy.y, 0.003)
            container.addChild(marker)

            // Label ON the disk, centered — never floating beside it.
            if !isAvoid,
               let label = OverlayPalette.label(for: highlight, style: content.labelStyle,
                                                scale: content.scale) {
                let text = textEntity(label, size: radius * 1.05, color: textColor)
                let bounds = text.visualBounds(relativeTo: nil)
                text.position = SIMD3<Float>(xy.x - bounds.extents.x / 2,
                                             xy.y - bounds.extents.y / 2,
                                             0.0055)
                container.addChild(text)
            }
        }
        return container
    }

    private static func textEntity(_ string: String, size: Float,
                                   color: UIColor) -> ModelEntity {
        let mesh = MeshResource.generateText(
            string,
            extrusionDepth: 0.0003,
            font: .systemFont(ofSize: CGFloat(size), weight: .bold),
            alignment: .center
        )
        return ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)])
    }
}
