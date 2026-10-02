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
            let fretWidth = rect.width / CGFloat(fretCount)
            let stringGap = rect.height / CGFloat(max(stringCount - 1, 1))

            func x(fret: Int) -> CGFloat { rect.minX + CGFloat(fret) * fretWidth }
            // String 0 (lowest pitch) at the bottom; mirrored for lefties to
            // match the flipped spatial overlay.
            func y(string: Int) -> CGFloat {
                leftHanded ? rect.minY + CGFloat(string) * stringGap
                           : rect.maxY - CGFloat(string) * stringGap
            }

            // Frets
            for fret in 0...fretCount {
                var line = Path()
                line.move(to: CGPoint(x: x(fret: fret), y: rect.minY))
                line.addLine(to: CGPoint(x: x(fret: fret), y: rect.maxY))
                context.stroke(line, with: .color(.white.opacity(fret == 0 ? 0.9 : 0.3)),
                               lineWidth: fret == 0 ? 3 : 1)
            }

            // Inlay markers
            for fret in [3, 5, 7, 9, 12, 15] where fret <= fretCount {
                let cx = x(fret: fret) - fretWidth / 2
                let count = fret == 12 ? 2 : 1
                for i in 0..<count {
                    let cy = rect.midY + (count == 2 ? (CGFloat(i) * 2 - 1) * rect.height / 5 : 0)
                    let dot = Path(ellipseIn: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))
                    context.fill(dot, with: .color(.white.opacity(0.15)))
                }
            }

            // Strings
            for string in 0..<stringCount {
                var line = Path()
                line.move(to: CGPoint(x: rect.minX, y: y(string: string)))
                line.addLine(to: CGPoint(x: rect.maxX, y: y(string: string)))
                context.stroke(line, with: .color(.white.opacity(0.4)), lineWidth: 1)
            }

            // Marker center, shared by connections and highlights.
            func center(_ position: FretPosition) -> CGPoint {
                let cx = position.fret == 0
                    ? rect.minX - 14
                    : x(fret: position.fret) - fretWidth / 2
                return CGPoint(x: cx, y: y(string: position.string))
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
                let cx = h.position.fret == 0
                    ? rect.minX - 14 // open strings sit left of the nut
                    : x(fret: h.position.fret) - fretWidth / 2
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
