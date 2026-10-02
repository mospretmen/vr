/// A concrete chord grip: one fret (or mute) per string. Unlike computed
/// voicings these are curated — the open "cowboy chords" every guitarist
/// learns first, with their characteristic doublings and omissions.
public struct ChordShape: Codable, Sendable, Hashable {
    public let chord: Chord
    public let name: String
    /// One entry per string, low to high; nil = muted/unplayed.
    public let frets: [Int?]

    public init(chord: Chord, name: String, frets: [Int?]) {
        self.chord = chord
        self.name = name
        self.frets = frets
    }

    /// Sounding positions, low string to high.
    public var positions: [FretPosition] {
        frets.enumerated().compactMap { string, fret in
            fret.map { FretPosition(string: string, fret: $0) }
        }
    }
}

/// The open-position chord library (standard tuning). Shapes are validated
/// by tests against FretboardModel: every sounding note belongs to the
/// chord and the root is present.
public enum OpenChords {
    public static func shapes(for chord: Chord) -> [ChordShape] {
        all.filter { $0.chord == chord }
    }

    public static let all: [ChordShape] = [
        // Major
        shape(.c, .major, "Open C", [nil, 3, 2, 0, 1, 0]),
        shape(.a, .major, "Open A", [nil, 0, 2, 2, 2, 0]),
        shape(.g, .major, "Open G", [3, 2, 0, 0, 0, 3]),
        shape(.e, .major, "Open E", [0, 2, 2, 1, 0, 0]),
        shape(.d, .major, "Open D", [nil, nil, 0, 2, 3, 2]),
        // Minor
        shape(.a, .minor, "Open Am", [nil, 0, 2, 2, 1, 0]),
        shape(.e, .minor, "Open Em", [0, 2, 2, 0, 0, 0]),
        shape(.d, .minor, "Open Dm", [nil, nil, 0, 2, 3, 1]),
        // Dominant sevenths
        shape(.a, .dominant7, "Open A7", [nil, 0, 2, 0, 2, 0]),
        shape(.e, .dominant7, "Open E7", [0, 2, 0, 1, 0, 0]),
        shape(.d, .dominant7, "Open D7", [nil, nil, 0, 2, 1, 2]),
        shape(.g, .dominant7, "Open G7", [3, 2, 0, 0, 0, 1]),
        shape(.c, .dominant7, "Open C7", [nil, 3, 2, 3, 1, 0]),
        shape(.b, .dominant7, "Open B7", [nil, 2, 1, 2, 0, 2]),
        // Common opens beyond the five
        shape(.c, .major7, "Open Cmaj7", [nil, 3, 2, 0, 0, 0]),
        shape(.a, .minor7, "Open Am7", [nil, 0, 2, 0, 1, 0]),
        shape(.e, .minor7, "Open Em7", [0, 2, 2, 0, 3, 0]),
        shape(.d, .sus2, "Open Dsus2", [nil, nil, 0, 2, 3, 0]),
        shape(.d, .sus4, "Open Dsus4", [nil, nil, 0, 2, 3, 3]),
        shape(.a, .sus2, "Open Asus2", [nil, 0, 2, 2, 0, 0]),
    ]

    private static func shape(
        _ root: PitchClass, _ quality: ChordQuality, _ name: String, _ frets: [Int?]
    ) -> ChordShape {
        ChordShape(chord: Chord(root: root, quality: quality), name: name, frets: frets)
    }
}
