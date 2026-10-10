import SwiftUI
import MusicTheory

/// The teaching strip under the compass: a mini staff showing the selected
/// chord's tones, and one plain-English line per lit pathway.
struct HarmonyContextCard: View {
    let selected: HarmonyWheel.Node
    let moves: [HarmonyWheel.Move]
    let moveColor: (HarmonyWheel.Move) -> Color
    let onSelectScale: (Scale) -> Void
    let onShowVoicings: () -> Void
    let onHearChord: (Chord) -> Void
    let onOpenChord: (Chord) -> Void
    @State private var pickedAlteration: ChordAlteration?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The staff and title follow a tapped alteration, so you see
            // exactly the stack you're hearing.
            MiniStaff(chord: pickedAlteration?.chord ?? selected.chord,
                      label: pickedAlteration?.label ?? selected.label)
                .frame(height: 92)
                .frame(maxWidth: .infinity)
            Text(pickedAlteration?.label ?? selected.label)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
            Divider()
            Button {
                onShowVoicings()
            } label: {
                Label("Voicings & triads on the fretboard", systemImage: "hand.raised.fingers.spread")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(.orange.opacity(0.3), in: .capsule)
            }
            .buttonStyle(.plain)
            Text("Scales to play").font(.caption.bold()).foregroundStyle(.secondary)
            FlowChips(scales: ChordScales.suggestions(for: selected.chord),
                      onTap: onSelectScale)
            AlterationChips(chord: selected.chord, picked: $pickedAlteration,
                            onHear: onHearChord, onOpenChord: onOpenChord)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(moves.enumerated()), id: \.offset) { _, move in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Circle().fill(moveColor(move)).frame(width: 9, height: 9)
                            Text(Self.describe(move))
                                .font(.callout)
                                .foregroundStyle(.primary.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .onChange(of: selected) { pickedAlteration = nil }
        .padding(16)
        .background(.thinMaterial, in: .rect(cornerRadius: 14))
        .frame(width: 300)
        .frame(maxHeight: .infinity)
    }

    /// Plain-English meaning of a pathway, for the player not the theorist.
    static func describe(_ move: HarmonyWheel.Move) -> String {
        let to = move.to.label
        switch move.kind {
        case .resolve:
            return "→ \(to): resolve — the tension releases home."
        case .deceptive:
            return "→ \(to): deceptive — slips to the relative instead of home."
        case .toDominant:
            return "→ \(to): raise tension on its dominant."
        case .twoFive:
            return "→ \(to): ii–V — you're the ii; this is your V."
        case .fifthSharpward:
            if move.from.ring == .dominant && move.to.ring == .dominant {
                return "→ \(to): back up the chain — the V7 of your V7."
            }
            return "→ \(to): up a fifth — to the dominant side (its V)."
        case .fifthFlatward:
            if move.from.ring == .dominant && move.to.ring == .dominant {
                return "→ \(to): the dominant chain — resolve down a fifth, stay dominant."
            }
            return "→ \(to): up a fourth — to the subdominant side (its IV)."
        case .relative:
            return "→ \(to): relative switch — same notes, new home."
        case .passingDim:
            return "→ \(to): chromatic walk-up through the passing dim."
        case .tritoneSub:
            switch (move.from.ring, move.to.ring) {
            case (.dominant, .dominant):
                return "→ \(to): tritone sub — same 3rd & 7th, slides down a half-step into the same home."
            case (.dominant, _):
                return "→ \(to): resolve home — the sub lands a half-step down."
            default:
                return "→ \(to): sub of your V7 (♭II7) — then it slides a half-step back home."
            }
        case .deepen:
            return "→ \(to): darken into the 7♭9 diminished."
        case .dimFamily:
            return "→ \(to): same four notes respelled — pivot a minor third."
        }
    }
}

/// A compact treble staff rendering the chord's tones as stacked
/// note heads with accidentals, honoring the node's flat/sharp spelling.
struct MiniStaff: View {
    let chord: Chord
    let label: String

    var body: some View {
        Canvas { context, size in
            let lineGap: CGFloat = 9
            let staffTop = size.height / 2 - 2 * lineGap
            let left: CGFloat = 34
            let right = size.width - 8

            for line in 0..<5 {
                let y = staffTop + CGFloat(line) * lineGap
                var path = Path()
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: right, y: y))
                context.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 1)
            }
            context.draw(
                Text("𝄞").font(.system(size: 46)).foregroundStyle(.white.opacity(0.85)),
                at: CGPoint(x: left - 16, y: staffTop + 2 * lineGap)
            )

            // Note heads, stacked by spelled letter.
            let useFlats = label.contains("♭")
            let spelled = chord.pitchClasses.map { pc in
                pc.name(useFlats ? .flats : .sharps)
            }
            let letterSteps: [Character: Int] = ["C": 0, "D": 1, "E": 2, "F": 3,
                                                 "G": 4, "A": 5, "B": 6]
            // Bottom staff line (E4) = step 2 above middle C's 0.
            var lastStep = -10
            var x = left + 34
            for name in spelled {
                guard let letter = name.first, var step = letterSteps[letter] else { continue }
                while step <= lastStep { step += 7 } // stack strictly upward
                lastStep = step

                // steps above middle C → y (E4 bottom line is step 2).
                let positionsAboveBottomLine = CGFloat(step - 2)
                let y = staffTop + 4 * lineGap - positionsAboveBottomLine * lineGap / 2

                // Ledger lines: every line position between the staff and
                // the note (middle C below, A5/C6/… above).
                var ledgerSteps: [Int] = []
                if step <= 0 { ledgerSteps = Array(stride(from: 0, through: step, by: -2)) }
                if step >= 12 { ledgerSteps = Array(stride(from: 12, through: step, by: 2)) }
                for ledgerStep in ledgerSteps {
                    let ly = staffTop + 4 * lineGap - CGFloat(ledgerStep - 2) * lineGap / 2
                    var ledger = Path()
                    ledger.move(to: CGPoint(x: x - 9, y: ly))
                    ledger.addLine(to: CGPoint(x: x + 9, y: ly))
                    context.stroke(ledger, with: .color(.white.opacity(0.55)), lineWidth: 1)
                }

                let head = Path(ellipseIn: CGRect(x: x - 6, y: y - 4.5, width: 12, height: 9))
                context.fill(head, with: .color(.white))

                if name.count > 1 {
                    context.draw(
                        Text(String(name.dropFirst())).font(.system(size: 13))
                            .foregroundStyle(.white),
                        at: CGPoint(x: x - 14, y: y)
                    )
                }
                x += 24
            }
        }
    }
}


/// Compact tappable scale chips, two per row.
struct FlowChips: View {
    let scales: [Scale]
    let onTap: (Scale) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                  alignment: .leading, spacing: 6) {
            ForEach(Array(scales.enumerated()), id: \.offset) { _, scale in
                Button {
                    onTap(scale)
                } label: {
                    Text(scale.type.name)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(.blue.opacity(0.22), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }
}


/// Context-correct alterations for the selected chord: tap to hear one,
/// and the why + covering scale appears beneath.
struct AlterationChips: View {
    let chord: Chord
    @Binding var picked: ChordAlteration?
    let onHear: (Chord) -> Void
    let onOpenChord: (Chord) -> Void

    @State private var expanded = false

    var body: some View {
        let options = ChordAlterations.options(for: chord)
        let shown = expanded ? options : Array(options.prefix(6))
        if !options.isEmpty {
            HStack {
                Text("Alterations").font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                if options.count > 6 {
                    Button(expanded ? "Fewer" : "All \(options.count)…") {
                        expanded.toggle()
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                GridItem(.flexible())],
                      alignment: .leading, spacing: 6) {
                ForEach(shown, id: \.label) { option in
                    Button {
                        picked = option
                        onHear(option.chord)
                    } label: {
                        Text(option.label)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(picked?.label == option.label
                                            ? .orange.opacity(0.4) : .white.opacity(0.1),
                                        in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let picked {
                Text("\(picked.hint) · \(picked.scale.name)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    onOpenChord(picked.chord)
                } label: {
                    Label("Grips & inversions for \(picked.label)",
                          systemImage: "hand.raised.fingers.spread")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.3), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
