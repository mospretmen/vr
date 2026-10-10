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
            types = [.naturalMinor, .dorian, .phrygian, .harmonicMinor,
                     .melodicMinor, .minorPentatonic, .blues]
        case .minor7:
            types = [.dorian, .naturalMinor, .phrygian, .minorPentatonic, .blues]
        case .dominant7:
            types = [.mixolydian, .lydianDominant, .altered, .phrygianDominant,
                     .bebopDominant, .blues]
        case .minor7b5:
            types = [.locrian, .locrianNatural2]
        case .diminished, .diminished7:
            types = [.wholeHalfDiminished]
        case .augmented:
            types = [.wholeTone, .lydianAugmented]
        case .sus2, .sus4:
            types = [.mixolydian, .major]
        default:
            types = [.major]
        }
        return types.map { Scale(root: chord.root, type: $0) }
    }
}
