import SwiftUI
import MusicTheory

/// The harmony compass window: three concentric rings (keys + relative
/// minors, their dominants, the diminished hubs) with directional move
/// arrows from the selected chord. Tap a chord to stand on it; tap a lit
/// destination to travel — the breadcrumb below becomes your progression.
struct HarmonyWheelView: View {
    @State private var selected: HarmonyWheel.Node = HarmonyWheel.node(.majorKey, 0)
    @State private var path: [HarmonyWheel.Node] = [HarmonyWheel.node(.majorKey, 0)]

    private var moves: [HarmonyWheel.Move] { HarmonyWheel.moves(from: selected) }

    /// The onward web: moves graded by distance from the selected chord.
    /// Depth 1 blazes, depth 2 glows, depth 3 whispers — so standing on C
    /// you see C→E7, then E7→Am / Am→E7 / E7→G♯°7, then the dim family
    /// arcs beyond, each with direction arrows.
    private var gradedMoves: [(move: HarmonyWheel.Move, depth: Int)] {
        var graded: [(HarmonyWheel.Move, Int)] = []
        var seenEdges = Set<String>()
        var frontier: Set<HarmonyWheel.Node> = [selected]
        var visited: Set<HarmonyWheel.Node> = [selected]

        for depth in 1...3 {
            var next: Set<HarmonyWheel.Node> = []
            for node in frontier {
                for move in HarmonyWheel.moves(from: node) {
                    let key = move.from.id + ">" + move.to.id
                    guard seenEdges.insert(key).inserted else { continue }
                    graded.append((move, depth))
                    if !visited.contains(move.to) { next.insert(move.to) }
                }
            }
            visited.formUnion(next)
            frontier = next
        }
        return graded
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            GeometryReader { proxy in
                wheel(size: proxy.size)
            }
            breadcrumb
        }
        .padding(20)
    }

    private var header: some View {
        HStack {
            Text("Harmony Compass").font(.title.bold())
            Spacer()
            legend
        }
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(MoveStyle.ordered, id: \.kind) { style in
                HStack(spacing: 3) {
                    Circle().fill(style.color).frame(width: 8, height: 8)
                    Text(style.label).font(.caption2)
                }
            }
        }
        .foregroundStyle(.secondary)
    }

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(path.enumerated()), id: \.offset) { index, node in
                        if index > 0 { Image(systemName: "arrow.right").font(.caption2) }
                        Text(node.label)
                            .font(.callout.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: .capsule)
                    }
                }
            }
            if path.count > 1 {
                Button("Clear") {
                    path = [selected]
                }
                .font(.caption)
            }
        }
        .frame(height: 36)
    }

    // MARK: - Wheel

    private func wheel(size: CGSize) -> some View {
        let layout = WheelLayout(size: size)
        return Canvas { context, _ in
            drawRingGuides(context: context, layout: layout)
            drawLattice(context: context, layout: layout)
            drawActiveMoves(context: context, layout: layout)
            drawNodes(context: context, layout: layout)
        }
        .gesture(
            SpatialTapGesture().onEnded { value in
                handleTap(at: value.location, layout: layout)
            }
        )
    }

    private func handleTap(at point: CGPoint, layout: WheelLayout) {
        guard let node = layout.node(at: point) else { return }
        let isDestination = moves.contains { $0.to == node }
        selected = node
        if isDestination {
            path.append(node)
        } else {
            path = [node] // jumped somewhere unrelated: start a new journey
        }
    }

    private func drawRingGuides(context: GraphicsContext, layout: WheelLayout) {
        for radius in [layout.majorRadius, layout.dominantRadius, layout.hubRadius] {
            let rect = CGRect(x: layout.center.x - radius, y: layout.center.y - radius,
                              width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect),
                           with: .color(.white.opacity(0.08)), lineWidth: 1)
        }
    }

    /// Every pathway in the wheel, always visible — thin, kind-colored, no
    /// arrowheads. Mirror-image pairs draw once.
    private func drawLattice(context: GraphicsContext, layout: WheelLayout) {
        var drawn = Set<String>()
        for move in HarmonyWheel.allMoves {
            let pairKey = [move.from.id, move.to.id].sorted().joined(separator: "|")
                + move.kind.rawValue
            guard drawn.insert(pairKey).inserted else { continue }
            let style = MoveStyle.style(for: move.kind)
            context.stroke(
                curve(from: move.from, to: move.to, layout: layout),
                with: .color(style.color.opacity(0.16)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
        }
    }

    /// The onward web from the selected chord: deeper hops draw first so
    /// nearer futures sit on top; every highlighted edge carries an arrow.
    private func drawActiveMoves(context: GraphicsContext, layout: WheelLayout) {
        let appearance: [Int: (opacity: Double, width: CGFloat, head: CGFloat)] = [
            1: (0.95, 3.0, 11),
            2: (0.55, 2.0, 8),
            3: (0.28, 1.5, 6),
        ]
        for (move, depth) in gradedMoves.sorted(by: { $0.depth > $1.depth }) {
            guard let look = appearance[depth] else { continue }
            let style = MoveStyle.style(for: move.kind)
            let path = curve(from: move.from, to: move.to, layout: layout)
            context.stroke(path, with: .color(style.color.opacity(look.opacity)),
                           style: StrokeStyle(lineWidth: look.width, lineCap: .round))

            let to = layout.position(of: move.to)
            let control = controlPoint(from: layout.position(of: move.from),
                                       to: to, layout: layout)
            let angle = atan2(to.y - control.y, to.x - control.x)
            var head = Path()
            head.move(to: to)
            head.addLine(to: CGPoint(x: to.x - look.head * cos(angle - 0.4),
                                     y: to.y - look.head * sin(angle - 0.4)))
            head.addLine(to: CGPoint(x: to.x - look.head * cos(angle + 0.4),
                                     y: to.y - look.head * sin(angle + 0.4)))
            head.closeSubpath()
            context.fill(head, with: .color(style.color.opacity(look.opacity)))
        }
    }

    private func controlPoint(from: CGPoint, to: CGPoint, layout: WheelLayout) -> CGPoint {
        // Bow the line toward the wheel center for an orbital feel.
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let pull: CGFloat = 0.22
        return CGPoint(x: mid.x + (layout.center.x - mid.x) * pull,
                       y: mid.y + (layout.center.y - mid.y) * pull)
    }

    private func curve(from: HarmonyWheel.Node, to: HarmonyWheel.Node,
                       layout: WheelLayout) -> Path {
        let a = layout.position(of: from)
        let b = layout.position(of: to)
        var path = Path()
        path.move(to: a)
        path.addQuadCurve(to: b, control: controlPoint(from: a, to: b, layout: layout))
        return path
    }

    /// Ring-identity chip color: keys blue, relatives indigo, dominants
    /// amber. Diminished chips tint by enharmonic family, so the three
    /// four-note families read as three threads woven through the inner
    /// ring.
    private func chipColor(for node: HarmonyWheel.Node) -> Color {
        switch node.ring {
        case .majorKey: return Color(red: 0.25, green: 0.52, blue: 0.95)
        case .relativeMinor: return Color(red: 0.42, green: 0.36, blue: 0.85)
        case .dominant: return Color(red: 0.92, green: 0.58, blue: 0.18)
        case .diminished:
            switch HarmonyWheel.family(ofDiminishedAt: node.index) {
            case 0: return Color(red: 0.62, green: 0.30, blue: 0.86)
            case 1: return Color(red: 0.82, green: 0.30, blue: 0.70)
            default: return Color(red: 0.48, green: 0.36, blue: 0.95)
            }
        }
    }

    private func drawNodes(context: GraphicsContext, layout: WheelLayout) {
        let destinations = Set(moves.map(\.to))
        for node in HarmonyWheel.nodes {
            let position = layout.position(of: node)
            let isSelected = node == selected
            let isDestination = destinations.contains(node)
            let radius = layout.chipRadius(for: node.ring)
                * (isSelected ? 1.25 : 1.0)

            let base = chipColor(for: node)
            let fill = base.opacity(isSelected ? 1.0 : isDestination ? 0.95 : 0.3)

            let rect = CGRect(x: position.x - radius, y: position.y - radius,
                              width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(fill))
            if isSelected {
                context.stroke(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)),
                               with: .color(.white), lineWidth: 3)
            } else if isDestination {
                context.stroke(Path(ellipseIn: rect.insetBy(dx: -2.5, dy: -2.5)),
                               with: .color(.white.opacity(0.9)), lineWidth: 2)
            }
            context.draw(
                Text(node.label)
                    .font(.system(size: radius * 0.62,
                                  weight: (isSelected || isDestination) ? .bold : .medium,
                                  design: .rounded))
                    .foregroundStyle(.white.opacity(
                        isSelected || isDestination ? 1.0 : 0.75)),
                at: position
            )
        }
    }
}

/// Geometry: fifths order around the clock (C at 12), minors tucked inside
/// their majors, dominants on the third ring, the three hubs orbiting the
/// center.
private struct WheelLayout {
    let center: CGPoint
    let majorRadius: CGFloat
    let minorRadius: CGFloat
    let dominantRadius: CGFloat
    let hubRadius: CGFloat

    init(size: CGSize) {
        center = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = min(size.width, size.height) / 2 - 30
        majorRadius = r
        minorRadius = r // pairs share the outer ring
        dominantRadius = r * 0.62
        hubRadius = r * 0.34
    }

    func angle(forSpoke index: Int) -> CGFloat {
        -.pi / 2 + CGFloat(index) * (.pi * 2 / 12)
    }

    /// The major sits a nudge counterclockwise of its column's spoke and
    /// the relative minor a nudge clockwise — side by side on the SAME
    /// ring, touching distance. Dominant and diminished stack straight
    /// below on the spoke line.
    func position(of node: HarmonyWheel.Node) -> CGPoint {
        let pairNudge: CGFloat = .pi * 2 / 12 * 0.21
        switch node.ring {
        case .majorKey:
            return point(angle: angle(forSpoke: node.index) - pairNudge, radius: majorRadius)
        case .relativeMinor:
            return point(angle: angle(forSpoke: node.index) + pairNudge, radius: majorRadius)
        case .dominant:
            return point(angle: angle(forSpoke: node.index), radius: dominantRadius)
        case .diminished:
            return point(angle: angle(forSpoke: node.index), radius: hubRadius)
        }
    }

    func chipRadius(for ring: HarmonyWheel.Ring) -> CGFloat {
        switch ring {
        case .majorKey: 24
        case .relativeMinor: 20
        case .dominant: 21
        case .diminished: 17
        }
    }

    func node(at point: CGPoint) -> HarmonyWheel.Node? {
        HarmonyWheel.nodes
            .map { ($0, hypot(position(of: $0).x - point.x, position(of: $0).y - point.y)) }
            .filter { $0.1 < chipRadius(for: $0.0.ring) + 10 }
            .min { $0.1 < $1.1 }?.0
    }

    private func point(angle: CGFloat, radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius)
    }
}

/// Color + label language for move kinds.
private struct MoveStyle {
    let kind: HarmonyWheel.MoveKind
    let color: Color
    let label: String

    static let ordered: [MoveStyle] = [
        .init(kind: .resolve, color: .green, label: "Resolve"),
        .init(kind: .toDominant, color: .orange, label: "To V7"),
        .init(kind: .relative, color: .yellow, label: "Relative"),
        .init(kind: .twoFive, color: .mint, label: "ii–V"),
        .init(kind: .fifthSharpward, color: .blue, label: "Fifth ♯"),
        .init(kind: .fifthFlatward, color: .teal, label: "Fifth ♭"),
        .init(kind: .deepen, color: .purple, label: "V7 → dim"),
        .init(kind: .dimFamily, color: .pink, label: "Dim family"),
    ]

    static func style(for kind: HarmonyWheel.MoveKind) -> MoveStyle {
        ordered.first { $0.kind == kind } ?? ordered[0]
    }
}
