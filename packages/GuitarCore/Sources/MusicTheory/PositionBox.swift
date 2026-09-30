/// Restricting highlights to playable regions of the neck — fret windows and
/// compact "position boxes" (the building block for CAGED-style pattern study).
extension FretboardModel {
    /// Highlights filtered to a fret window (open strings included only when
    /// the window contains fret 0).
    public func highlights(for scale: Scale, frets window: ClosedRange<Int>) -> [FretboardHighlight] {
        highlights(for: scale).filter { window.contains($0.position.fret) }
    }

    public func highlights(for chord: Chord, frets window: ClosedRange<Int>) -> [FretboardHighlight] {
        highlights(for: chord).filter { window.contains($0.position.fret) }
    }

    /// A compact scale box: on each string, the notes of the scale within a
    /// `span`-fret reach starting at `startFret` (default 5 frets ≈ one hand
    /// position with a stretch). This is how players learn scales — one box
    /// at a time, then connecting boxes up the neck.
    public func positionBox(
        for scale: Scale,
        startingAt startFret: Int,
        span: Int = 5
    ) -> [FretboardHighlight] {
        let window = startFret...(startFret + span - 1)
        return highlights(for: scale, frets: window)
    }

    /// Starting frets of the five consecutive boxes covering one octave up
    /// the neck for a scale — each box begins where the scale's next note
    /// appears on the lowest string at or after the previous box's start.
    public func boxStartFrets(for scale: Scale, count: Int = 5) -> [Int] {
        guard count > 0 else { return [] }
        var starts: [Int] = []
        var fret = 0
        while starts.count < count && fret <= fretCount {
            let note = note(at: FretPosition(string: 0, fret: fret))
            if scale.contains(note.pitchClass) {
                starts.append(fret)
                fret += 1
                // Skip ahead to the next scale tone on the low string.
                while fret <= fretCount,
                      !scale.contains(self.note(at: FretPosition(string: 0, fret: fret)).pitchClass) {
                    fret += 1
                }
            } else {
                fret += 1
            }
        }
        return starts
    }
}
