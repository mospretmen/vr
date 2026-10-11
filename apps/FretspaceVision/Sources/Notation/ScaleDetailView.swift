import SwiftUI
import MusicTheory

/// A scale's full card, opened from the Harmony Compass: hear it, read it
/// on the staff with spelled degrees, understand its character, and see
/// it on a realistic fretboard — full neck or one position box.
struct ScaleDetailView: View {
    let scale: Scale

    @State private var labelStyle: LabelStyle = .degrees
    @State private var boxIndex: Int? = nil
    @State private var guideTones = false
    @State private var drillTask: Task<Void, Never>? = nil
    @State private var drillSteps: [ExerciseStep] = []
    @State private var drillCurrent: Int = -1

    /// Walk a drill note by note: the board lights each step as it sounds —
    /// see the thirds move, not just hear them.
    private func playDrill(intervalDegrees: Int) {
        drillTask?.cancel()
        let drill = ExerciseGenerator.scaleInIntervals(
            scale: scale,
            box: board.boxStartFrets(for: scale).first ?? 5,
            intervalDegrees: intervalDegrees,
            on: board)
        drillSteps = drill.steps
        drillTask = Task { @MainActor in
            for (index, step) in drill.steps.enumerated() {
                if Task.isCancelled { return }
                drillCurrent = index
                pads.playVoicing([step.note], durationMs: 210, restart: index == 0)
                try? await Task.sleep(nanoseconds: 230_000_000)
            }
            drillCurrent = -1
            drillSteps = []
        }
    }
    @State private var pads = ChordPadEngine()

    private var board: FretboardModel { FretboardModel() }

    private var highlights: [FretboardHighlight] {
        var all: [FretboardHighlight]
        if let boxIndex,
           board.boxStartFrets(for: scale).indices.contains(boxIndex) {
            all = board.positionBox(
                for: scale, startingAt: board.boxStartFrets(for: scale)[boxIndex])
        } else {
            all = board.highlights(for: scale)
        }
        if !drillSteps.isEmpty {
            // Drill mode: the walked path as exercise steps — the sounding
            // note pops, the rest of the path dims.
            var seen = Set<FretPosition>()
            let currentPosition = drillCurrent >= 0 && drillCurrent < drillSteps.count
                ? drillSteps[drillCurrent].position : nil
            return drillSteps.compactMap { step in
                guard seen.insert(step.position).inserted else { return nil }
                return FretboardHighlight(
                    position: step.position, note: step.note,
                    role: .exerciseStep(isCurrent: step.position == currentPosition))
            }
        }
        return all
    }

    /// One compact cell per degree: note, spelled degree, and the chord
    /// that degree carries (tappable) — the whole formula in a single row.
    private var formulaRow: some View {
        let names = scale.spelledNames()
        let degrees = Modes.degreeLabels(of: scale.type)
        let triads = scale.type.intervals.count == 7
            ? Chord.diatonicTriads(in: scale) : []
        return HStack(spacing: 6) {
            ForEach(0..<names.count, id: \.self) { degree in
                Button {
                    if triads.indices.contains(degree) {
                        pads.play(triads[degree], durationMs: 1200)
                    } else {
                        pads.playVoicing([Note(scale.pitchClasses[degree], octave: 4)],
                                         durationMs: 500, restart: true)
                    }
                } label: {
                    VStack(spacing: 1) {
                        Text(names[degree]).font(.callout.bold())
                        Text(degrees.indices.contains(degree) ? degrees[degree] : "")
                            .font(.caption)
                            .foregroundStyle(.orange.opacity(0.9))
                        if triads.indices.contains(degree) {
                            Text("\(names[degree])\(triads[degree].quality.symbol) · "
                                 + Self.degreeNumeral(degree, triads[degree]))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .frame(minWidth: 62)
                    .padding(.vertical, 5).padding(.horizontal, 4)
                    .background(.white.opacity(0.07), in: .rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private static func degreeNumeral(_ degree: Int, _ chord: Chord) -> String {
        let base = ["I", "II", "III", "IV", "V", "VI", "VII"][degree]
        switch chord.quality {
        case .major: return base
        case .minor: return base.lowercased()
        case .diminished: return base.lowercased() + "°"
        case .augmented: return base + "+"
        default: return base
        }
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

            formulaRow

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
                Toggle("Guide tones", isOn: $guideTones)
                    .toggleStyle(.button)
                    .font(.caption)
                Divider().frame(height: 18)
                Text("Practice in").font(.caption).foregroundStyle(.secondary)
                ForEach([3, 4, 5, 6, 7], id: \.self) { interval in
                    Button("\(interval)ths") {
                        playDrill(intervalDegrees: interval)
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                if !drillSteps.isEmpty {
                    Button {
                        drillTask?.cancel()
                        drillSteps = []
                        drillCurrent = -1
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                Spacer()
            }

            FretboardDiagram(
                highlights: highlights,
                stringCount: 6,
                fretCount: 15,
                labelStyle: labelStyle,
                scale: scale,
                highlightGuideTones: guideTones
            )
            // A real neck's proportions — never stretched by the window.
            .aspectRatio(5.6, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        case .altered: return "Every tension at once (♭9 ♯9 ♯11 ♭13) — maximum pull, for the V7 right before it resolves."
        case .wholeTone: return "Six equal whole steps — weightless and unresolved; the augmented chord's home."
        case .lydianAugmented: return "Lydian with a ♯5 — the shimmering maj7♯5 color from melodic minor."
        case .locrianNatural2: return "Locrian with a usable natural 2 — the melodic-minor answer for m7♭5 chords."
        case .halfWholeDiminished: return "The ♭9 dominant sound — symmetric tension that resolves anywhere a minor third apart."
        case .augmentedScale: return "Minor third + half step, repeating — six notes of pure augmented mystery."
        case .hungarianMinor: return "Harmonic minor with a ♯4 — Gypsy fire, two augmented seconds of drama."
        case .doubleHarmonic: return "The Byzantine major — exotic and ceremonial, flamenco's darker cousin."
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

            let names = scale.spelledNames()
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
                while step < lastStep { step += 7 }
                lastStep = step

                let x = left + 36 + CGFloat(index) * spacing
                let positionsAboveBottomLine = CGFloat(step - 2)
                let y = staffTop + 4 * lineGap - positionsAboveBottomLine * lineGap / 2

                var ledgerSteps: [Int] = []
                if step <= 0 { ledgerSteps = Array(stride(from: 0, through: step, by: -2)) }
                if step >= 12 { ledgerSteps = Array(stride(from: 12, through: step, by: 2)) }
                for ledgerStep in ledgerSteps {
                    let ly = staffTop + 4 * lineGap - CGFloat(ledgerStep - 2) * lineGap / 2
                    var ledger = Path()
                    ledger.move(to: CGPoint(x: x - 8, y: ly))
                    ledger.addLine(to: CGPoint(x: x + 8, y: ly))
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
