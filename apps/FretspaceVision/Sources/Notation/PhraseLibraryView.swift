import SwiftUI
import MusicTheory

/// The phrase repository: your own vocabulary, one lick at a time. Browse,
/// hear, and record phrases by tapping notes straight onto the fretboard.
struct PhraseLibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var pads = ChordPadEngine()
    @State private var selectedID: Phrase.ID? = nil
    @State private var recording = false
    @State private var editing: Phrase? = nil
    /// Ephemeral transposition of the selected phrase (semitones).
    @State private var transpose = 0
    @State private var selectedClassic: Phrase? = nil
    private let board = FretboardModel()

    /// The selected phrase as currently viewed (possibly transposed).
    private var viewedPhrase: Phrase? {
        guard let base = selectedClassic ?? selected else { return nil }
        return base.transposed(by: transpose, on: board) ?? base
    }

    private var selected: Phrase? {
        model.phrases.phrases.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Phrases").font(.title.bold())
                    Text("Your vocabulary — \(model.phrases.phrases.count) stored")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editing = nil
                    recording.toggle()
                } label: {
                    Label(recording ? "Close recorder" : "New phrase",
                          systemImage: recording ? "xmark" : "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if recording {
                PhraseRecorder(pads: pads, editing: editing) { phrase in
                    if editing == nil {
                        model.phrases.add(phrase)
                    } else {
                        model.phrases.update(phrase)
                    }
                    editing = nil
                    recording = false
                    selectedID = phrase.id
                }
            } else {
                browser
            }
        }
        .padding(22)
    }

    private var browser: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if model.phrases.phrases.isEmpty {
                        Text("No phrases of your own yet — record one, or pull a classic from the shelf below.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(model.phrases.phrases) { phrase in
                        HStack(spacing: 8) {
                            Button {
                                if selectedID != phrase.id { transpose = 0 }
                                selectedClassic = nil
                                selectedID = phrase.id
                                pads.playRun(phrase.steps.map(\.note), noteMs: 230)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.circle")
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(phrase.name).font(.callout.bold())
                                        Text(phraseSubtitle(phrase))
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6).padding(.horizontal, 10)
                                .background(phrase.id == selectedID
                                                ? .blue.opacity(0.3) : .white.opacity(0.06),
                                            in: .rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            Button {
                                editing = phrase
                                recording = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            Button(role: .destructive) {
                                model.phrases.delete(phrase)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Divider().padding(.vertical, 4)
                    Text("Classics — style-of lines & public-domain themes")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(BuiltInPhrases.all) { classic in
                        HStack(spacing: 8) {
                            Button {
                                selectedID = nil
                                transpose = 0
                                selectedClassic = classic
                                pads.playRun(classic.steps.map(\.note), noteMs: 230)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.circle")
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(classic.name).font(.callout.bold())
                                        Text(phraseSubtitle(classic))
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6).padding(.horizontal, 10)
                                .background(classic.id == selectedClassic?.id
                                                ? .blue.opacity(0.3) : .white.opacity(0.04),
                                            in: .rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            Button {
                                var copy = classic
                                copy.id = UUID()
                                copy.createdAt = .now
                                model.phrases.add(copy)
                                selectedClassic = nil
                                selectedID = copy.id
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .frame(maxHeight: 230)

            if let phrase = viewedPhrase {
                analysisRow(phrase)
                FretboardDiagram(
                    highlights: phraseHighlights(phrase),
                    stringCount: 6,
                    fretCount: 15,
                    labelStyle: .noteNames,
                    chord: phrase.chord
                )
                .aspectRatio(5.6, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    /// Harmonic reading + transposition controls for the selected phrase.
    private func analysisRow(_ phrase: Phrase) -> some View {
        let notes = phrase.steps.map(\.note)
        let devices = PhraseAnalysis.devices(notes: notes, chord: phrase.chord)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                if !devices.isEmpty {
                    Text(devices.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.cyan.opacity(0.9))
                }
                Spacer()
                Menu {
                    ForEach(0..<12, id: \.self) { delta in
                        let label = delta == 0 ? "Original"
                            : "+\(delta) (\(transposedLabel(phrase, delta)))"
                        Button(label) {
                            transpose = delta
                            if let moved = selected?.transposed(by: delta, on: board) {
                                pads.playRun(moved.steps.map(\.note), noteMs: 230)
                            }
                        }
                    }
                } label: {
                    Label(transpose == 0 ? "Transpose"
                          : "Transposed +\(transpose)",
                          systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                }
                if transpose != 0 {
                    Button("Save as copy") {
                        guard let moved = viewedPhrase else { return }
                        var copy = moved
                        copy.id = UUID()
                        copy.name = moved.name + " (+\(transpose))"
                        copy.createdAt = .now
                        model.phrases.add(copy)
                        transpose = 0
                        selectedID = copy.id
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
            if let chord = phrase.chord {
                Text("Over \(chord.symbol): "
                     + PhraseAnalysis.degreePath(notes: notes, chord: chord))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private func transposedLabel(_ phrase: Phrase, _ delta: Int) -> String {
        let anchor = phrase.chord?.root ?? phrase.steps.first?.note.pitchClass ?? .c
        return anchor.transposed(by: delta).name()
    }

    private func phraseSubtitle(_ phrase: Phrase) -> String {
        var parts: [String] = ["\(phrase.steps.count) notes"]
        if let context = phrase.context, !context.isEmpty {
            parts.append(context)
        } else if let chord = phrase.chord {
            parts.append("over \(chord.symbol)")
        }
        if !phrase.remark.isEmpty { parts.append(phrase.remark) }
        return parts.joined(separator: " · ")
    }

    private func phraseHighlights(_ phrase: Phrase) -> [FretboardHighlight] {
        var seen = Set<FretPosition>()
        return phrase.steps.compactMap { step in
            guard seen.insert(step.position).inserted else { return nil }
            return FretboardHighlight(position: step.position, note: step.note,
                                      role: .exerciseStep(isCurrent: false))
        }
    }
}

/// Record a phrase by tapping notes onto the neck, in order.
private struct PhraseRecorder: View {
    let pads: ChordPadEngine
    var editing: Phrase? = nil
    let onSave: (Phrase) -> Void

    @State private var steps: [ExerciseStep] = []
    @State private var name = ""
    @State private var remark = ""
    @State private var contextRoot: PitchClass? = nil
    @State private var contextQuality: Int = 0
    private let board = FretboardModel()

    private var contextChord: Chord? {
        contextRoot.map { Chord(root: $0, quality: ChordQuality.all[contextQuality]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Phrase name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                TextField("Why it works (optional)", text: $remark)
                    .textFieldStyle(.roundedBorder)
                Button("Undo") {
                    _ = steps.popLast()
                }
                .disabled(steps.isEmpty)
                Button("Hear") {
                    pads.playRun(steps.map(\.note), noteMs: 230)
                }
                .disabled(steps.isEmpty)
                Button(editing == nil ? "Save" : "Save changes") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    onSave(Phrase(id: editing?.id ?? UUID(),
                                  name: trimmed.isEmpty ? "Untitled phrase" : trimmed,
                                  chord: contextChord,
                                  steps: steps, remark: remark,
                                  createdAt: editing?.createdAt ?? .now))
                }
                .buttonStyle(.borderedProminent)
                .disabled(steps.isEmpty)
            }

            HStack(spacing: 8) {
                Text("Over").font(.caption).foregroundStyle(.secondary)
                Picker("Root", selection: $contextRoot) {
                    Text("No chord").tag(PitchClass?.none)
                    ForEach(PitchClass.allCases, id: \.self) { pc in
                        Text(pc.name()).tag(PitchClass?.some(pc))
                    }
                }
                .pickerStyle(.menu)
                if contextRoot != nil {
                    Picker("Quality", selection: $contextQuality) {
                        ForEach(Array(ChordQuality.all.enumerated()), id: \.offset) { i, q in
                            Text(q.name).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if let chord = contextChord {
                    Text(chord.symbol).font(.caption.bold()).foregroundStyle(.orange)
                }
                Spacer()
            }
            .onAppear {
                guard let editing else { return }
                steps = editing.steps
                name = editing.name
                remark = editing.remark
                if let chord = editing.chord {
                    contextRoot = chord.root
                    contextQuality = ChordQuality.all.firstIndex(of: chord.quality) ?? 0
                }
            }

            Text(steps.isEmpty
                 ? "Tap the fretboard to lay down the line, note by note."
                 : steps.map { $0.note.pitchClass.name() }.joined(separator: " → "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            FretboardDiagram(
                highlights: recorderHighlights,
                stringCount: 6,
                fretCount: 15,
                labelStyle: .noteNames,
                onTap: { position in
                    let step = ExerciseStep(position: position,
                                            note: board.note(at: position))
                    steps.append(step)
                    pads.playVoicing([step.note], durationMs: 300, restart: true)
                }
            )
            .aspectRatio(5.6, contentMode: .fit)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .padding(12)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 12))
    }

    private var recorderHighlights: [FretboardHighlight] {
        var seen = Set<FretPosition>()
        return steps.enumerated().compactMap { index, step in
            guard seen.insert(step.position).inserted else { return nil }
            return FretboardHighlight(
                position: step.position, note: step.note,
                role: .exerciseStep(isCurrent: index == steps.count - 1))
        }
    }
}
