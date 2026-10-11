import SwiftUI
import RealityKit
import MusicTheory

/// The Harmony Compass as a volume — same visual grammar as the 2D wheel
/// (graded three-hop web, pair-collapsed arrows, curved bows, chip colors),
/// with harmony's tension as gentle physical depth: rim nearest, dominants
/// behind, the diminished hub deepest. Tap a chip: it sounds, and its web
/// lights across the depth.
struct Compass3DView: View {
    @State private var selectedID = "majorKey:0"
    @State private var pads = ChordPadEngine()
    @State private var cache = Compass3DCache()

    var body: some View {
        RealityView { content in
            let root = Entity()
            cache.build(into: root)
            cache.showMoves(for: selectedID)
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

    private func chipID(of entity: Entity) -> String? {
        var current: Entity? = entity
        while let e = current {
            if e.name.contains(":") { return e.name }
            current = e.parent
        }
        return nil
    }
}

/// Entities are built once; the active web is swapped per selection.
@MainActor
final class Compass3DCache {
    private var chips: [String: ModelEntity] = [:]
    private var halo = Entity()
    private var movesRoot = Entity()
    private var builtSelection: String?

    static let rimRadius: Float = 0.27
    static let dominantDepth: Float = -0.055
    static let hubDepth: Float = -0.11

    // MARK: - Graph helpers (mirrors the 2D view's grammar)

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
        case .majorKey: 0.028
        case .relativeMinor: 0.024
        case .dominant: 0.025
        case .diminished: 0.018
        }
    }

    private static func chipColor(_ node: HarmonyWheel.Node) -> UIColor {
        switch node.ring {
        case .majorKey: UIColor(red: 0.25, green: 0.52, blue: 0.95, alpha: 1)
        case .relativeMinor: UIColor(red: 0.35, green: 0.35, blue: 0.85, alpha: 1)
        case .dominant: UIColor(red: 0.92, green: 0.62, blue: 0.18, alpha: 1)
        case .diminished:
            [UIColor(red: 0.62, green: 0.33, blue: 0.80, alpha: 1),
             UIColor(red: 0.72, green: 0.36, blue: 0.70, alpha: 1),
             UIColor(red: 0.54, green: 0.38, blue: 0.86, alpha: 1)][node.index % 3]
        }
    }

    private static func moveColor(_ move: HarmonyWheel.Move) -> UIColor {
        switch move.kind {
        case .dimFamily: chipColor(move.from)
        case .deepen, .passingDim: chipColor(move.to)
        case .resolve, .deceptive: UIColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1)
        case .toDominant: UIColor(red: 0.98, green: 0.57, blue: 0.24, alpha: 1)
        case .twoFive: UIColor(red: 0.37, green: 0.92, blue: 0.83, alpha: 1)
        case .soften: UIColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 1)
        case .tritoneSub: UIColor(red: 0.96, green: 0.45, blue: 0.71, alpha: 1)
        case .fifthSharpward, .fifthFlatward: UIColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1)
        case .relative: UIColor(white: 0.92, alpha: 1)
        }
    }

    private static func priority(_ move: HarmonyWheel.Move) -> Int {
        switch move.kind {
        case .resolve: 3
        case .deceptive: 2
        case .tritoneSub:
            move.from.ring == .dominant && move.to.ring != .dominant ? 2 : 1
        default: 1
        }
    }

    /// Three-hop graded web from a node, pair-collapsed: one curve per
    /// unordered pair at its shallowest depth, forward = highest priority.
    private static func gradedPairs(
        from start: HarmonyWheel.Node
    ) -> [(move: HarmonyWheel.Move, depth: Int, twoWay: Bool)] {
        var frontier = [start]
        var seenNodes: Set<String> = [start.id]
        var pairs: [String: (HarmonyWheel.Move, Int)] = [:]
        for depth in 1...3 {
            var next: [HarmonyWheel.Node] = []
            for node in frontier {
                for move in HarmonyWheel.moves(from: node) {
                    let key = [move.from.id, move.to.id].sorted().joined(separator: "|")
                    if let (existing, d) = pairs[key] {
                        if priority(move) > priority(existing) {
                            pairs[key] = (move, d)
                        }
                    } else {
                        pairs[key] = (move, depth)
                    }
                    if seenNodes.insert(move.to.id).inserted { next.append(move.to) }
                }
            }
            frontier = next
        }
        return pairs.values.map { (move: $0.0, depth: $0.1,
                                   twoWay: HarmonyWheel.isTwoWay($0.0)) }
    }

    // MARK: - Build

    func build(into root: Entity) {
        // Quiet lattice: a thin, slightly bowed thread per unique pair.
        let lattice = Entity()
        lattice.components.set(OpacityComponent(opacity: 0.10))
        var seen = Set<String>()
        for move in HarmonyWheel.allMoves {
            let key = [move.from.id, move.to.id].sorted().joined(separator: "|")
            guard seen.insert(key).inserted else { continue }
            addBow(to: lattice, from: Self.position(of: move.from),
                   to: Self.position(of: move.to),
                   radius: 0.0006, color: .white, segments: 6)
        }
        root.addChild(lattice)

        movesRoot = Entity()
        root.addChild(movesRoot)

        // Selection halo: a white ring that sits behind the chosen chip.
        let ring = ModelEntity(
            mesh: .generateCylinder(height: 0.002, radius: 0.034),
            materials: [UnlitMaterial(color: UIColor(white: 1, alpha: 0.9))])
        ring.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        halo = ring
        root.addChild(halo)

        for node in HarmonyWheel.nodes {
            let radius = Self.chipRadius(node.ring)
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: Self.chipColor(node))
            material.roughness = 0.35
            material.metallic = 0.15
            material.emissiveColor = .init(color: Self.chipColor(node).withAlphaComponent(0.4))
            material.emissiveIntensity = 0.35
            let chip = ModelEntity(
                mesh: .generateCylinder(height: 0.010, radius: radius),
                materials: [material])
            chip.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            chip.position = Self.position(of: node)
            chip.name = node.id
            chip.generateCollisionShapes(recursive: false)
            chip.components.set(InputTargetComponent())
            chip.components.set(HoverEffectComponent())

            let fontSize: CGFloat = node.ring == .diminished ? 0.011 : 0.014
            let text = ModelEntity(
                mesh: .generateText(node.label, extrusionDepth: 0.0008,
                                    font: .boldSystemFont(ofSize: fontSize),
                                    alignment: .center),
                materials: [UnlitMaterial(color: .white)])
            let bounds = text.visualBounds(relativeTo: nil)
            text.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            text.position = [-bounds.extents.x / 2, 0.0062, bounds.extents.y / 2]
            chip.addChild(text)

            chips[node.id] = chip
            root.addChild(chip)
        }
    }

    // MARK: - Active web

    func showMoves(for id: String) {
        guard builtSelection != id, let node = Self.node(for: id) else { return }
        builtSelection = id
        movesRoot.children.removeAll()

        // Appearance by hop, mirroring the 2D map: blaze / glow / whisper.
        let look: [Int: (opacity: Float, radius: Float, cone: Float)] = [
            1: (1.0, 0.0024, 1.0), 2: (0.5, 0.0015, 0.7), 3: (0.25, 0.0009, 0.0),
        ]

        for pair in Self.gradedPairs(from: node) {
            guard let style = look[pair.depth] else { continue }
            let from = Self.position(of: pair.move.from)
            let to = Self.position(of: pair.move.to)
            let color = Self.moveColor(pair.move)
            let group = Entity()
            group.components.set(OpacityComponent(opacity: style.opacity))

            addBow(to: group, from: from, to: to,
                   radius: style.radius, color: color,
                   segments: 10,
                   dashed: pair.move.kind == .deceptive)

            if style.cone > 0 {
                addCone(to: group, at: to, from: from,
                        inset: Self.chipRadius(pair.move.to.ring),
                        color: color, scale: style.cone)
                if pair.twoWay {
                    addCone(to: group, at: from, from: to,
                            inset: Self.chipRadius(pair.move.from.ring),
                            color: color, scale: style.cone * 0.6)
                }
            }
            movesRoot.addChild(group)
        }

        for (chipID, chip) in chips {
            chip.scale = chipID == id ? [1.18, 1.18, 1.18] : [1, 1, 1]
        }
        if let chip = chips[id] {
            halo.position = chip.position + SIMD3<Float>(0, 0, -0.004)
        }
    }

    // MARK: - Geometry

    /// A gently bowed tube (quadratic curve pulled toward the wheel center),
    /// built from short cylinder segments; optionally dashed.
    private func addBow(
        to parent: Entity, from: SIMD3<Float>, to: SIMD3<Float>,
        radius: Float, color: UIColor, segments: Int, dashed: Bool = false
    ) {
        let mid = (from + to) / 2
        let control = mid + (SIMD3<Float>(0, 0, mid.z) - mid) * 0.16
        var previous = from
        for i in 1...segments {
            let t = Float(i) / Float(segments)
            let a = simd_mix(from, control, SIMD3(repeating: t))
            let b = simd_mix(control, to, SIMD3(repeating: t))
            let point = simd_mix(a, b, SIMD3(repeating: t))
            if !dashed || i % 2 == 1 {
                let span = point - previous
                let length = simd_length(span)
                if length > 0.0001 {
                    let segment = ModelEntity(
                        mesh: .generateCylinder(height: length, radius: radius),
                        materials: [UnlitMaterial(color: color)])
                    segment.position = (previous + point) / 2
                    segment.orientation = simd_quatf(from: [0, 1, 0],
                                                     to: simd_normalize(span))
                    parent.addChild(segment)
                }
            }
            previous = point
        }
    }

    private func addCone(
        to parent: Entity, at target: SIMD3<Float>, from source: SIMD3<Float>,
        inset: Float, color: UIColor, scale: Float
    ) {
        let direction = simd_normalize(target - source)
        let cone = ModelEntity(
            mesh: .generateCone(height: 0.013 * scale, radius: 0.005 * scale),
            materials: [UnlitMaterial(color: color)])
        cone.position = target - direction * (inset + 0.010)
        cone.orientation = simd_quatf(from: [0, 1, 0], to: direction)
        parent.addChild(cone)
    }
}
