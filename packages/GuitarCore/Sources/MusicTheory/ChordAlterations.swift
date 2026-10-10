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
                alt("9sus4", [0, 5, 7, 10, 14], "suspended dominant — modern, floats until the 3rd lands.", .mixolydian),
                alt("7♭9", [0, 4, 7, 10, 13], "the pull into a minor home — or any home, harder.", .halfWholeDiminished),
                alt("13♭9", [0, 4, 7, 10, 13, 21], "♭9 bite with a bright 13 — the half-whole sound in one grip.", .halfWholeDiminished),
                alt("7♯9", [0, 4, 10, 15], "blues grit — the Hendrix bite over major or minor.", .altered),
                alt("7♯11", [0, 4, 7, 10, 18], "lydian-dominant shimmer — the tritone-sub flavor.", .lydianDominant),
                alt("9♯11", [0, 4, 7, 10, 14, 18], "shimmer plus a smooth 9 — full lydian dominant.", .lydianDominant),
                alt("7♭13", [0, 4, 10, 20], "darkened top — leaning into a minor home.", .phrygianDominant),
                alt("7♭9♭13", [0, 4, 7, 10, 13, 20], "the Spanish dominant — phrygian dominant in a grip.", .phrygianDominant),
                alt("7alt", [0, 4, 10, 13, 15, 20], "maximum tension — every note pulls; resolve next.", .altered),
            ]
        case .major:
            return [
                alt("maj7", [0, 4, 7, 11], "the resting color of a key center.", .major),
                alt("maj9", [0, 4, 7, 11, 14], "maj7 with a silky 9 on top — lush and settled.", .major),
                alt("maj13", [0, 4, 7, 11, 14, 21], "the whole key stacked — maximum lush, still at rest.", .major),
                alt("6", [0, 4, 7, 9], "resolved but warmer than maj7 — great on the final chord.", .major),
                alt("6/9", [0, 4, 7, 9, 14], "the gentlest ending in music — 6 and 9, no leading tone.", .major),
                alt("add9", [0, 2, 4, 7], "open, modern sparkle without the 7.", .major),
                alt("maj7♯11", [0, 4, 7, 11, 18], "lydian lift — dreamlike, floats off the ground.", .lydian),
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
            ]
        case .minor7b5:
            return [
                alt("m9♭5", [0, 3, 6, 10, 14], "half-diminished with a usable 9 — the melodic-minor color.", .locrianNatural2),
                alt("m11♭5", [0, 3, 6, 10, 17], "the softened half-diminished — 11 instead of the ♭9 rub.", .locrian),
            ]
        default:
            return []
        }
    }
}
