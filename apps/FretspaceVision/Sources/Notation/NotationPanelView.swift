import SwiftUI
import MusicTheory
import FretboardKit

/// Floating chart window: a 2D fretboard diagram mirroring the spatial
/// overlay, plus the notes/degrees of the current selection. Staff notation
/// rendering is a later phase (see docs/ROADMAP.md).
struct NotationPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            FretboardDiagram(
                highlights: model.highlights,
                stringCount: model.tuning.stringCount,
                fretCount: min(model.fretCount, 15), // charts read best to fret 15
                labelStyle: model.labelStyle,
                leftHanded: model.leftHanded,
                scale: model.activeScale,
                connections: model.connectionGroups,
                emphasizeAlterations: model.emphasizeAlterations
            )
            .frame(maxHeight: .infinity)
            if model.backing.timeline != nil {
                ProgressionStrip()
            } else if model.displayMode == .triads {
                voicingCaptionStrip
            } else {
                noteStrip
            }
        }
        .padding(24)
    }

    private var header: some View {
        HStack {
            Text(title).font(.largeTitle.bold())
            Spacer()
            legend
        }
    }

    private var title: String {
        switch model.displayMode {
        case .scale: model.scale.name
        case .chord: model.chord.symbol
        case .triads:
            switch model.voicingStyle {
            case .triads:
                model.focusedInversion.map { "\(model.chord.symbol) — \($0.label)" }
                    ?? "\(model.chord.symbol) Triads"
            case .drop2:
                model.focusedSeventhInversion.map { "\(model.chord.symbol) drop-2 — \($0.label)" }
                    ?? "\(model.chord.symbol) Drop-2 Voicings"
            case .harmonized:
                "\(model.scale.name) — Harmonized"
            case .open:
                "\(model.chord.symbol) — Open Shape"
            }
        case .chordInScale: "\(model.chord.symbol) over \(model.scale.name)"
        case .exercise: model.exercise?.name ?? "Exercise"
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            if model.displayMode != .scale {
                legendDot(.orange, "Root")
                legendDot(.cyan, "3rd")
                legendDot(.green, "5th")
                legendDot(.purple, "7th")
            } else {
                legendDot(.orange, "Root")
                legendDot(Color.white.opacity(0.55), "Scale")
            }
        }
        .font(.caption)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    private var voicingCaptionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(model.voicingCaptions.enumerated()), id: \.offset) { _, caption in
                    Text(caption)
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: .capsule)
                }
            }
        }
    }

    private var noteStrip: some View {
        HStack(spacing: 10) {
            let showChordTones = model.displayMode == .chord
                || (model.displayMode == .triads && model.voicingStyle != .harmonized)
            let pcs = showChordTones ? model.chord.pitchClasses : model.scale.pitchClasses
            ForEach(Array(pcs.enumerated()), id: \.offset) { _, pc in
                Text(pc.name())
                    .font(.title3.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: .capsule)
            }
        }
    }
}

/// The loaded backing track's progression as a horizontal bar strip.
/// The sounding bar glows and the strip auto-scrolls to keep it visible;
/// the next change is pre-announced by a subtle ring.
struct ProgressionStrip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.backing.title)
                .font(.headline)
                .foregroundStyle(.secondary)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        let events = model.backing.timeline?.events ?? []
                        ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                            barCell(index: index, event: event)
                                .id(index)
                        }
                    }
                }
                .onChange(of: model.backing.currentChord) {
                    guard let timeline = model.backing.timeline,
                          let index = timeline.events.firstIndex(where: {
                              $0.startMs <= model.backing.positionMs
                              && model.backing.positionMs < $0.endMs
                          }) else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }

    private func barCell(index: Int, event: ChordEvent) -> some View {
        let isCurrent = model.backing.isPlaying
            && event.startMs <= model.backing.positionMs
            && model.backing.positionMs < event.endMs
        let isNext = model.backing.upcoming?.startMs == event.startMs

        return VStack(spacing: 2) {
            Text("\(index + 1)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(event.chord.symbol)
                .font(.title3.monospaced().weight(isCurrent ? .bold : .regular))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            isCurrent ? AnyShapeStyle(.orange.opacity(0.35)) : AnyShapeStyle(.thinMaterial),
            in: .rect(cornerRadius: 10)
        )
        .overlay {
            if isNext {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.orange.opacity(0.5), lineWidth: 1.5)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
    }
}

/// 2D fretboard chart drawn with Canvas. Strings run horizontally
/// (lowest string at the bottom, like tab), frets vertically.
struct FretboardDiagram: View {
    let highlights: [FretboardHighlight]
    let stringCount: Int
    let fretCount: Int
    let labelStyle: LabelStyle
    var leftHanded = false
    var scale: Scale? = nil
    var connections: [[FretPosition]] = []
    var emphasizeAlterations = false

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 28
            let rect = CGRect(x: inset, y: inset,
                              width: size.width - inset * 2,
                              height: size.height - inset * 2)
            let stringGap = rect.height / CGFloat(max(stringCount - 1, 1))

            // Real equal-temperament fret spacing, normalized to the panel.
            let geo = FretboardGeometry(fretCount: fretCount)
            let span = geo.fretDistance(fretCount)
            func x(fret: Int) -> CGFloat {
                rect.minX + rect.width * CGFloat(geo.fretDistance(fret) / span)
            }
            func noteCX(_ fret: Int) -> CGFloat {
                fret == 0 ? rect.minX - 16
                          : rect.minX + rect.width * CGFloat(geo.noteX(fret: fret) / span)
            }

            // Wood neck: layered warm gradient with a rounded edge.
            let board = rect.insetBy(dx: -6, dy: -12)
            context.fill(
                Path(roundedRect: board, cornerRadius: 8),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.26, green: 0.15, blue: 0.09),
                        Color(red: 0.36, green: 0.22, blue: 0.13),
                        Color(red: 0.30, green: 0.18, blue: 0.11),
                    ]),
                    startPoint: CGPoint(x: board.minX, y: board.minY),
                    endPoint: CGPoint(x: board.minX, y: board.maxY))
            )

            // Bone nut.
            let nut = CGRect(x: rect.minX - 5, y: board.minY, width: 7, height: board.height)
            context.fill(Path(roundedRect: nut, cornerRadius: 2),
                         with: .color(Color(red: 0.93, green: 0.90, blue: 0.82)))
            // String 0 (lowest pitch) at the bottom; mirrored for lefties to
            // match the flipped spatial overlay.
            func y(string: Int) -> CGFloat {
                leftHanded ? rect.minY + CGFloat(string) * stringGap
                           : rect.maxY - CGFloat(string) * stringGap
            }

            // Metal frets: light bar with a darker shadow edge.
            for fret in 1...fretCount {
                let fx = x(fret: fret)
                var shadow = Path()
                shadow.move(to: CGPoint(x: fx + 1.4, y: board.minY + 3))
                shadow.addLine(to: CGPoint(x: fx + 1.4, y: board.maxY - 3))
                context.stroke(shadow, with: .color(.black.opacity(0.45)), lineWidth: 1.6)
                var wire = Path()
                wire.move(to: CGPoint(x: fx, y: board.minY + 3))
                wire.addLine(to: CGPoint(x: fx, y: board.maxY - 3))
                context.stroke(wire, with: .color(Color(red: 0.78, green: 0.78, blue: 0.80)),
                               lineWidth: 2.2)
            }

            // Pearl inlays.
            for fret in [3, 5, 7, 9, 12, 15] where fret <= fretCount {
                let cx = noteCX(fret)
                let count = fret == 12 ? 2 : 1
                for i in 0..<count {
                    let cy = rect.midY + (count == 2 ? (CGFloat(i) * 2 - 1) * rect.height / 5 : 0)
                    let dot = Path(ellipseIn: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10))
                    context.fill(dot, with: .color(Color(red: 0.88, green: 0.86, blue: 0.80).opacity(0.55)))
                }
            }

            // Strings: steel-toned, gauged thicker toward the low string.
            for string in 0..<stringCount {
                let sy = y(string: string)
                let gauge = 3.0 - CGFloat(string) * 0.38
                var line = Path()
                line.move(to: CGPoint(x: rect.minX - 5, y: sy))
                line.addLine(to: CGPoint(x: rect.maxX, y: sy))
                context.stroke(line, with: .color(.black.opacity(0.35)),
                               lineWidth: gauge + 1)
                context.stroke(line, with: .color(Color(red: 0.82, green: 0.80, blue: 0.74)),
                               lineWidth: max(gauge, 0.9))
            }

            // Marker center, shared by connections and highlights.
            func center(_ position: FretPosition) -> CGPoint {
                CGPoint(x: noteCX(position.fret), y: y(string: position.string))
            }

            // Shape connections (triad voicings) under the markers.
            for group in connections where group.allSatisfy({ $0.fret <= fretCount }) {
                guard group.count > 1 else { continue }
                var path = Path()
                path.move(to: center(group[0]))
                for position in group.dropFirst() {
                    path.addLine(to: center(position))
                }
                context.stroke(path, with: .color(.white.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            // Highlights
            for h in highlights where h.position.fret <= fretCount {
                let cx = noteCX(h.position.fret)
                let cy = y(string: h.position.string)
                let radius: CGFloat = CGFloat(OverlayPalette.radius(for: h.role)) * 2200
                let circle = Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius,
                                                    width: radius * 2, height: radius * 2))
                context.fill(circle, with: .color(OverlayPalette.color(
                    for: h, scale: scale, emphasizeAlterations: emphasizeAlterations)))

                if let label = OverlayPalette.label(for: h, style: labelStyle, scale: scale) {
                    context.draw(
                        Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.black),
                        at: CGPoint(x: cx, y: cy)
                    )
                }
            }
        }
    }
}
