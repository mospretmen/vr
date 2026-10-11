import SwiftUI
import MusicTheory

/// Barry Harris movement: the 6th-diminished ladder voiced as drop-2
/// shapes climbing a string set — C6 · B°7 · C6/E · B°7/D … Tap a rung to
/// see and hear it; Play walks the whole ladder.
struct MovementView: View {
    let chord: Chord

    @State private var stringSetIndex = 1
    @State private var rungIndex = 0
    @State private var pads = ChordPadEngine()

    private var board: FretboardModel { FretboardModel() }
    private var isMinor: Bool { chord.quality.intervals.contains(3) }
    private var ladder: [SixthDiminished.Step] {
        SixthDiminished.ladder(root: chord.root, minor: isMinor)
    }
    private var strings: [Int] {
        SeventhVoicings.stringSets[min(stringSetIndex, SeventhVoicings.stringSets.count - 1)]
    }

    private func voicing(for step: SixthDiminished.Step) -> SeventhVoicing? {
        // Prefer the inversion with the rung's bass; widen the hand span
        // before giving up, and never show an empty board.
        for span in [5, 6, 7] {
            let shapes = SeventhVoicings.drop2(of: step.chord, strings: strings,
                                               on: board, maxSpan: span)
            if let match = shapes.first(where: { $0.steps.first?.note.pitchClass == step.bass }) {
                return match
            }
        }
        return SeventhVoicings.drop2(of: step.chord, strings: strings,
                                     on: board, maxSpan: 7).first
    }

    private func rungLabel(_ step: SixthDiminished.Step) -> String {
        let degree = chord.root.semitones(to: step.bass)
        let spelling: PitchClass.Spelling = [1, 3, 6, 8, 10].contains(degree) ? .flats : .sharps
        return step.bass == step.chord.root
            ? step.chord.symbol
            : "\(step.chord.symbol)/\(step.bass.name(spelling))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(chord.symbol) movement").font(.title.bold())
                    Text("The 6th-diminished ladder — Barry Harris style")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Button {
                    pads.playProgression(ladder.map(\.chord), eachMs: 620)
                } label: {
                    Label("Play ladder", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Picker("Strings", selection: $stringSetIndex) {
                    ForEach(SeventhVoicings.stringSets.indices, id: \.self) { index in
                        let set = SeventhVoicings.stringSets[index]
                        Text("Strings \(set.map { String(6 - $0) }.joined(separator: "·"))")
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
            }

            Text("Alternate the \(chord.symbol) chord with \(ladder[1].chord.symbol) and a "
                 + "parked chord starts to walk: every scale step harmonized, every "
                 + "bass a chord tone. Comp it, and tension breathes in and out.")
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(Array(ladder.enumerated()), id: \.offset) { index, step in
                    Button {
                        rungIndex = index
                        if let v = voicing(for: step) {
                            pads.playRun(v.steps.map(\.note))
                        }
                    } label: {
                        Text(rungLabel(step))
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .padding(.horizontal, 9).padding(.vertical, 6)
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

            let step = ladder[min(rungIndex, ladder.count - 1)]
            let shape = voicing(for: step)
            FretboardDiagram(
                highlights: (shape?.positions ?? []).compactMap { position in
                    let note = board.note(at: position)
                    guard let tone = step.chord.tone(of: note.pitchClass) else { return nil }
                    return FretboardHighlight(position: position, note: note,
                                              role: .chordTone(tone))
                },
                stringCount: 6,
                fretCount: 15,
                labelStyle: .degrees,
                chord: step.chord
            )
            .aspectRatio(5.6, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(22)
    }
}
