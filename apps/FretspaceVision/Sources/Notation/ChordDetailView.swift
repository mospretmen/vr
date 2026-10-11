import SwiftUI
import MusicTheory

/// A chord's hands-on card, opened from the Harmony Compass: playable grips
/// up the neck, closed triads per string set, and drop-2 sevenths — each
/// shape drawn on the fretboard and arpeggiable bottom to top.
struct ChordDetailView: View {
    let chord: Chord
    @Environment(\.openWindow) private var openWindow

    /// The 6-chord whose Barry Harris ladder this chord belongs to, if any.
    private var movementSixChord: Chord? {
        let intervals = chord.quality.intervals
        if intervals.starts(with: [0, 4, 7]) || intervals == [0, 4, 7, 9] {
            return Chord(root: chord.root,
                         quality: ChordQuality(name: "6", symbol: "6", intervals: [0, 4, 7, 9]))
        }
        if intervals.starts(with: [0, 3, 7]) {
            return Chord(root: chord.root,
                         quality: ChordQuality(name: "m6", symbol: "m6", intervals: [0, 3, 7, 9]))
        }
        if chord.quality == .diminished7 {
            return Chord(root: chord.root.transposed(by: 1),
                         quality: ChordQuality(name: "6", symbol: "6", intervals: [0, 4, 7, 9]))
        }
        return nil
    }

    private enum Mode: String, CaseIterable, Identifiable {
        case grips = "Grips"
        case shells = "Shells"
        case triads = "Triads"
        case drop2 = "Drop-2"
        case movement = "Movement"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .grips
    @State private var gripIndex = 0
    @State private var shellIndex = 0
    @State private var bass: ChordTone = .root
    @State private var guideTones = false
    /// nil = show all inversions climbing the neck.
    @State private var inversionFilter: Int? = nil
    @State private var stringSetIndex = 0
    @State private var labelStyle: LabelStyle = .degrees
    @State private var pads = ChordPadEngine()

    private var board: FretboardModel { FretboardModel() }
    private var grips: [Voicing] { ChordVoicings.voicings(for: chord, bass: bass) }
    private var bassChoices: [ChordTone] {
        hasSeventh ? [.root, .third, .fifth, .seventh] : [.root, .third, .fifth]
    }
    private func bassLabel(_ tone: ChordTone) -> String {
        switch tone {
        case .root: "Root"
        case .third: "/3rd"
        case .fifth: "/5th"
        case .seventh: "/7th"
        case .extended: "/ext"
        }
    }
    private var hasSeventh: Bool { chord.quality.intervals.count >= 4 }

    private var modes: [Mode] {
        var list: [Mode] = hasSeventh ? [.grips, .shells, .triads, .drop2]
                                      : [.grips, .triads]
        if movementSixChord != nil { list.append(.movement) }
        return list
    }
    @State private var rungIndex = 0
    @State private var ladderTask: Task<Void, Never>? = nil

    /// Walk the ladder: each rung's ACTUAL voicing sounds while the board
    /// follows along — the movement is seen and heard together.
    private func playLadder() {
        ladderTask?.cancel()
        let steps = ladder
        ladderTask = Task { @MainActor in
            for (index, step) in steps.enumerated() {
                if Task.isCancelled { return }
                rungIndex = index
                if let v = rungVoicing(step) {
                    pads.playVoicing(v.steps.map(\.note), durationMs: 560,
                                     restart: index == 0)
                }
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
        }
    }
    private var ladder: [SixthDiminished.Step] {
        guard let six = movementSixChord else { return [] }
        return SixthDiminished.ladder(root: six.root,
                                      minor: six.quality.intervals.contains(3))
    }
    private var currentRung: SixthDiminished.Step? {
        ladder.isEmpty ? nil : ladder[min(rungIndex, ladder.count - 1)]
    }
    /// The chord whose tones label the board: the rung's chord in Movement.
    private var contextChord: Chord {
        mode == .movement ? (currentRung?.chord ?? chord) : chord
    }

    private func rungVoicing(_ step: SixthDiminished.Step) -> SeventhVoicing? {
        let set = drop2Sets[min(stringSetIndex, drop2Sets.count - 1)]
        for span in [5, 6, 7] {
            let shapes = SeventhVoicings.drop2(of: step.chord, strings: set,
                                               on: board, maxSpan: span)
            if let match = shapes.first(where: { $0.steps.first?.note.pitchClass == step.bass }) {
                return match
            }
        }
        return SeventhVoicings.drop2(of: step.chord, strings: set,
                                     on: board, maxSpan: 7).first
    }

    private func rungLabel(_ step: SixthDiminished.Step) -> String {
        guard let six = movementSixChord else { return step.chord.symbol }
        let degree = six.root.semitones(to: step.bass)
        let spelling: PitchClass.Spelling = [1, 3, 6, 8, 10].contains(degree) ? .flats : .sharps
        return step.bass == step.chord.root
            ? step.chord.symbol
            : "\(step.chord.symbol)/\(step.bass.name(spelling))"
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
                chord: contextChord,
                highlightGuideTones: guideTones,
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
            Toggle("Guide tones", isOn: $guideTones)
                .toggleStyle(.button)
                .font(.caption)
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
        .fixedSize()
    }

    @ViewBuilder
    private var shapeControls: some View {
        switch mode {
        case .grips, .shells:
            let shapes = mode == .grips ? grips : shellVoicings
            let selection = mode == .grips ? gripIndex : shellIndex
            HStack(spacing: 8) {
                if mode == .grips {
                    Picker("Bass", selection: $bass) {
                        ForEach(bassChoices, id: \.self) { Text(bassLabel($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                    .onChange(of: bass) { gripIndex = 0 }
                }
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
        case .movement:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Picker("Strings", selection: $stringSetIndex) {
                        ForEach(drop2Sets.indices, id: \.self) { index in
                            Text("Strings \(setLabel(drop2Sets[index]))").tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    Button {
                        playLadder()
                    } label: {
                        Label("Play ladder", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                    Text("Barry Harris: the 6th-diminished ladder")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                HStack(spacing: 5) {
                    ForEach(Array(ladder.enumerated()), id: \.offset) { index, step in
                        Button {
                            rungIndex = index
                            if let v = rungVoicing(step) {
                                pads.playRun(v.steps.map(\.note))
                            }
                        } label: {
                            Text(rungLabel(step))
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(index == rungIndex
                                                ? (step.isDiminished ? .purple.opacity(0.5)
                                                                     : .blue.opacity(0.5))
                                                : .white.opacity(0.1),
                                            in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
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
                Picker("Inversion", selection: $inversionFilter) {
                    Text("All").tag(Int?.none)
                    Text("Root").tag(Int?.some(0))
                    Text("1st").tag(Int?.some(1))
                    Text("2nd").tag(Int?.some(2))
                    if mode == .drop2 { Text("3rd").tag(Int?.some(3)) }
                }
                .pickerStyle(.segmented)
                .frame(width: mode == .drop2 ? 280 : 230)
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
        case .movement:
            guard let step = currentRung, let v = rungVoicing(step) else { return [] }
            return [InversionShape(shape: v.positions,
                                   label: rungLabel(step),
                                   notes: v.steps.map(\.note))]
        case .movement:
            guard let step = currentRung, let v = rungVoicing(step) else { return [] }
            return [InversionShape(shape: v.positions,
                                   label: rungLabel(step),
                                   notes: v.steps.map(\.note))]
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
            return TriadVoicings.inversions(of: chord, strings: set, on: board)
                .filter { inversionFilter == nil || $0.inversion.rawValue == inversionFilter }
                .map {
                    InversionShape(shape: $0.positions,
                                   label: $0.inversion.label,
                                   notes: $0.steps.map(\.note))
                }
        case .drop2:
            let set = drop2Sets[min(stringSetIndex, drop2Sets.count - 1)]
            return SeventhVoicings.drop2(of: chord, strings: set, on: board)
                .filter { inversionFilter == nil || $0.inversion.rawValue == inversionFilter }
                .map {
                    InversionShape(shape: $0.positions,
                                   label: $0.inversion.label,
                                   notes: $0.steps.map(\.note))
                }
        }
    }

    private var shapeHighlights: [FretboardHighlight] {
        let context = contextChord
        return currentInversions.flatMap(\.shape).compactMap { position in
            let note = board.note(at: position)
            guard let tone = context.tone(of: note.pitchClass) else { return nil }
            return FretboardHighlight(position: position, note: note,
                                      role: .chordTone(tone))
        }
    }

    private var shapeConnections: [[FretPosition]] {
        // Owner call: the tone-to-tone lines read as fingering advice they
        // aren't. Markers + role labels carry the shape; lines retired
        // until a validated fingering model earns them back.
        []
    }

    /// Guitarist numbering: string 6 is the low E.
    private func setLabel(_ set: [Int]) -> String {
        set.map { String(6 - $0) }.joined(separator: "·")
    }
}
