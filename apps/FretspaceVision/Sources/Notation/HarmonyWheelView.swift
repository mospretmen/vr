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
            drawMoveArrows(context: context, layout: layout)
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

    private func drawMoveArrows(context: GraphicsContext, layout: WheelLayout) {
        for move in moves {
            let from = layout.position(of: move.from)
            let to = layout.position(of: move.to)
            let style = MoveStyle.style(for: move.kind)

            var path = Path()
            path.move(to: from)
            // Bow the line toward the wheel center for an orbital feel.
            let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
            let pull: CGFloat = 0.22
            let control = CGPoint(x: mid.x + (layout.center.x - mid.x) * pull,
                                  y: mid.y + (layout.center.y - mid.y) * pull)
            path.addQuadCurve(to: to, control: control)
            context.stroke(path, with: .color(style.color.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            // Arrowhead at the destination.
            let angle = atan2(to.y - control.y, to.x - control.x)
            var head = Path()
            let tip = to
            head.move(to: tip)
            head.addLine(to: CGPoint(x: tip.x - 10 * cos(angle - 0.4),
                                     y: tip.y - 10 * sin(angle - 0.4)))
            head.addLine(to: CGPoint(x: tip.x - 10 * cos(angle + 0.4),
                                     y: tip.y - 10 * sin(angle + 0.4)))
            head.closeSubpath()
            context.fill(head, with: .color(style.color))
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

            let fill: Color = isSelected ? .orange
                : isDestination ? Color.white.opacity(0.95)
                : Color.white.opacity(0.14)
            let textColor: Color = (isSelected || isDestination) ? .black : .white.opacity(0.75)

            let rect = CGRect(x: position.x - radius, y: position.y - radius,
                              width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(fill))
            if isDestination {
                context.stroke(Path(ellipseIn: rect.insetBy(dx: -2.5, dy: -2.5)),
                               with: .color(.orange.opacity(0.8)), lineWidth: 2)
            }
            context.draw(
                Text(node.label)
                    .font(.system(size: radius * 0.62, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor),
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
        minorRadius = r * 0.76
        dominantRadius = r * 0.52
        hubRadius = r * 0.22
    }

    func angle(forSpoke index: Int) -> CGFloat {
        -.pi / 2 + CGFloat(index) * (.pi * 2 / 12)
    }

    func position(of node: HarmonyWheel.Node) -> CGPoint {
        switch node.ring {
        case .majorKey: point(angle: angle(forSpoke: node.index), radius: majorRadius)
        case .relativeMinor: point(angle: angle(forSpoke: node.index), radius: minorRadius)
        case .dominant: point(angle: angle(forSpoke: node.index), radius: dominantRadius)
        case .diminished:
            point(angle: -.pi / 2 + CGFloat(node.index) * (.pi * 2 / 3) + .pi / 12,
                  radius: hubRadius)
        }
    }

    func chipRadius(for ring: HarmonyWheel.Ring) -> CGFloat {
        switch ring {
        case .majorKey: 26
        case .relativeMinor: 21
        case .dominant: 21
        case .diminished: 24
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
        .init(kind: .fifthSharpward, color: .blue, label: "Fifth ♯"),
        .init(kind: .fifthFlatward, color: .teal, label: "Fifth ♭"),
        .init(kind: .relative, color: .yellow, label: "Relative"),
        .init(kind: .leadingTone, color: .mint, label: "Leading tone"),
        .init(kind: .flatNine, color: .purple, label: "7♭9 ↔ dim"),
    ]

    static func style(for kind: HarmonyWheel.MoveKind) -> MoveStyle {
        ordered.first { $0.kind == kind } ?? ordered[0]
    }
}
