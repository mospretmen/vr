/// Context-correct alterations and extensions for a chord: what a player may
/// add on top, why, and the scale that covers the sound. Ordered mild → spicy.
public struct ChordAlteration: Sendable, Hashable {
    /// Chord-symbol suffix spelled out, e.g. "7♭9".
    public let label: String
    /// The playable altered chord (intervals may exceed the octave).
    public let chord: Chord
    /// When this alteration is the right call.
    public let hint: String
    /// The scale that contains every note of it.
    public let scale: ScaleType
}

public enum ChordAlterations {
    public static func options(for chord: Chord) -> [ChordAlteration] {
        let r = chord.root
        func alt(_ suffix: String, _ intervals: [Int], _ hint: String,
                 _ scale: ScaleType) -> ChordAlteration {
            let quality = ChordQuality(name: suffix, symbol: suffix, intervals: intervals)
            return ChordAlteration(label: "\(r.name())\(suffix)",
                                   chord: Chord(root: r, quality: quality),
                                   hint: hint, scale: scale)
        }
        switch chord.quality {
        case .dominant7:
            return [
                alt("9", [0, 4, 7, 10, 14], "smooth and settled — heading to a major home.", .mixolydian),
                alt("13", [0, 4, 7, 10, 14, 21], "the full bright dominant — classic to a major home.", .mixolydian),
                alt("7sus4", [0, 5, 7, 10], "suspended dominant — the 4 waits to fall to the 3rd.", .mixolydian),
                alt("9sus4", [0, 5, 7, 10, 14], "suspended dominant — modern, floats until the 3rd lands.", .mixolydian),
                alt("13sus4", [0, 5, 7, 10, 14, 21], "the full suspended stack — gospel and neo-soul.", .mixolydian),
                alt("7♭9", [0, 4, 7, 10, 13], "the pull into a minor home — or any home, harder.", .halfWholeDiminished),
                alt("13♭9", [0, 4, 7, 10, 13, 21], "♭9 bite with a bright 13 — the half-whole sound in one grip.", .halfWholeDiminished),
                alt("7♯9", [0, 4, 10, 15], "blues grit — the Hendrix bite over major or minor.", .altered),
                alt("7♯11", [0, 4, 7, 10, 18], "lydian-dominant shimmer — the tritone-sub flavor.", .lydianDominant),
                alt("9♯11", [0, 4, 7, 10, 14, 18], "shimmer plus a smooth 9 — full lydian dominant.", .lydianDominant),
                alt("13♯11", [0, 4, 7, 10, 14, 18, 21], "everything lydian dominant offers in one chord.", .lydianDominant),
                alt("7♭5", [0, 4, 6, 10], "flattened core — whole-tone ambiguity before resolving.", .wholeTone),
                alt("9♭5", [0, 4, 6, 10, 14], "♭5 with a smooth 9 — floating whole-tone dominant.", .wholeTone),
                alt("7♯5", [0, 4, 8, 10], "augmented dominant — pushes up hard into the next chord.", .wholeTone),
                alt("9♯5", [0, 4, 8, 10, 14], "augmented with a 9 — the dreamy strong pull.", .wholeTone),
                alt("7♭13", [0, 4, 10, 20], "darkened top — leaning into a minor home.", .phrygianDominant),
                alt("7♭9♭13", [0, 4, 7, 10, 13, 20], "the Spanish dominant — phrygian dominant in a grip.", .phrygianDominant),
                alt("7♯9♭13", [0, 4, 10, 15, 20], "dark grit — altered-scale bite, top and bottom.", .altered),
                alt("7alt", [0, 4, 10, 13, 15, 20], "maximum tension — every note pulls; resolve next.", .altered),
            ]
        case .major, .major7:
            return [
                alt("maj7", [0, 4, 7, 11], "the resting color of a key center.", .major),
                alt("maj9", [0, 4, 7, 11, 14], "maj7 with a silky 9 on top — lush and settled.", .major),
                alt("maj13", [0, 4, 7, 11, 14, 21], "the whole key stacked — maximum lush, still at rest.", .major),
                alt("6", [0, 4, 7, 9], "resolved but warmer than maj7 — great on the final chord.", .major),
                alt("6/9", [0, 4, 7, 9, 14], "the gentlest ending in music — 6 and 9, no leading tone.", .major),
                alt("add9", [0, 2, 4, 7], "open, modern sparkle without the 7.", .major),
                alt("maj7♯11", [0, 4, 7, 11, 18], "lydian lift — dreamlike, floats off the ground.", .lydian),
                alt("maj7♯5", [0, 4, 8, 11], "the shimmering augmented-major — melodic minor's crown.", .lydianAugmented),
            ]
        case .minor, .minor7:
            return [
                alt("m7", [0, 3, 7, 10], "the everyday minor seventh.", .dorian),
                alt("m9", [0, 3, 7, 10, 14], "silky — the pretty minor.", .dorian),
                alt("m11", [0, 3, 7, 10, 14, 17], "stacked and modern — the quartal minor wash.", .dorian),
                alt("m13", [0, 3, 7, 10, 14, 21], "the full dorian color in one chord.", .dorian),
                alt("m6", [0, 3, 7, 9], "bright minor — dorian in one chord.", .dorian),
                alt("m6/9", [0, 3, 7, 9, 14], "bright and silky at once — the suave minor ending.", .dorian),
                alt("m(add9)", [0, 2, 3, 7], "open minor sparkle without the 7.", .dorian),
                alt("m(maj7)", [0, 3, 7, 11], "noir drama — the raised 7 pulling home.", .harmonicMinor),
                alt("m(maj9)", [0, 3, 7, 11, 14], "noir with a silk lining — melodic minor at rest.", .melodicMinor),
                alt("m7(♭9)", [0, 3, 7, 10, 13], "the phrygian minor — dark Spanish shading.", .phrygian),
                alt("m7♯5", [0, 3, 8, 10], "minor with the ♭6 ache — pure natural-minor color.", .naturalMinor),
            ]
        case .minor7b5:
            return [
                alt("m9♭5", [0, 3, 6, 10, 14], "half-diminished with a usable 9 — the melodic-minor color.", .locrianNatural2),
                alt("m11♭5", [0, 3, 6, 10, 17], "the softened half-diminished — 11 instead of the ♭9 rub.", .locrian),
            ]
        case .diminished, .diminished7:
            return [
                alt("°(maj7)", [0, 3, 6, 9, 11], "the dim chord's one upward color — a maj7 on top.", .wholeHalfDiminished),
            ]
        case .augmented:
            return [
                alt("+maj7", [0, 4, 8, 11], "augmented at rest — the maj7♯5 shimmer.", .lydianAugmented),
                alt("+7", [0, 4, 8, 10], "augmented in motion — a whole-tone dominant.", .wholeTone),
            ]
        case .sus2, .sus4:
            return [
                alt("7sus4", [0, 5, 7, 10], "suspended dominant — the 4 waits to fall.", .mixolydian),
                alt("9sus4", [0, 5, 7, 10, 14], "modern floating dominant.", .mixolydian),
                alt("13sus4", [0, 5, 7, 10, 14, 21], "the full suspended stack.", .mixolydian),
            ]
        default:
            return []
        }
    }
}
