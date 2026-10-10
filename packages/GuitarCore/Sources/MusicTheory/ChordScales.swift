/// Which scales a player reaches for over a given chord — the bridge from
/// the harmony compass to the fretboard. Ordered most-idiomatic first.
public enum ChordScales {
    public static func suggestions(for chord: Chord) -> [Scale] {
        let types: [ScaleType]
        switch chord.quality {
        case .major:
            types = [.major, .lydian, .majorPentatonic, .mixolydian]
        case .major7:
            types = [.major, .lydian, .majorPentatonic]
        case .minor:
            types = [.naturalMinor, .dorian, .harmonicMinor, .melodicMinor,
                     .minorPentatonic, .blues]
        case .minor7:
            types = [.dorian, .naturalMinor, .minorPentatonic, .blues]
        case .dominant7:
            types = [.mixolydian, .lydianDominant, .phrygianDominant,
                     .bebopDominant, .blues]
        case .minor7b5:
            types = [.locrian]
        case .diminished, .diminished7:
            types = [.wholeHalfDiminished]
        case .augmented:
            types = [.melodicMinor] // #5 lives in melodic minor's 3rd mode
        case .sus2, .sus4:
            types = [.mixolydian, .major, .majorPentatonic]
        default:
            types = [.major]
        }
        return types.map { Scale(root: chord.root, type: $0) }
    }
}
