import SwiftUI
import MusicTheory

/// A chord's hands-on card, opened from the Harmony Compass: playable grips
/// up the neck, closed triads per string set, and drop-2 sevenths — each
/// shape drawn on the fretboard and arpeggiable bottom to top.
struct ChordDetailView: View {
    let chord: Chord

    private enum Mode: String, CaseIterable, Identifiable {
        case grips = "Grips"
        case shells = "Shells"
        case triads = "Triads"
        case drop2 = "Drop-2"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .grips
    @State private var gripIndex = 0
    @State private var shellIndex = 0
    @State private var stringSetIndex = 0
    @State private var labelStyle: LabelStyle = .degrees
    @State private var pads = ChordPadEngine()

    private var board: FretboardModel { FretboardModel() }
    private var grips: [Voicing] { ChordVoicings.voicings(for: chord) }
    private var hasSeventh: Bool { chord.quality.intervals.count >= 4 }

    private var modes: [Mode] {
        hasSeventh ? [.grips, .shells, .triads, .drop2] : [.grips, .triads]
    }
    private var shellVoicings: [Voicing] { ChordVoicings.shells(for: chord) }

    private var triadSets: [[Int]] { TriadVoicings.stringSets }
    private var drop2Sets: [[Int]] { SeventhVoicings.stringSets }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            modePicker
            shapeControls
            FretboardDiagram(
                highlights: shapeHighlights,
                stringCount: 6,
                fretCount: 15,
                labelStyle: labelStyle,
                connections: shapeConnections
            )
            // A real neck's proportions — never stretched by the window.
            .aspectRatio(5.6, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(22)
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(chord.symbol).font(.title.bold())
                Text(chord.quality.name).font(.callout).foregroundStyle(.secondary)
            }
            Button {
                pads.play(chord, durationMs: 1800)
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
            Picker("Labels", selection: $labelStyle) {
                Text("Tones").tag(LabelStyle.degrees)
                Text("Notes").tag(LabelStyle.noteNames)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
    }

    private var modePicker: some View {
        Picker("Shapes", selection: $mode) {
            ForEach(modes) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(width: 340)
    }

    @ViewBuilder
    private var shapeControls: some View {
        switch mode {
        case .grips, .shells:
            let shapes = mode == .grips ? grips : shellVoicings
            let selection = mode == .grips ? gripIndex : shellIndex
            HStack(spacing: 8) {
                ForEach(Array(shapes.enumerated()), id: \.offset) { index, grip in
                    Button {
                        if mode == .grips { gripIndex = index } else { shellIndex = index }
                        pads.playRun(grip.positions.map { board.note(at: $0) })
                    } label: {
                        Text(grip.positionLabel)
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(index == selection ? .blue.opacity(0.45)
                                                           : .white.opacity(0.1),
                                        in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(mode == .shells ? "Root + 3rd + 7th — the comping skeleton"
                                     : "Tap a grip to hear it")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        case .triads, .drop2:
            HStack(spacing: 8) {
                Picker("Strings", selection: $stringSetIndex) {
                    let sets = mode == .triads ? triadSets : drop2Sets
                    ForEach(sets.indices, id: \.self) { index in
                        Text("Strings \(setLabel(sets[index]))").tag(index)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                ForEach(currentInversions, id: \.shape) { item in
                    Button {
                        pads.playRun(item.notes)
                    } label: {
                        Label(item.label, systemImage: "play.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Shape data

    private struct InversionShape: Hashable {
        let shape: [FretPosition]
        let label: String
        let notes: [Note]
    }

    /// All inversions on the chosen string set, lowest spot each — shown
    /// together so the same chord is visible climbing the neck.
    private var currentInversions: [InversionShape] {
        switch mode {
        case .grips, .shells:
            let shapes = mode == .grips ? grips : shellVoicings
            let index = mode == .grips ? gripIndex : shellIndex
            guard shapes.indices.contains(index) else { return [] }
            let grip = shapes[index]
            return [InversionShape(shape: grip.positions,
                                   label: grip.positionLabel,
                                   notes: grip.positions.map { board.note(at: $0) })]
        case .triads:
            let set = triadSets[min(stringSetIndex, triadSets.count - 1)]
            return TriadVoicings.inversions(of: chord, strings: set, on: board).map {
                InversionShape(shape: $0.positions,
                               label: $0.inversion.label,
                               notes: $0.steps.map(\.note))
            }
        case .drop2:
            let set = drop2Sets[min(stringSetIndex, drop2Sets.count - 1)]
            return SeventhVoicings.drop2(of: chord, strings: set, on: board).map {
                InversionShape(shape: $0.positions,
                               label: $0.inversion.label,
                               notes: $0.steps.map(\.note))
            }
        }
    }

    private var shapeHighlights: [FretboardHighlight] {
        currentInversions.flatMap(\.shape).compactMap { position in
            let note = board.note(at: position)
            guard let tone = chord.tone(of: note.pitchClass) else { return nil }
            return FretboardHighlight(position: position, note: note,
                                      role: .chordTone(tone))
        }
    }

    private var shapeConnections: [[FretPosition]] {
        switch mode {
        case .grips: return []
        case .shells, .triads, .drop2: return currentInversions.map(\.shape)
        }
    }

    /// Guitarist numbering: string 6 is the low E.
    private func setLabel(_ set: [Int]) -> String {
        set.map { String(6 - $0) }.joined(separator: "·")
    }
}
