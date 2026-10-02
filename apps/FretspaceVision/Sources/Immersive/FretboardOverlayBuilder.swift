import RealityKit
import SwiftUI
import MusicTheory
import FretboardKit

/// Builds the RealityKit entity tree for the fretboard overlay from pure data.
/// Stateless: the immersive view calls `build` whenever the model changes and
/// swaps the old subtree for the new one.
@MainActor
enum FretboardOverlayBuilder {
    /// Root entity in *local fretboard space*; caller applies the calibration
    /// transform to place it on the physical guitar.
    static func build(
        highlights: [FretboardHighlight],
        geometry: FretboardGeometry,
        labelStyle: LabelStyle,
        showStringLines: Bool,
        showFretLines: Bool,
        connections: [[FretPosition]] = [],
        scale: Scale? = nil,
        emphasizeAlterations: Bool = false
    ) -> Entity {
        let root = Entity()
        root.name = "fretboardOverlay"

        if showFretLines {
            root.addChild(fretLines(geometry: geometry))
        }
        if showStringLines {
            root.addChild(stringLines(geometry: geometry))
        }
        if !connections.isEmpty {
            root.addChild(connectionLines(groups: connections, geometry: geometry))
        }
        root.addChild(markers(highlights: highlights, geometry: geometry,
                              labelStyle: labelStyle, scale: scale,
                              emphasizeAlterations: emphasizeAlterations))

        return root
    }

    // MARK: - Shape connections (triad voicings, etc.)

    /// Thin luminous segments linking consecutive positions of each group,
    /// floated just above the board so shapes read as units.
    private static func connectionLines(
        groups: [[FretPosition]],
        geometry: FretboardGeometry
    ) -> Entity {
        let container = Entity()
        container.name = "connections"
        let material = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.45))
        let lift = SIMD3<Float>(0, 0.004, 0) // match marker float height

        for group in groups {
            for (a, b) in zip(group, group.dropFirst()) {
                let start = geometry.markerPosition(for: a) + lift
                let end = geometry.markerPosition(for: b) + lift
                let vector = end - start
                let length = simd_length(vector)
                guard length > 1e-5 else { continue }

                let mesh = MeshResource.generateBox(width: length, height: 0.0008, depth: 0.0016)
                let segment = ModelEntity(mesh: mesh, materials: [material])
                segment.position = (start + end) / 2
                segment.orientation = simd_quatf(from: SIMD3<Float>(1, 0, 0),
                                                 to: vector / length)
                container.addChild(segment)
            }
        }
        return container
    }

    // MARK: - Markers

    private static func markers(
        highlights: [FretboardHighlight],
        geometry: FretboardGeometry,
        labelStyle: LabelStyle,
        scale: Scale? = nil,
        emphasizeAlterations: Bool = false
    ) -> Entity {
        let container = Entity()
        container.name = "markers"

        // One mesh per radius, one material per distinct color keeps entity
        // counts cheap.
        var meshCache: [Float: MeshResource] = [:]
        var materialCache: [Color: UnlitMaterial] = [:]

        for highlight in highlights {
            let radius = OverlayPalette.radius(for: highlight.role)
            let mesh = meshCache[radius] ?? {
                let m = MeshResource.generateSphere(radius: radius)
                meshCache[radius] = m
                return m
            }()
            let color = OverlayPalette.color(for: highlight, scale: scale,
                                             emphasizeAlterations: emphasizeAlterations)
            let material = materialCache[color] ?? {
                var m = UnlitMaterial(color: UIColor(color))
                m.blending = .transparent(opacity: 0.92)
                materialCache[color] = m
                return m
            }()

            let marker = ModelEntity(mesh: mesh, materials: [material])
            var position = geometry.markerPosition(for: highlight.position)
            position.y += radius * 0.6 // float just above the board surface
            marker.position = position
            container.addChild(marker)

            if let text = OverlayPalette.label(for: highlight, style: labelStyle, scale: scale) {
                marker.addChild(labelEntity(text: text, radius: radius))
            }
        }
        return container
    }

    private static func labelEntity(text: String, radius: Float) -> Entity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.0005,
            font: .systemFont(ofSize: 0.008, weight: .semibold),
            alignment: .center
        )
        let entity = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
        // Center the text above the marker; generateText origins at baseline-left.
        let bounds = entity.visualBounds(relativeTo: nil)
        entity.position = SIMD3<Float>(-bounds.extents.x / 2, radius + 0.002, 0)
        entity.components.set(BillboardComponent()) // always face the player
        return entity
    }

    // MARK: - Board wireframe

    private static func fretLines(geometry: FretboardGeometry) -> Entity {
        let container = Entity()
        container.name = "fretLines"
        let material = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.25))

        for fret in 0...geometry.fretCount {
            let x = Float(geometry.fretDistance(fret))
            let span = Float(abs(geometry.stringZ(string: 0, atX: Double(x))) * 2 + 0.006)
            let mesh = MeshResource.generateBox(width: 0.0012, height: 0.0004, depth: span)
            let line = ModelEntity(mesh: mesh, materials: [material])
            line.position = SIMD3<Float>(x, 0, 0)
            container.addChild(line)
        }
        return container
    }

    private static func stringLines(geometry: FretboardGeometry) -> Entity {
        let container = Entity()
        container.name = "stringLines"
        let material = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.18))
        let length = Float(geometry.fretDistance(geometry.fretCount))

        for string in 0..<geometry.stringCount {
            // Strings taper outward; approximate each as a straight segment
            // between its nut and last-fret positions.
            let zNut = Float(geometry.stringZ(string: string, atX: 0))
            let zEnd = Float(geometry.stringZ(string: string, atX: Double(length)))
            let mesh = MeshResource.generateBox(width: length, height: 0.0004, depth: 0.0008)
            let line = ModelEntity(mesh: mesh, materials: [material])
            let midZ = (zNut + zEnd) / 2
            line.position = SIMD3<Float>(length / 2, 0, midZ)
            line.orientation = simd_quatf(from: SIMD3<Float>(1, 0, 0),
                                          to: simd_normalize(SIMD3<Float>(length, 0, zEnd - zNut)))
            container.addChild(line)
        }
        return container
    }
}
