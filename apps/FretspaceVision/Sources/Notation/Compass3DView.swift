import SwiftUI
import RealityKit
import MusicTheory

/// The Harmony Compass as a volume: the rim (keys + relative minors) floats
/// nearest you, dominants sit a hand-depth behind it, and the diminished
/// family hub deepest — harmony's tension literally recedes into the volume.
/// Tap any chip: it sounds, and its pathways light across the depth.
struct Compass3DView: View {
    @State private var selectedID = "majorKey:0"
    @State private var pads = ChordPadEngine()
    @State private var cache = Compass3DCache()

    var body: some View {
        RealityView { content in
            let root = Entity()
            root.name = "compassRoot"
            cache.build(into: root)
            content.add(root)
        } update: { _ in
            cache.showMoves(for: selectedID)
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard let id = chipID(of: value.entity),
                          let node = Compass3DCache.node(for: id) else { return }
                    selectedID = id
                    pads.play(node.chord, durationMs: 1400)
                }
        )
    }

    /// Walk up from a tapped sub-entity (label text) to the named chip.
    private func chipID(of entity: Entity) -> String? {
        var current: Entity? = entity
        while let e = current {
            if e.name.contains(":") { return e.name }
            current = e.parent
        }
        return nil
    }
}

/// Reference-type scene cache: entities are built once and the active
/// pathway set is swapped on selection — never mutated from view state.
@MainActor
final class Compass3DCache {
    private var chips: [String: ModelEntity] = [:]
    private var movesRoot = Entity()
    private var builtSelection: String?

    static let rimRadius: Float = 0.26
    static let dominantDepth: Float = -0.08
    static let hubDepth: Float = -0.16

    static func node(for id: String) -> HarmonyWheel.Node? {
        let parts = id.split(separator: ":")
        guard parts.count == 2, let index = Int(parts[1]) else { return nil }
        let ring: HarmonyWheel.Ring? = switch parts[0] {
        case "majorKey": .majorKey
        case "relativeMinor": .relativeMinor
        case "dominant": .dominant
        case "diminished": .diminished
        default: nil
        }
        return ring.map { HarmonyWheel.node($0, index) }
    }

    static func position(of node: HarmonyWheel.Node) -> SIMD3<Float> {
        let spoke = -Float.pi / 2 + Float(node.index) * .pi * 2 / 12
        let nudge = Float.pi * 2 / 12 * 0.21
        let (angle, radius, depth): (Float, Float, Float) = switch node.ring {
        case .majorKey: (spoke - nudge, rimRadius, 0)
        case .relativeMinor: (spoke + nudge, rimRadius, 0)
        case .dominant: (spoke, rimRadius * 0.62, dominantDepth)
        case .diminished: (spoke, rimRadius * 0.34, hubDepth)
        }
        return [cos(angle) * radius, -sin(angle) * radius, depth]
    }

    private static func chipRadius(_ ring: HarmonyWheel.Ring) -> Float {
        switch ring {
        case .majorKey: 0.027
        case .relativeMinor: 0.023
        case .dominant: 0.024
        case .diminished: 0.017
        }
    }

    private static func chipColor(_ node: HarmonyWheel.Node) -> UIColor {
        switch node.ring {
        case .majorKey: UIColor(red: 0.18, green: 0.40, blue: 0.82, alpha: 1)
        case .relativeMinor: UIColor(red: 0.28, green: 0.28, blue: 0.72, alpha: 1)
        case .dominant: UIColor(red: 0.73, green: 0.47, blue: 0.09, alpha: 1)
        case .diminished:
            [UIColor(red: 0.55, green: 0.29, blue: 0.70, alpha: 1),
             UIColor(red: 0.63, green: 0.32, blue: 0.61, alpha: 1),
             UIColor(red: 0.48, green: 0.33, blue: 0.76, alpha: 1)][node.index % 3]
        }
    }

    private static func moveColor(_ move: HarmonyWheel.Move) -> UIColor {
        switch move.kind {
        case .resolve, .deceptive: UIColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1)
        case .toDominant: UIColor(red: 0.98, green: 0.57, blue: 0.24, alpha: 1)
        case .twoFive: UIColor(red: 0.37, green: 0.92, blue: 0.83, alpha: 1)
        case .soften: UIColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 1)
        case .tritoneSub: UIColor(red: 0.96, green: 0.45, blue: 0.71, alpha: 1)
        case .fifthSharpward, .fifthFlatward: UIColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1)
        case .relative: UIColor(white: 0.9, alpha: 1)
        case .passingDim, .deepen, .dimFamily: UIColor(red: 0.75, green: 0.52, blue: 0.99, alpha: 1)
        }
    }

    func build(into root: Entity) {
        // Quiet lattice: one thin gray strut per unique pair, across depth.
        let lattice = Entity()
        lattice.components.set(OpacityComponent(opacity: 0.18))
        var seen = Set<String>()
        for move in HarmonyWheel.allMoves {
            let key = [move.from.id, move.to.id].sorted().joined(separator: "|")
            guard seen.insert(key).inserted else { continue }
            lattice.addChild(Self.strut(
                from: Self.position(of: move.from), to: Self.position(of: move.to),
                radius: 0.0007, color: .white))
        }
        root.addChild(lattice)

        movesRoot = Entity()
        root.addChild(movesRoot)

        for node in HarmonyWheel.nodes {
            let radius = Self.chipRadius(node.ring)
            let chip = ModelEntity(
                mesh: .generateCylinder(height: 0.009, radius: radius),
                materials: [SimpleMaterial(color: Self.chipColor(node), isMetallic: false)])
            chip.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            chip.position = Self.position(of: node)
            chip.name = node.id
            chip.generateCollisionShapes(recursive: false)
            chip.components.set(InputTargetComponent())
            chip.components.set(HoverEffectComponent())

            let text = ModelEntity(
                mesh: .generateText(node.label, extrusionDepth: 0.0012,
                                    font: .boldSystemFont(ofSize: 0.016),
                                    alignment: .center),
                materials: [UnlitMaterial(color: .white)])
            let bounds = text.visualBounds(relativeTo: nil)
            // Text mesh grows from its baseline origin; recenter on the chip,
            // and counter-rotate so it faces the viewer.
            text.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            text.position = [-bounds.extents.x / 2, 0.0065, bounds.extents.y / 2]
            chip.addChild(text)

            chips[node.id] = chip
            root.addChild(chip)
        }
    }

    func showMoves(for id: String) {
        guard builtSelection != id, let node = Self.node(for: id) else { return }
        builtSelection = id
        movesRoot.children.removeAll()

        for move in HarmonyWheel.moves(from: node) {
            let from = Self.position(of: move.from)
            let to = Self.position(of: move.to)
            let color = Self.moveColor(move)
            movesRoot.addChild(Self.strut(from: from, to: to, radius: 0.0022, color: color))

            // Arrowhead: a small cone just before the target chip.
            let direction = simd_normalize(to - from)
            let tip = to - direction * (Self.chipRadius(move.to.ring) + 0.012)
            let cone = ModelEntity(
                mesh: .generateCone(height: 0.016, radius: 0.0065),
                materials: [SimpleMaterial(color: color, isMetallic: false)])
            cone.position = tip
            cone.orientation = simd_quatf(from: [0, 1, 0], to: direction)
            movesRoot.addChild(cone)
        }

        for (chipID, chip) in chips {
            chip.scale = chipID == id ? [1.25, 1.25, 1.25] : [1, 1, 1]
        }
    }

    private static func strut(
        from: SIMD3<Float>, to: SIMD3<Float>, radius: Float, color: UIColor
    ) -> ModelEntity {
        let span = to - from
        let length = simd_length(span)
        let strut = ModelEntity(
            mesh: .generateCylinder(height: length, radius: radius),
            materials: [UnlitMaterial(color: color)])
        strut.position = (from + to) / 2
        strut.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(span))
        return strut
    }
}
