/// Reverse lookup: name the chord(s) a set of pitch classes spells.
/// Backs "what am I holding?" features — the user frets some notes (or the
/// listener hears them) and we say what it is.
public enum ChordIdentifier {
    /// Chords whose tones exactly equal the input set, best reading first.
    /// Enharmonic ambiguity is real (C6 = Am7, Csus2 = Gsus4): every valid
    /// reading is returned; callers show the first and offer the rest.
    public static func identify(_ pitchClasses: Set<PitchClass>) -> [Chord] {
        guard pitchClasses.count >= 2 else { return [] }
        var matches: [Chord] = []
        for root in PitchClass.allCases where pitchClasses.contains(root) {
            for quality in ChordQuality.all {
                let chord = Chord(root: root, quality: quality)
                if Set(chord.pitchClasses) == pitchClasses {
                    matches.append(chord)
                }
            }
        }
        // Stable, musically sensible order: simpler qualities first, then
        // root pitch order.
        return matches.sorted { lhs, rhs in
            let li = ChordQuality.all.firstIndex(of: lhs.quality) ?? .max
            let ri = ChordQuality.all.firstIndex(of: rhs.quality) ?? .max
            if li != ri { return li < ri }
            return lhs.root.rawValue < rhs.root.rawValue
        }
    }

    /// Best single reading for a set of sounding positions on a fretboard,
    /// using the lowest sounding note as the preferred root (how players
    /// actually name what they're holding).
    public static func identify(
        positions: [FretPosition],
        on model: FretboardModel
    ) -> Chord? {
        let notes = positions.map { model.note(at: $0) }
        guard let bass = notes.min() else { return nil }
        let matches = identify(Set(notes.map(\.pitchClass)))
        return matches.first { $0.root == bass.pitchClass } ?? matches.first
    }
}
