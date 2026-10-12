import SwiftUI
import MusicTheory

/// The phrase repository: your own vocabulary, one lick at a time. Browse,
/// hear, and record phrases by tapping notes straight onto the fretboard.
struct PhraseLibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var pads = ChordPadEngine()
    @State private var selectedID: Phrase.ID? = nil
    @State private var recording = false

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
                    recording.toggle()
                } label: {
                    Label(recording ? "Close recorder" : "New phrase",
                          systemImage: recording ? "xmark" : "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if recording {
                PhraseRecorder(pads: pads) { phrase in
                    model.phrases.add(phrase)
                    recording = false
                    selectedID = phrase.id
                }
            } else if model.phrases.phrases.isEmpty {
                ContentUnavailableView(
                    "No phrases yet",
                    systemImage: "music.quarternote.3",
                    description: Text("Tap New phrase and play a line onto the "
                                      + "fretboard — your repertoire starts here."))
                    .frame(maxHeight: .infinity)
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
                    ForEach(model.phrases.phrases) { phrase in
                        HStack(spacing: 8) {
                            Button {
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
                            Button(role: .destructive) {
                                model.phrases.delete(phrase)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .frame(maxHeight: 190)

            if let selected {
                FretboardDiagram(
                    highlights: phraseHighlights(selected),
                    stringCount: 6,
                    fretCount: 15,
                    labelStyle: .noteNames,
                    chord: selected.chord
                )
                .aspectRatio(5.6, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private func phraseSubtitle(_ phrase: Phrase) -> String {
        var parts: [String] = ["\(phrase.steps.count) notes"]
        if let chord = phrase.chord { parts.append("over \(chord.symbol)") }
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
    let onSave: (Phrase) -> Void

    @State private var steps: [ExerciseStep] = []
    @State private var name = ""
    @State private var remark = ""
    private let board = FretboardModel()

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
                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    onSave(Phrase(name: trimmed.isEmpty ? "Untitled phrase" : trimmed,
                                  steps: steps, remark: remark))
                }
                .buttonStyle(.borderedProminent)
                .disabled(steps.isEmpty)
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
