import Testing
@testable import MusicTheory

@Suite("Harmony wheel graph")
struct HarmonyWheelTests {
    @Test func nodeCensus() {
        #expect(HarmonyWheel.nodes.count == 48) // 4 rings × 12 columns
        #expect(Set(HarmonyWheel.spokes).count == 12)
    }

    @Test func columnZeroIsTheCanonicalFamily() {
        // The owner's exact column: C · Am / E7 / G♯°7.
        #expect(HarmonyWheel.node(.majorKey, 0).chord == Chord(root: .c, quality: .major))
        #expect(HarmonyWheel.node(.relativeMinor, 0).chord == Chord(root: .a, quality: .minor))
        #expect(HarmonyWheel.node(.dominant, 0).chord == Chord(root: .e, quality: .dominant7))
        #expect(HarmonyWheel.node(.diminished, 0).chord == Chord(root: .gSharp, quality: .diminished7))
    }

    @Test func theOwnersWalkIsAllSameColumnOrAdjacent() {
        // C → Am (relative, same column) ✓
        let fromC = HarmonyWheel.moves(from: HarmonyWheel.node(.majorKey, 0))
        #expect(fromC.contains { $0.kind == .relative
            && $0.to.chord == Chord(root: .a, quality: .minor) })
        // C → E7 (straight down) ✓
        #expect(fromC.contains { $0.kind == .toDominant
            && $0.to == HarmonyWheel.node(.dominant, 0) })
        // E7 → Am (straight up) ✓
        let fromE7 = HarmonyWheel.moves(from: HarmonyWheel.node(.dominant, 0))
        #expect(fromE7.contains { $0.kind == .resolve
            && $0.to == HarmonyWheel.node(.relativeMinor, 0) })
        // E7 → G♯°7 (straight down) ✓
        #expect(fromE7.contains { $0.kind == .deepen
            && $0.to == HarmonyWheel.node(.diminished, 0) })
        // G♯°7 → its respelled family mates ✓
        let fromDim = HarmonyWheel.moves(from: HarmonyWheel.node(.diminished, 0))
        let familyHops = fromDim.filter { $0.kind == .dimFamily }.map(\.to)
        #expect(Set(familyHops.map(\.index)) == [3, 9])
        #expect(familyHops.allSatisfy {
            Set($0.chord.pitchClasses) == Set(HarmonyWheel.node(.diminished, 0).chord.pitchClasses)
        })
    }

    @Test func majorsOwnDominantArrivesCrossWheel() {
        // C's own V7 (G7) lives nine columns away and resolves back home.
        let fromC = HarmonyWheel.moves(from: HarmonyWheel.node(.majorKey, 0))
        let ownV7 = fromC.filter { $0.kind == .toDominant }
            .first { $0.to.chord == Chord(root: .g, quality: .dominant7) }
        #expect(ownV7?.to.index == 9)

        let fromG7 = HarmonyWheel.moves(from: HarmonyWheel.node(.dominant, 9))
        #expect(fromG7.contains { $0.kind == .resolve
            && $0.to.chord == Chord(root: .c, quality: .major) })
        #expect(fromG7.contains { $0.kind == .resolve
            && $0.to.chord == Chord(root: .a, quality: .minor) }) // deceptive
    }

    @Test func dominantRingCoversAllTwelveDominants() {
        let roots = Set(HarmonyWheel.nodes.filter { $0.ring == .dominant }.map(\.chord.root))
        #expect(roots.count == 12)
    }

    @Test func diminishedResolutionsAndFamilies() {
        for i in 0..<12 {
            let dim = HarmonyWheel.node(.diminished, i)
            let moves = HarmonyWheel.moves(from: dim)
            // Up into its dominant, up into the minor, across to the major.
            #expect(moves.contains { $0.kind == .resolve && $0.to == HarmonyWheel.node(.dominant, i) })
            #expect(moves.contains { $0.kind == .resolve && $0.to == HarmonyWheel.node(.relativeMinor, i) })
            #expect(moves.contains { $0.kind == .resolve && $0.to == HarmonyWheel.node(.majorKey, (i + 3) % 12) })
            // Family hops preserve pitch content.
            #expect(HarmonyWheel.family(ofDiminishedAt: i)
                    == HarmonyWheel.family(ofDiminishedAt: (i + 3) % 12))
            #expect(HarmonyWheel.family(ofDiminishedAt: i)
                    != HarmonyWheel.family(ofDiminishedAt: (i + 1) % 12))
        }
    }

    @Test func minorsRideTheRimToo() {
        // Am's rim neighbors are Em (sharpward) and Dm (flatward).
        let moves = HarmonyWheel.moves(from: HarmonyWheel.node(.relativeMinor, 0))
        #expect(moves.contains { $0.kind == .fifthSharpward
            && $0.to.chord == Chord(root: .e, quality: .minor) })
        #expect(moves.contains { $0.kind == .fifthFlatward
            && $0.to.chord == Chord(root: .d, quality: .minor) })
    }

    @Test func wheelIsFullyConnected() {
        var visited: Set<HarmonyWheel.Node> = []
        var frontier = [HarmonyWheel.node(.majorKey, 0)]
        while let next = frontier.popLast() {
            guard visited.insert(next).inserted else { continue }
            frontier += HarmonyWheel.moves(from: next).map(\.to)
        }
        #expect(visited.count == HarmonyWheel.nodes.count)
    }
}
