import SwiftUI
import MusicTheory

/// The harmony compass window: three concentric rings (keys + relative
/// minors, their dominants, the diminished hubs) with directional move
/// arrows from the selected chord. Tap a chord to stand on it; tap a lit
/// destination to travel — the breadcrumb below becomes your progression.
struct HarmonyWheelView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppModel.self) private var model

    /// Debug screenshot tour: `simctl launch … -tour windows|3d` opens the
    /// showcase windows automatically so the simulator can be photographed.
    private func runTourIfRequested() {
        guard let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-tour"),
              ProcessInfo.processInfo.arguments.count > i + 1 else { return }
        let mode = ProcessInfo.processInfo.arguments[i + 1]
        if mode == "windows" || mode == "all" {
            model.presentedScale = Scale(root: .c, type: .melodicMinor)
            model.presentedChord = Chord(root: .g, quality: .dominant7)
            openWindow(id: SceneID.scaleDetail, value: 0)
            openWindow(id: SceneID.chordDetail, value: 0)
        }
    }
    @State private var selected: HarmonyWheel.Node = HarmonyWheel.node(.majorKey, 0)
    @State private var path: [HarmonyWheel.Node] = Self.restoredPath()
    @State private var walkTask: Task<Void, Never>? = nil
    /// First-launch guided walk; nil once completed or skipped.
    @State private var onboardingStep: Int? =
        UserDefaults.standard.bool(forKey: "compass.onboarded") ? nil : 0

    private static func restoredPath() -> [HarmonyWheel.Node] {
        let ids = UserDefaults.standard.stringArray(forKey: "compass.path") ?? []
        let nodes = ids.compactMap(Self.node(for:))
        return nodes.isEmpty ? [HarmonyWheel.node(.majorKey, 0)] : nodes
    }

    private static func node(for id: String) -> HarmonyWheel.Node? {
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

    /// Perform the walked path: each chord strums as its chip relights —
    /// your journey played back as a progression.
    private func playWalk() {
        walkTask?.cancel()
        let steps = path
        walkTask = Task { @MainActor in
            for (index, node) in steps.enumerated() {
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.2)) { selected = node }
                pads.playVoicing(
                    [Note(node.chord.root, octave: 3)]
                        + node.chord.pitchClasses.map { Note($0, octave: 4) },
                    durationMs: 780, restart: index == 0)
                try? await Task.sleep(nanoseconds: 820_000_000)
            }
        }
    }
    /// The column you harmonically live in — its neighborhood (which holds
    /// all its diatonic chords) is haloed. Modulation = moving this.
    @State private var keyCenter: Int =
        UserDefaults.standard.integer(forKey: "compass.keyCenter")
    @State private var keyIsMinor =
        UserDefaults.standard.bool(forKey: "compass.keyIsMinor")

    /// The tonic the wheel is currently read from — spelling follows it.
    private var frameTonic: PitchClass {
        let major = HarmonyWheel.spokes[keyCenter]
        return keyIsMinor ? major.transposed(by: -3) : major
    }
    /// Pathway families switched off via the tappable legend.
    @State private var hiddenKinds: Set<HarmonyWheel.MoveKind> = Set(
        (UserDefaults.standard.stringArray(forKey: "compass.hiddenKinds") ?? [])
            .compactMap(HarmonyWheel.MoveKind.init(rawValue:)))
    /// Tap a chord, hear the chord — same synth as the backing pads.
    @State private var pads = ChordPadEngine()

    private var moves: [HarmonyWheel.Move] { HarmonyWheel.moves(from: selected) }

    /// The onward web: moves graded by distance from the selected chord.
    /// Depth 1 blazes, depth 2 glows, depth 3 whispers — so standing on C
    /// you see C→E7, then E7→Am / Am→E7 / E7→G♯°7, then the dim family
    /// arcs beyond, each with direction arrows.
    private var gradedMoves: [(move: HarmonyWheel.Move, depth: Int)] {
        var graded: [(HarmonyWheel.Move, Int)] = []
        // Standing on a diminished chip, its whole family clique is depth 1:
        // the four chips are the same chord, so all their links are "here".
        var familyPromote = Set<String>()
        if selected.ring == .diminished {
            for offset in [0, 3, 6, 9] {
                let member = HarmonyWheel.node(.diminished, (selected.index + offset) % 12)
                for move in HarmonyWheel.moves(from: member) where move.kind == .dimFamily {
                    familyPromote.insert(move.from.id + ">" + move.to.id)
                }
            }
        }
        var seenEdges = Set<String>()
        var frontier: Set<HarmonyWheel.Node> = [selected]
        var visited: Set<HarmonyWheel.Node> = [selected]

        for depth in 1...3 {
            var next: Set<HarmonyWheel.Node> = []
            for node in frontier {
                for move in HarmonyWheel.moves(from: node) {
                    let key = move.from.id + ">" + move.to.id
                    guard seenEdges.insert(key).inserted else { continue }
                    graded.append((move, familyPromote.contains(key) ? 1 : depth))
                    if !visited.contains(move.to) { next.insert(move.to) }
                }
            }
            visited.formUnion(next)
            frontier = next
        }
        for move in HarmonyWheel.allMoves {
            let key = move.from.id + ">" + move.to.id
            if familyPromote.contains(key), seenEdges.insert(key).inserted {
                graded.append((move, 1))
            }
        }
        return graded
    }

    var body: some View {
        VStack(spacing: 12) {
            header
                .onAppear { runTourIfRequested() }
            HStack(alignment: .top, spacing: 14) {
                GeometryReader { proxy in
                    wheel(size: proxy.size)
                }
                HarmonyContextCard(selected: selected, moves: moves,
                                   frameTonic: frameTonic,
                                   keyCenter: keyCenter,
                                   keyIsMinor: keyIsMinor,
                                   onSetKey: { column, minor in
                                       select(HarmonyWheel.node(
                                           minor ? .relativeMinor : .majorKey,
                                           column))
                                   },
                                   moveColor: { self.moveColor($0) },
                                   onSelectScale: { scale in
                                       model.presentedScale = scale
                                       openWindow(id: SceneID.scaleDetail, value: 0)
                                   },
                                   onShowVoicings: {
                                       model.presentedChord = selected.chord
                                       openWindow(id: SceneID.chordDetail, value: 0)
                                   },
                                   onHearChord: { pads.play($0, durationMs: 1400) },
                                   onOpenChord: { chord in
                                       model.presentedChord = chord
                                       openWindow(id: SceneID.chordDetail, value: 0)
                                   },
                                   onHearProgression: { pads.playProgression($0) })
            }
            breadcrumb
        }
        .padding(20)
        .overlay(alignment: .bottom) {
            if let step = onboardingStep {
                onboardingCard(step: step)
                    .padding(.bottom, 52)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: selected) {
            guard let step = onboardingStep else { return }
            if step == 0, selected.id == "dominant:9" {
                withAnimation { onboardingStep = 1 }
            } else if step == 1, selected.id == "majorKey:0" {
                withAnimation { onboardingStep = 2 }
            }
        }
        .onChange(of: keyCenter) {
            UserDefaults.standard.set(keyCenter, forKey: "compass.keyCenter")
        }
        .onChange(of: keyIsMinor) {
            UserDefaults.standard.set(keyIsMinor, forKey: "compass.keyIsMinor")
        }
        .onChange(of: path) {
            UserDefaults.standard.set(path.map(\.id), forKey: "compass.path")
        }
        .onChange(of: hiddenKinds) {
            UserDefaults.standard.set(hiddenKinds.map(\.rawValue).sorted(),
                                      forKey: "compass.hiddenKinds")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Harmony Compass").font(.title.bold())
                Text(BuildStamp.value)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            keyCenterBadge
            Spacer()
            utilityBar
            legend
        }
    }

    private func onboardingCard(step: Int) -> some View {
        let lines = [
            "Welcome. This wheel is a map of harmony — every chord, every road. "
                + "Start by tapping G7, the orange chip below C.",
            "That pull you hear is tension. The green pathway shows where it "
                + "wants to go — tap C to let it land.",
            "Home again. Tap the pathway text on the right to watch the voices "
                + "move — then wander anywhere. Every road explains itself.",
        ]
        return HStack(spacing: 12) {
            Text(lines[min(step, lines.count - 1)])
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            if step >= 2 {
                Button("Let's play") { finishOnboarding() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Skip") { finishOnboarding() }
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(maxWidth: 560)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
    }

    private func finishOnboarding() {
        withAnimation { onboardingStep = nil }
        UserDefaults.standard.set(true, forKey: "compass.onboarded")
    }

    /// Everything that used to live on the main menu, one tap away.
    private var utilityBar: some View {
        HStack(spacing: 10) {
            Button {
                openWindow(id: SceneID.phrases, value: 0)
            } label: {
                Label("Phrases", systemImage: "music.quarternote.3")
            }
        }
        .buttonStyle(.bordered)
        .font(.callout)
    }

    private var keyCenterBadge: some View {
        HStack(spacing: 8) {
            Text(keyIsMinor
                 ? "Key: \(HarmonyWheel.node(.relativeMinor, keyCenter).label) · rel. \(HarmonyWheel.node(.majorKey, keyCenter).label)"
                 : "Key: \(HarmonyWheel.node(.majorKey, keyCenter).label) · rel. \(HarmonyWheel.node(.relativeMinor, keyCenter).label)")
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.blue.opacity(0.25), in: .capsule)
        }
    }

    /// The legend doubles as the pathway mixer: tap a family to hide or
    /// show its lines. Two tidy fixed-size rows — never wrapped syllables.
    private var legend: some View {
        let rows = MoveStyle.legendRows
        let split = (rows.count + 1) / 2
        return VStack(alignment: .trailing, spacing: 3) {
            legendRow(Array(rows.prefix(split)))
            HStack(spacing: 10) {
                legendRow(Array(rows.dropFirst(split)))
                if hiddenKinds.isEmpty {
                    Text("tap to filter").font(.caption2).fixedSize()
                } else {
                    Button {
                        hiddenKinds = []
                    } label: {
                        Text("Show all")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.orange.opacity(0.35), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(.secondary)
    }

    private func legendRow(_ rows: [(color: Color, label: String, kinds: Set<HarmonyWheel.MoveKind>)]) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                let off = row.kinds.allSatisfy { hiddenKinds.contains($0) }
                Button {
                    if off {
                        hiddenKinds.subtract(row.kinds)
                    } else {
                        hiddenKinds.formUnion(row.kinds)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Circle().fill(row.color).frame(width: 8, height: 8)
                        Text(row.label).font(.caption2).fixedSize()
                            .strikethrough(off, color: .secondary)
                    }
                    .opacity(off ? 0.35 : 1)
                }
                .buttonStyle(.plain)
            }
        }
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
                Button {
                    playWalk()
                } label: {
                    Label("Play walk", systemImage: "play.fill")
                }
                .font(.caption)
                .buttonStyle(.bordered)
                Button("Clear") {
                    walkTask?.cancel()
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
            drawKeyCenterHalo(context: context, layout: layout)
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
        select(node)
    }

    /// The one selection routine — wheel taps and the card's key switcher
    /// both land here, so every surface (staff, pathways, numerals, halo,
    /// breadcrumb, sound) moves together.
    private func select(_ node: HarmonyWheel.Node) {
        let isDestination = moves.contains { $0.to == node }
        selected = node
        pads.play(node.chord, durationMs: 1400)
        // Degrees re-reference to whatever key you stand on; dominants and
        // diminisheds are transitional and keep the current frame.
        if node.ring == .majorKey || node.ring == .relativeMinor {
            withAnimation(.easeInOut(duration: 0.3)) {
                keyCenter = node.index
                keyIsMinor = node.ring == .relativeMinor
            }
        }
        if isDestination {
            path.append(node)
        } else {
            path = [node] // jumped somewhere unrelated: start a new journey
        }
    }

    /// The key center's home territory: a soft wedge over its column and
    /// the neighbors either side — together they hold every diatonic chord
    /// of the key (for C: F·Dm | C·Am | G·Em, plus G7 and the dim below).
    private func drawKeyCenterHalo(context: GraphicsContext, layout: WheelLayout) {
        let spokeWidth: CGFloat = .pi * 2 / 12
        let outer = layout.majorRadius + 34
        let inner = layout.hubRadius - 26

        for offset in -1...1 {
            let column = ((keyCenter + offset) % 12 + 12) % 12
            let mid = layout.angle(forSpoke: column)
            let halfSpan = spokeWidth / 2 * (offset == 0 ? 0.98 : 0.88)
            var sector = Path()
            sector.addArc(center: layout.center, radius: outer,
                          startAngle: .radians(mid - halfSpan),
                          endAngle: .radians(mid + halfSpan), clockwise: false)
            sector.addArc(center: layout.center, radius: inner,
                          startAngle: .radians(mid + halfSpan),
                          endAngle: .radians(mid - halfSpan), clockwise: true)
            sector.closeSubpath()
            let strength = offset == 0 ? 0.10 : 0.05
            context.fill(sector, with: .color(.blue.opacity(strength)))
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

    /// A clip that excludes every chip disk, so pathway strokes never draw
    /// across chords they merely pass by (their own endpoints dock at the
    /// borders, outside the holes).
    private func edgeContext(_ context: GraphicsContext, layout: WheelLayout) -> GraphicsContext {
        var clipped = context
        var holes = Path()
        holes.addRect(CGRect(x: -10_000, y: -10_000, width: 20_000, height: 20_000))
        for node in HarmonyWheel.nodes {
            let p = layout.position(of: node)
            let r = layout.chipRadius(for: node.ring) + 1.5
            holes.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
        clipped.clip(to: holes, style: FillStyle(eoFill: true))
        return clipped
    }

    /// The color a move draws in: diminished pathways inherit their
    /// family's chip tint (three colored threads through the center);
    /// everything else uses its kind color.
    private func moveColor(_ move: HarmonyWheel.Move) -> Color {
        switch move.kind {
        case .dimFamily:
            return chipColor(for: move.from)
        case .deepen, .passingDim:
            return chipColor(for: move.to)
        default:
            return MoveStyle.style(for: move.kind).color
        }
    }

    /// Every pathway, always visible — but NEUTRAL until relevant: a quiet
    /// gray web. Color belongs to the selected chord's onward moves.
    private func drawLattice(context: GraphicsContext, layout: WheelLayout) {
        let ctx = edgeContext(context, layout: layout)
        var drawn = Set<String>()
        for move in HarmonyWheel.allMoves {
            let pairKey = [move.from.id, move.to.id].sorted().joined(separator: "|")
            guard drawn.insert(pairKey).inserted else { continue }
            ctx.stroke(
                curve(from: move.from, to: move.to, layout: layout),
                with: .color(.white.opacity(0.10)),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
            )
        }
    }

    /// One rendered stroke per connected PAIR in the onward web. The big
    /// arrowhead follows harmonic priority — a resolution always owns it
    /// (G7→C gets the big green head into C even while you stand on C);
    /// the lesser direction shows as a smaller counter-head in its own
    /// kind color. One-way streets keep a single head. Deceptive motion
    /// draws dashed.
    private func drawActiveMoves(context: GraphicsContext, layout: WheelLayout) {
        // Calm grading: the selected chord blazes, the second hop hints,
        // the third barely breathes — the wheel must never read as a web
        // of everything (owner: "cluttered").
        let appearance: [Int: (opacity: Double, width: CGFloat, head: CGFloat)] = [
            1: (1.0, 4.5, 16),
            2: (0.30, 2.2, 9),
            3: (0.10, 1.2, 0),
        ]
        func priority(_ move: HarmonyWheel.Move) -> Int {
            switch move.kind {
            case .resolve: return 3
            case .deceptive: return 2
            case .tritoneSub, .backdoor:
                // The resolution side (into the key) owns the big head;
                // the outbound side is the lesser arrow.
                return move.from.ring == .dominant && move.to.ring != .dominant ? 2 : 1
            default: return 1
            }
        }

        // Group graded moves by unordered pair; keep the shallowest depth.
        struct PairInfo {
            var forward: HarmonyWheel.Move
            var backward: HarmonyWheel.Move?
            var depth: Int
        }
        var pairs: [String: PairInfo] = [:]
        for (move, depth) in gradedMoves where !hiddenKinds.contains(move.kind) {
            let key = [move.from.id, move.to.id].sorted().joined(separator: "|")
            if var info = pairs[key] {
                info.depth = min(info.depth, depth)
                if move.to.id == info.forward.from.id, info.backward == nil {
                    info.backward = move
                } else if priority(move) > priority(info.forward) {
                    info.backward = info.forward
                    info.forward = move
                }
                pairs[key] = info
            } else {
                pairs[key] = PairInfo(forward: move, backward: nil, depth: depth)
            }
        }
        // Promote: the higher-priority direction owns the big head.
        for (key, info) in pairs {
            if let back = info.backward, priority(back) > priority(info.forward) {
                pairs[key] = PairInfo(forward: back, backward: info.forward, depth: info.depth)
            }
        }

        let ctx = edgeContext(context, layout: layout)
        for info in pairs.values.sorted(by: { $0.depth > $1.depth }) {
            guard let look = appearance[info.depth] else { continue }
            let move = info.forward
            let mainColor = moveColor(move).opacity(look.opacity)
            let g = edgeGeometry(from: move.from, to: move.to, layout: layout)

            var strokeStyle = StrokeStyle(lineWidth: look.width, lineCap: .round)
            if move.kind == .deceptive { strokeStyle.dash = [9, 7] }
            ctx.stroke(g.path, with: .color(mainColor), style: strokeStyle)

            // Big head: the primary (most-resolved) direction of travel.
            arrowhead(context: context, tip: g.end, angle: g.endAngle,
                      size: look.head, color: mainColor)

            // Smaller counter-head in the SAME color as its stroke, so the
            // pair reads as one coherent two-way line.
            if info.backward != nil {
                arrowhead(context: context, tip: g.start, angle: g.startBackAngle,
                          size: look.head * 0.7, color: mainColor)
            }
        }
    }

    private func arrowhead(context: GraphicsContext, tip: CGPoint,
                           angle: CGFloat, size: CGFloat, color: Color) {
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: tip.x - size * cos(angle - 0.4),
                                 y: tip.y - size * sin(angle - 0.4)))
        head.addLine(to: CGPoint(x: tip.x - size * cos(angle + 0.4),
                                 y: tip.y - size * sin(angle + 0.4)))
        head.closeSubpath()
        context.fill(head, with: .color(color))
    }

    private func controlPoint(from: CGPoint, to: CGPoint, layout: WheelLayout) -> CGPoint {
        // Bow the line toward the wheel center for an orbital feel.
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let pull: CGFloat = 0.22
        return CGPoint(x: mid.x + (layout.center.x - mid.x) * pull,
                       y: mid.y + (layout.center.y - mid.y) * pull)
    }

    /// Edge geometry trimmed along the ACTUAL curve: endpoints land where
    /// the bowed line truly crosses each chip's border, and arrowhead
    /// angles come from the curve's real tangents — so heads always sit
    /// exactly on the stroke.
    private struct EdgeGeometry {
        let path: Path
        let start: CGPoint
        let startBackAngle: CGFloat // pointing back into the source chip
        let end: CGPoint
        let endAngle: CGFloat       // direction of travel at the destination
    }

    private func edgeGeometry(
        from: HarmonyWheel.Node, to: HarmonyWheel.Node, layout: WheelLayout
    ) -> EdgeGeometry {
        let p0 = layout.position(of: from)
        let p1 = layout.position(of: to)
        let c = controlPoint(from: p0, to: p1, layout: layout)

        func point(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
                           y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y)
        }
        func tangentAngle(_ t: CGFloat) -> CGFloat {
            let dx = 2 * (1 - t) * (c.x - p0.x) + 2 * t * (p1.x - c.x)
            let dy = 2 * (1 - t) * (c.y - p0.y) + 2 * t * (p1.y - c.y)
            return atan2(dy, dx)
        }

        let rFrom = layout.chipRadius(for: from.ring) + 3
        let rTo = layout.chipRadius(for: to.ring) + 3
        let samples = 64
        var t0: CGFloat = 0
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            if hypot(point(t).x - p0.x, point(t).y - p0.y) >= rFrom { t0 = t; break }
            t0 = t
        }
        var t1: CGFloat = 1
        for i in stride(from: samples, through: 0, by: -1) {
            let t = CGFloat(i) / CGFloat(samples)
            if hypot(point(t).x - p1.x, point(t).y - p1.y) >= rTo { t1 = t; break }
            t1 = t
        }
        // Short edges (touching pair chips): keep a visible middle stub.
        t0 = min(t0, 0.42)
        t1 = max(t1, 0.58)

        var path = Path()
        path.move(to: point(t0))
        let steps = 16
        for i in 1...steps {
            path.addLine(to: point(t0 + (t1 - t0) * CGFloat(i) / CGFloat(steps)))
        }

        return EdgeGeometry(
            path: path,
            start: point(t0),
            startBackAngle: tangentAngle(t0) + .pi,
            end: point(t1),
            endAngle: tangentAngle(t1)
        )
    }

    private func curve(from: HarmonyWheel.Node, to: HarmonyWheel.Node,
                       layout: WheelLayout) -> Path {
        edgeGeometry(from: from, to: to, layout: layout).path
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
                Text(HarmonyWheel.functionalLabel(for: node, inKeyFrame: frameTonic))
                    .font(.system(size: radius * 0.62,
                                  weight: (isSelected || isDestination) ? .bold : .medium,
                                  design: .rounded))
                    .foregroundStyle(.white.opacity(
                        isSelected || isDestination ? 1.0 : 0.75)),
                at: position
            )

            // Roman-numeral function relative to the key center, floated
            // just outside the chip along its radial.
            let numeral = keyIsMinor
                ? HarmonyWheel.romanNumeral(
                    for: node,
                    inMinorKey: HarmonyWheel.spokes[keyCenter].transposed(by: -3))
                : HarmonyWheel.romanNumeral(
                    for: node, inKey: HarmonyWheel.spokes[keyCenter])
            let dx = position.x - layout.center.x
            let dy = position.y - layout.center.y
            let dist = max(hypot(dx, dy), 0.001)
            let numeralPos = CGPoint(
                x: position.x + dx / dist * (radius + 11),
                y: position.y + dy / dist * (radius + 11))
            let isDiatonic = !numeral.contains("/") && !numeral.contains("♭")
            context.draw(
                Text(numeral)
                    .font(.system(size: 11, weight: isDiatonic ? .bold : .regular))
                    .foregroundStyle(.white.opacity(isDiatonic ? 0.85 : 0.45)),
                at: numeralPos
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
        // Chips extend ~42pt past the ring line (24pt chip + numeral at
        // +11 + text height), so the margin must clear all of it.
        let r = min(size.width, size.height) / 2 - 48
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
        var best: HarmonyWheel.Node? = nil
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for node in HarmonyWheel.nodes {
            let p = position(of: node)
            let distance = hypot(p.x - point.x, p.y - point.y)
            if distance < chipRadius(for: node.ring) + 10, distance < bestDistance {
                best = node
                bestDistance = distance
            }
        }
        return best
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
        .init(kind: .deceptive, color: Color.green.opacity(0.7), label: "Deceptive"),
        .init(kind: .toDominant, color: .orange, label: "To V7"),
        .init(kind: .relative, color: Color.white.opacity(0.65), label: "Diatonic"),
        .init(kind: .mediant, color: Color.white.opacity(0.5), label: "Diatonic"),
        .init(kind: .twoFive, color: .mint, label: "ii–V"),
        .init(kind: .tritoneSub, color: .pink, label: "Tritone sub"),
        .init(kind: .soften, color: .cyan, label: "Soften"),
        .init(kind: .backdoor, color: .yellow, label: "Backdoor"),
        .init(kind: .fifthSharpward, color: .blue, label: "Fifths"),
        .init(kind: .fifthFlatward, color: .blue, label: "Fifths"),
        // deepen/dimFamily inherit the diminished family's chip tint at
        // draw time; these are only legend fallbacks.
        .init(kind: .deepen, color: .purple, label: "Dim paths"),
        .init(kind: .dimFamily, color: .purple, label: "Dim paths"),
        .init(kind: .passingDim, color: .purple, label: "Dim paths"),
    ]

    /// Legend rows (deduped — fifths share a color, dim paths share a row).
    static let legendRows: [(color: Color, label: String, kinds: Set<HarmonyWheel.MoveKind>)] = {
        var rows: [(Color, String, Set<HarmonyWheel.MoveKind>)] = []
        for style in ordered {
            if let index = rows.firstIndex(where: { $0.1 == style.label }) {
                rows[index].2.insert(style.kind)
            } else {
                rows.append((style.color, style.label, [style.kind]))
            }
        }
        return rows
    }()

    static func style(for kind: HarmonyWheel.MoveKind) -> MoveStyle {
        ordered.first { $0.kind == kind } ?? ordered[0]
    }
}
