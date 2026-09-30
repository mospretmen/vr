import Testing
import MusicTheory
@testable import AudioAnalysis

@Suite("Chromagram")
struct ChromagramTests {
    @Test func normalizationIsUnitLengthAndSilenceSafe() {
        let chroma = Chromagram.synthetic([.c, .e, .g]).normalized
        let magnitude = chroma.energies.map { $0 * $0 }.reduce(0, +)
        #expect(abs(magnitude - 1.0) < 1e-9)
        #expect(Chromagram.silence.normalized == .silence)
    }
}

@Suite("Chord matcher")
struct ChordMatcherTests {
    @Test func cleanTriadsMatchExactly() {
        for (pcs, expected) in [
            ([PitchClass.c, .e, .g], Chord(root: .c, quality: .major)),
            ([.a, .c, .e], Chord(root: .a, quality: .minor)),
            ([.g, .b, .d, .f], Chord(root: .g, quality: .dominant7)),
        ] {
            let match = ChordMatcher.match(.synthetic(pcs))
            #expect(match?.chord == expected, "expected \(expected.symbol)")
        }
    }

    @Test func rootWeightingDisambiguatesRelativeChords() {
        // C major (C,E,G) vs A minor (A,C,E) share two notes; a voicing with a
        // strong C and no A must not come back as A minor.
        let chroma = Chromagram.synthetic([.c, .e, .g], weights: [2.0, 1.0, 1.2])
        let match = ChordMatcher.match(chroma)
        #expect(match?.chord == Chord(root: .c, quality: .major))
    }

    @Test func realisticNoisyVoicingStillMatches() {
        // E major bar chord with overtone bleed on neighboring bins.
        var chroma = Chromagram.synthetic([.e, .gSharp, .b], weights: [2.2, 1.0, 1.6])
        chroma[.fSharp] = 0.25
        chroma[.d] = 0.2
        chroma[.a] = 0.3
        let match = ChordMatcher.match(chroma)
        #expect(match?.chord == Chord(root: .e, quality: .major))
    }

    @Test func silenceAndAmbientNoiseReturnNil() {
        #expect(ChordMatcher.match(.silence) == nil)
        // Flat noise: equally similar to everything → below confidence gate.
        let noise = Chromagram(energies: Array(repeating: 0.5, count: 12))
        #expect(ChordMatcher.match(noise) == nil)
    }

    @Test func singleNoteIsNotReportedAsAChord() {
        let match = ChordMatcher.match(.synthetic([.e]))
        // One pitch class overlaps every chord containing it, but similarity
        // to a 3-note template caps well below a real triad's score.
        if let match {
            #expect(match.score < 0.8)
        }
    }
}

@Suite("Decision smoother")
struct SmootherTests {
    private func match(_ chord: Chord) -> ChordMatcher.Match {
        // Score is irrelevant to the smoother; use a clean template match.
        ChordMatcher.Match(chord: chord, score: 1.0)
    }

    @Test func requiresConsecutiveFramesToSwitch() {
        var smoother = ChordDecisionSmoother(holdFrames: 3)
        let am = Chord(root: .a, quality: .minor)
        let c = Chord(root: .c, quality: .major)

        #expect(smoother.feed(match(am)) == nil)
        #expect(smoother.feed(match(am)) == nil)
        #expect(smoother.feed(match(am)) == am) // 3rd frame locks it

        // One-frame glitch doesn't switch…
        #expect(smoother.feed(match(c)) == am)
        #expect(smoother.feed(match(am)) == am)
        // …an interrupted streak restarts…
        #expect(smoother.feed(match(c)) == am)
        #expect(smoother.feed(match(c)) == am)
        // …a full streak switches.
        #expect(smoother.feed(match(c)) == c)
    }

    @Test func silenceHoldsTheCurrentChord() {
        var smoother = ChordDecisionSmoother(holdFrames: 2)
        let e = Chord(root: .e, quality: .major)
        smoother.feed(match(e))
        smoother.feed(match(e))
        #expect(smoother.feed(nil) == e) // ring-out keeps the aura alive
        smoother.reset()
        #expect(smoother.current == nil)
    }
}
