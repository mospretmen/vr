import SwiftUI
import MusicTheory

/// A scale's full card, opened from the Harmony Compass: hear it, read it
/// on the staff with spelled degrees, understand its character, and see
/// it on a realistic fretboard — full neck or one position box.
struct ScaleDetailView: View {
    let scale: Scale

    @State private var labelStyle: LabelStyle = .degrees
    @State private var boxIndex: Int? = nil
    @State private var pads = ChordPadEngine()

    private var board: FretboardModel { FretboardModel() }

    private var highlights: [FretboardHighlight] {
        if let boxIndex,
           board.boxStartFrets(for: scale).indices.contains(boxIndex) {
            return board.positionBox(
                for: scale, startingAt: board.boxStartFrets(for: scale)[boxIndex])
        }
        return board.highlights(for: scale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(scale.name).font(.title.bold())
                    if let summary = Modes.summary(of: scale) {
                        Text(summary).font(.callout).foregroundStyle(.secondary)
                    }
                }
                Button {
                    pads.playScale(scale)
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Picker("Labels", selection: $labelStyle) {
                    Text("Degrees").tag(LabelStyle.degrees)
                    Text("Notes").tag(LabelStyle.noteNames)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            Text(ScaleLore.description(for: scale.type))
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            ScaleStaff(scale: scale)
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial, in: .rect(cornerRadius: 10))

            HStack {
                Picker("Position", selection: $boxIndex) {
                    Text("Full neck").tag(Int?.none)
                    ForEach(Array(board.boxStartFrets(for: scale).enumerated()),
                            id: \.offset) { index, fret in
                        Text("Box \(index + 1) · fret \(fret)").tag(Int?.some(index))
                    }
                }
                .pickerStyle(.menu)
                Spacer()
            }

            FretboardDiagram(
                highlights: highlights,
                stringCount: 6,
                fretCount: 15,
                labelStyle: labelStyle,
                scale: scale
            )
            .frame(maxHeight: .infinity)
        }
        .padding(22)
    }
}

/// Short, player-facing character notes per scale type.
enum ScaleLore {
    static func description(for type: ScaleType) -> String {
        switch type {
        case .major: return "The home base — bright, stable, resolved. Everything else is measured against it."
        case .dorian: return "Minor with a bright natural 6 — the classic cool jazz and funk minor sound."
        case .phrygian: return "Dark minor with a ♭2 — Spanish and modern-metal flavor."
        case .lydian: return "Major with a raised 4 — floating, dreamy, film-score openness."
        case .mixolydian: return "Major with a ♭7 — the dominant-chord scale; blues, rock and funk live here."
        case .naturalMinor: return "The pure minor — melancholy, songlike, the relative shadow of major."
        case .locrian: return "Unstable by design (♭2 and ♭5) — at home only over half-diminished chords."
        case .majorPentatonic: return "Five safe, open notes of major — country, gospel, and singable solos."
        case .minorPentatonic: return "The guitarist's mother tongue — five notes, infinite blues and rock."
        case .blues: return "Minor pentatonic plus the ♭5 'blue note' — tension you bend through, not sit on."
        case .harmonicMinor: return "Minor with a raised 7 — the dramatic pull home; neoclassical and gypsy heat."
        case .melodicMinor: return "Minor with a bright 6 and 7 — the jazz minor, smooth on the way up."
        case .phrygianDominant: return "Harmonic minor's 5th mode — flamenco and metal fire over a dominant."
        case .lydianDominant: return "Mixolydian with a ♯4 — the hip altered-but-not-too-altered dominant color."
        case .bebopDominant: return "Mixolydian plus a passing major 7 — eight notes that keep chord tones on the beat."
        case .wholeHalfDiminished: return "The symmetric scale for °7 chords — repeats every minor third, like the chord itself."
        default: return "A color worth exploring — play it over its chord and listen."
        }
    }
}

/// The scale as an ascending run on a treble staff: note heads left to
/// right with accidentals, spelled degree labels beneath.
struct ScaleStaff: View {
    let scale: Scale

    var body: some View {
        Canvas { context, size in
            let lineGap: CGFloat = 8.5
            let staffTop = size.height / 2 - 2.5 * lineGap
            let left: CGFloat = 46
            let right = size.width - 16

            for line in 0..<5 {
                let y = staffTop + CGFloat(line) * lineGap
                var path = Path()
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: right, y: y))
                context.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 1)
            }
            context.draw(
                Text("𝄞").font(.system(size: 44)).foregroundStyle(.white.opacity(0.85)),
                at: CGPoint(x: left - 20, y: staffTop + 2 * lineGap)
            )

            let useFlats = scale.name.contains("♭")
            let names = scale.pitchClasses.map { $0.name(useFlats ? .flats : .sharps) }
            let degrees = Modes.degreeLabels(of: scale.type)
            let letterSteps: [Character: Int] = ["C": 0, "D": 1, "E": 2, "F": 3,
                                                 "G": 4, "A": 5, "B": 6]
            let count = names.count + 1
            let step0 = letterSteps[names[0].first ?? "C"] ?? 0
            let spacing = (right - left - 40) / CGFloat(max(count - 1, 1))

            var lastStep = step0 - 1
            for index in 0..<count {
                let name = names[index % names.count]
                guard let letter = name.first, var step = letterSteps[letter] else { continue }
                while step <= lastStep { step += 7 }
                lastStep = step

                let x = left + 36 + CGFloat(index) * spacing
                let positionsAboveBottomLine = CGFloat(step - 2)
                let y = staffTop + 4 * lineGap - positionsAboveBottomLine * lineGap / 2

                if step <= 0 {
                    var ledger = Path()
                    ledger.move(to: CGPoint(x: x - 8, y: y))
                    ledger.addLine(to: CGPoint(x: x + 8, y: y))
                    context.stroke(ledger, with: .color(.white.opacity(0.55)), lineWidth: 1)
                }
                let head = Path(ellipseIn: CGRect(x: x - 5.5, y: y - 4, width: 11, height: 8))
                context.fill(head, with: .color(.white))
                if name.count > 1 {
                    context.draw(Text(String(name.dropFirst())).font(.system(size: 12))
                        .foregroundStyle(.white),
                        at: CGPoint(x: x - 13, y: y))
                }
                let degree = index == count - 1 ? degrees[0] : degrees[index]
                context.draw(
                    Text(degree).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange.opacity(0.9)),
                    at: CGPoint(x: x, y: staffTop + 4 * lineGap + 18)
                )
            }
        }
    }
}
