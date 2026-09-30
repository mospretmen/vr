/// Generators for the bundled starter progressions — the offline seed content
/// for backing-track mode. The backend serves the same shapes over the API;
/// these exist so the app works with zero network.
public enum ProgressionTemplate {
    /// Milliseconds per bar of 4/4 at a tempo.
    public static func barMs(bpm: Double) -> Int {
        Int((240_000.0 / bpm).rounded())
    }

    /// Classic 12-bar blues: I7 I7 I7 I7 / IV7 IV7 I7 I7 / V7 IV7 I7 V7.
    public static func twelveBarBlues(in key: PitchClass, bpm: Double = 120) -> ChordTimeline {
        let one = Chord(root: key, quality: .dominant7)
        let four = Chord(root: key.transposed(by: 5), quality: .dominant7)
        let five = Chord(root: key.transposed(by: 7), quality: .dominant7)
        let bars = [one, one, one, one, four, four, one, one, five, four, one, five]
        return timeline(bars: bars, bpm: bpm, key: Scale(root: key, type: .blues))
    }

    /// ii–V–I in a major key, the I held for two bars.
    public static func twoFiveOne(in key: PitchClass, bpm: Double = 120) -> ChordTimeline {
        let two = Chord(root: key.transposed(by: 2), quality: .minor7)
        let five = Chord(root: key.transposed(by: 7), quality: .dominant7)
        let one = Chord(root: key, quality: .major7)
        return timeline(bars: [two, five, one, one], bpm: bpm,
                        key: Scale(root: key, type: .major))
    }

    /// Minor 12-bar blues: i7 i7 i7 i7 / iv7 iv7 i7 i7 / V7 iv7 i7 V7
    /// (dominant V, the harmonic-minor pull).
    public static func minorBlues(in key: PitchClass, bpm: Double = 120) -> ChordTimeline {
        let one = Chord(root: key, quality: .minor7)
        let four = Chord(root: key.transposed(by: 5), quality: .minor7)
        let five = Chord(root: key.transposed(by: 7), quality: .dominant7)
        let bars = [one, one, one, one, four, four, one, one, five, four, one, five]
        return timeline(bars: bars, bpm: bpm, key: Scale(root: key, type: .naturalMinor))
    }

    /// The 50s doo-wop loop: I–vi–IV–V.
    public static func doowop(in key: PitchClass, bpm: Double = 120) -> ChordTimeline {
        let bars = [
            Chord(root: key, quality: .major),
            Chord(root: key.transposed(by: 9), quality: .minor),
            Chord(root: key.transposed(by: 5), quality: .major),
            Chord(root: key.transposed(by: 7), quality: .major),
        ]
        return timeline(bars: bars, bpm: bpm, key: Scale(root: key, type: .major))
    }

    /// The I–V–vi–IV pop loop.
    public static func popLoop(in key: PitchClass, bpm: Double = 120) -> ChordTimeline {
        let bars = [
            Chord(root: key, quality: .major),
            Chord(root: key.transposed(by: 7), quality: .major),
            Chord(root: key.transposed(by: 9), quality: .minor),
            Chord(root: key.transposed(by: 5), quality: .major),
        ]
        return timeline(bars: bars, bpm: bpm, key: Scale(root: key, type: .major))
    }

    static func timeline(bars: [Chord], bpm: Double, key: Scale?) -> ChordTimeline {
        let bar = barMs(bpm: bpm)
        let events = bars.enumerated().map { index, chord in
            ChordEvent(startMs: index * bar, durationMs: bar, chord: chord)
        }
        return ChordTimeline(events: events, key: key)
    }
}
