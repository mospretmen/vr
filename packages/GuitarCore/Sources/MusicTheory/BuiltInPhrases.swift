import Foundation

/// The Classics: a starter vocabulary of short cells in the style of the
/// masters — original lines teaching the canonical devices (no verbatim
/// transcriptions; see docs/APPSTORE.md review notes). Every phrase is
/// verified against PhraseAnalysis in tests: the explanation must be TRUE.
public enum BuiltInPhrases {
    private static func make(
        _ name: String, _ chord: Chord?, _ remark: String,
        context: String? = nil,
        _ positions: [(Int, Int)]
    ) -> Phrase {
        let board = FretboardModel()
        let steps = positions.map { string, fret -> ExerciseStep in
            let position = FretPosition(string: string, fret: fret)
            return ExerciseStep(position: position, note: board.note(at: position))
        }
        // Stable ids so re-imports can be recognized later.
        let id = UUID(uuidString: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!.uuidString) ?? UUID()
        _ = id
        return Phrase(name: name, chord: chord, steps: steps,
                      remark: remark, context: context, createdAt: .distantPast)
    }

    public static let all: [Phrase] = [
        make("Bebop cell 1·2·3·5 (style of Parker)",
             Chord(root: .d, quality: .minor7),
             "The workhorse cell: outline the chord with 1-2-3-5 — melodic, no 7 needed.",
             [(1, 5), (1, 7), (1, 8), (2, 7)]),
        make("Enclosure of the 3rd (style of Parker)",
             Chord(root: .c, quality: .major7),
             "Surround the target from above and a half step below, then land — bebop's signature move.",
             [(4, 6), (4, 4), (4, 5)]),
        make("♭9 slide into home (style of Parker)",
             Chord(root: .g, quality: .dominant7),
             "3 up to ♭7, touch the ♭9, slide down a half step into the root.",
             [(3, 4), (3, 7), (4, 6), (4, 9), (4, 8)]),
        make("Octave riff cell (style of Wes)",
             Chord(root: .c, quality: .minor7),
             "Play it doubled an octave up with the thumb — melody first, always singable.",
             [(3, 5), (3, 3), (2, 5), (3, 3), (3, 5)]),
        make("Chromatic drop to the root (style of Joe Pass)",
             Chord(root: .g, quality: .dominant7),
             "Walk the 3rd down chromatically until it becomes the root — tension spent one fret at a time.",
             [(3, 4), (3, 3), (3, 2), (3, 1), (3, 0)]),
        make("♯9 bite (style of Kenny Burrell)",
             Chord(root: .c, quality: .dominant7),
             "The blues rub: minor third against a dominant, resolved up into the major 3rd.",
             [(3, 5), (4, 4), (4, 5), (4, 8)]),
        make("1·2·3·5 stack (style of Coltrane)",
             Chord(root: .c, quality: .major7),
             "The Giant-Steps-era building block — stack the cell and move it through the changes.",
             [(3, 5), (3, 7), (4, 5), (4, 8)]),
        make("Falling sigh to the 7 (style of Chet Baker)",
             Chord(root: .f, quality: .major7),
             "Stepwise descent 3-2-1-7: lyrical, patient, lands on the color tone.",
             [(5, 5), (5, 3), (5, 1), (5, 0)]),
        make("Dorian turn (style of Grant Green)",
             Chord(root: .d, quality: .minor7),
             "A singable turn on 3-4-5, resolved back to the root — groove over complexity.",
             [(5, 1), (5, 3), (5, 5), (5, 3), (5, 1), (4, 3)]),
        make("Four notes and air (style of Miles)",
             Chord(root: .d, quality: .minor7),
             "Economy as style: chord tones placed like brushstrokes — the rest is space.",
             context: "static minor vamp",
             [(2, 7), (3, 5), (3, 7), (3, 10), (3, 7)]),
        make("Tritone jab (style of Monk)",
             Chord(root: .g, quality: .dominant7),
             "Poke the ♭5 against the dominant, then land flat-footed on the root — wrong note, right time.",
             [(4, 6), (3, 6), (3, 4), (2, 5)]),
        make("Gospel bounce (style of Cannonball)",
             Chord(root: .f, quality: .dominant7),
             "Major-pentatonic joy over the bar line: 1-3-5-6 and back down to the 5th.",
             [(2, 3), (2, 7), (3, 5), (3, 7), (3, 5)]),
        make("Arpeggio rocket (style of Clifford Brown)",
             Chord(root: .c, quality: .dominant7),
             "Straight up the seventh chord to the high root — clarity at speed.",
             [(3, 5), (4, 5), (4, 8), (5, 6), (5, 8)]),
        make("Chromatic gallop (style of Django)",
             Chord(root: .a, quality: .minor),
             "Every fret on the way up — the gypsy sprint into the root.",
             [(4, 5), (4, 6), (4, 7), (4, 8), (5, 5)]),
        make("Für Elise opening (Beethoven, WoO 59)",
             Chord(root: .a, quality: .minor),
             "Verbatim, public domain: the E–D♯ trembling that resolves down into A minor.",
             [(4, 5), (4, 4), (4, 5), (4, 4), (4, 5), (3, 4), (3, 7), (3, 5), (2, 7)]),
        make("Ode to Joy theme (Beethoven, Op. 125)",
             Chord(root: .g, quality: .major),
             "Verbatim, public domain: stepwise hymn logic — the first phrase breathes on the V (half cadence).",
             context: "half cadence in C",
             [(4, 5), (4, 5), (4, 6), (4, 8), (4, 8), (4, 6), (4, 5), (3, 7)]),
        make("Alla Turca turn (Mozart, K. 331)",
             Chord(root: .a, quality: .minor),
             "Verbatim, public domain: the lower-neighbor turn that launches the Rondo.",
             [(3, 4), (3, 2), (3, 1), (3, 2), (3, 5)]),
        make("Prelude arpeggio (Bach, BWV 846)",
             Chord(root: .c, quality: .major),
             "The C major Prelude's broken chord — public domain, verbatim: let every note ring into the next.",
             [(3, 5), (4, 5), (4, 8), (5, 8), (5, 12)]),
        make("Invention No. 1 opening (Bach, BWV 772)",
             Chord(root: .c, quality: .major),
             "Bach's first lesson, verbatim: step up, turn back, leap to the 5th — melody as architecture.",
             [(3, 5), (3, 7), (4, 5), (4, 6), (3, 7), (4, 5), (3, 5), (4, 8)]),
        make("Descending-thirds sequence (after Bach)",
             Chord(root: .a, quality: .minor),
             "The sequence engine: a figure repeated a third lower each time — baroque motion in one cell.",
             [(4, 5), (3, 5), (3, 7), (3, 4), (3, 5), (2, 7)]),
        make("ii–V–I pocket (style of Parker)",
             Chord(root: .c, quality: .major),
             "Arpeggiate the ii, enclose the landing root — two bars of bebop in seven notes.",
             context: "ii–V–I in C",
             [(2, 3), (2, 7), (3, 5), (4, 5), (3, 7), (3, 4), (3, 5)]),
        make("V–I half-step drop (style of Wes)",
             Chord(root: .f, quality: .major),
             "Ride the ♯9→3 rub on the V, then fall home onto the 3rd of the I.",
             context: "V–I in F",
             [(4, 8), (4, 5), (4, 4), (3, 5), (2, 7)]),
        make("Backdoor descent (common practice)",
             Chord(root: .c, quality: .major),
             "♭7 falls through 6 to 5, then home — the backdoor cadence as a single line.",
             [(3, 3), (3, 2), (3, 0), (3, 5)]),
    ]
}
