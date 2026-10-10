import SwiftUI
import MusicTheory

/// The teaching strip under the compass: a mini staff showing the selected
/// chord's tones, and one plain-English line per lit pathway.
struct HarmonyContextCard: View {
    let selected: HarmonyWheel.Node
    let moves: [HarmonyWheel.Move]
    let moveColor: (HarmonyWheel.Move) -> Color

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 4) {
                MiniStaff(chord: selected.chord, label: selected.label)
                    .frame(width: 150, height: 86)
                Text(selected.label).font(.headline)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(moves.enumerated()), id: \.offset) { _, move in
                        HStack(spacing: 6) {
                            Circle().fill(moveColor(move)).frame(width: 8, height: 8)
                            Text(Self.describe(move))
                                .font(.callout)
                                .foregroundStyle(.primary.opacity(0.9))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: .rect(cornerRadius: 14))
        .frame(height: 130)
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
            return "→ \(to): one fifth sharpward around the circle."
        case .fifthFlatward:
            return "→ \(to): one fifth flatward around the circle."
        case .relative:
            return "→ \(to): relative switch — same notes, new home."
        case .passingDim:
            return "→ \(to): chromatic walk-up through the passing dim."
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

                // Ledger line for middle C.
                if step == 0 || step == 14 {
                    var ledger = Path()
                    ledger.move(to: CGPoint(x: x - 9, y: y))
                    ledger.addLine(to: CGPoint(x: x + 9, y: y))
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
