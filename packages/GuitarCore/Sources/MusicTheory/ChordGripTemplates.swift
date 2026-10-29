/// The curated grip dictionary: movable shapes exactly as chord charts
/// print them, keyed by the quality's interval content. These lead the
/// voicing list; the generative search only fills what no template covers.
///
/// Each shape is a fret offset per string relative to the ROOT fret on its
/// anchor string (the first non-muted string, always offset 0). Standard
/// tuning only — other tunings fall back to the generator.
public enum ChordGripTemplates {
    /// catalog[intervalSet] = shapes, best-known first.
    /// E-root = anchored on string 0 (low E), A-root = string 1.
    static let catalog: [Set<Int>: [[Int?]]] = [
        // maj7 — Gmaj7 3x443x · Cmaj7 x35453 · C-shape x32000 · D-shape xx0222
        [0, 4, 7, 11]: [[0, nil, 1, 1, 0, nil], [nil, 0, 2, 1, 2, 0],
                        [nil, 0, -1, -3, -3, -3], [nil, nil, 0, 2, 2, 2]],
        // 7 — G7 353433 · C7 x35353 · C7-shape x32310 · D7-shape xx0212 · G7-shape 320001
        [0, 4, 7, 10]: [[0, 2, 0, 1, 0, 0], [nil, 0, 2, 0, 2, 0],
                        [nil, 0, -1, 0, -2, -3], [nil, nil, 0, 2, 1, 2],
                        [0, -1, -3, -3, -3, -2]],
        // m7 — Gm7 353333 · Cm7 x35343 · Dm7-shape xx0211
        [0, 3, 7, 10]: [[0, 2, 0, 0, 0, 0], [nil, 0, 2, 0, 1, 0],
                        [nil, nil, 0, 2, 1, 1]],
        // m7♭5 — Gm7♭5 3x332x · Cm7♭5 x3434x
        [0, 3, 6, 10]: [[0, nil, 0, 0, -1, nil], [nil, 0, 1, 0, 1, nil]],
        // dim7 — G°7 3x232x · C°7 x3424x
        [0, 3, 6, 9]: [[0, nil, -1, 0, -1, nil], [nil, 0, 1, -1, 1, nil]],
        // m(maj7) — GmM7 3x433x · CmM7 x3544x
        [0, 3, 7, 11]: [[0, nil, 1, 0, 0, nil], [nil, 0, 2, 1, 1, nil]],
        // 6 — G6 3x243x · C6 x35555
        [0, 4, 7, 9]: [[0, nil, -1, 1, 0, nil], [nil, 0, 2, 2, 2, 2]],
        // m6 — Gm6 3x233x · Cm6 x3121x
        [0, 3, 7, 9]: [[0, nil, -1, 0, 0, nil], [nil, 0, -2, -1, -2, nil]],
        // maj9 — Cmaj9 x3243x
        [0, 2, 4, 7, 11]: [[nil, 0, -1, 1, 0, nil]],
        // 9 — C9 x32333
        [0, 2, 4, 7, 10]: [[nil, 0, -1, 0, 0, 0]],
        // 13 — C13 x32335
        [0, 2, 4, 7, 9, 10]: [[nil, 0, -1, 0, 0, 2]],
        // m9 — Cm9 x31333 (5th omitted, as charts print it) · Gm9 353335
        [0, 2, 3, 7, 10]: [[nil, 0, -2, 0, 0, 0], [0, 2, 0, 0, 0, 2]],
        // m11 — Gm11 3x331x (compact) · 333333 (full barre) · Cm11 x3334x
        [0, 2, 3, 5, 7, 10]: [[0, nil, 0, 0, -2, nil],
                              [0, 0, 0, 0, 0, 0],
                              [nil, 0, 0, 0, 1, nil]],
        // 6/9 — C6/9 x32233
        [0, 2, 4, 7, 9]: [[nil, 0, -1, -1, 0, 0]],
        // 7♭9 — C7♭9 x3232x
        [0, 1, 4, 7, 10]: [[nil, 0, -1, 0, -1, nil]],
        // 7♯9 — C7♯9 x3234x (the Hendrix)
        [0, 3, 4, 10]: [[nil, 0, -1, 0, 1, nil]],
        // 7♯5 — G7♯5 3x344x
        [0, 4, 8, 10]: [[0, nil, 0, 1, 1, nil]],
        // 7♭5 — G7♭5 3x342x
        [0, 4, 6, 10]: [[0, nil, 0, 1, -1, nil]],
        // 7sus4 — C7sus4 x35363
        [0, 5, 7, 10]: [[nil, 0, 2, 0, 3, 0]],
        // 9sus4 — C9sus4 x33333
        [0, 2, 5, 7, 10]: [[nil, 0, 0, 0, 0, 0]],
    ]

    /// Every instantiation of the chord's template shapes along the neck,
    /// ordered low to high. Empty when no template covers the quality.
    public static func grips(for chord: Chord, tuning: Tuning = .standard) -> [Voicing] {
        guard tuning == .standard else { return [] }
        let key = Set(chord.quality.intervals.map { (($0 % 12) + 12) % 12 })
        guard let shapes = catalog[key] else { return [] }
        let board = FretboardModel(tuning: tuning)

        var grips: [Voicing] = []
        for offsets in shapes {
            guard let anchor = offsets.firstIndex(where: { $0 != nil }) else { continue }
            for rootFret in 0...12 {
                let anchorPos = FretPosition(string: anchor, fret: rootFret)
                guard board.note(at: anchorPos).pitchClass == chord.root else { continue }
                let frets = offsets.map { $0.map { rootFret + $0 } }
                guard frets.compactMap({ $0 }).allSatisfy({ $0 >= 0 && $0 <= 15 })
                else { continue }
                grips.append(Voicing(frets: frets))
            }
        }
        var seen = Set<Voicing>()
        return grips.filter { seen.insert($0).inserted }
                    .sorted { $0.neckPosition < $1.neckPosition }
    }
}
