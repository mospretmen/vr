import Testing
@testable import MusicTheory

@Suite("Harmony wheel graph")
struct HarmonyWheelTests {
    @Test func nodeCensus() {
        #expect(HarmonyWheel.nodes.count == 39) // 12+12+12+3
        #expect(HarmonyWheel.spokes.count == 12)
        #expect(Set(HarmonyWheel.spokes).count == 12)
    }

    @Test func spokesPairKeysWithRelativesAndDominants() {
        // Spoke 0 = C: relative Am, dominant chip G7.
        #expect(HarmonyWheel.node(.majorKey, 0).chord == Chord(root: .c, quality: .major))
        #expect(HarmonyWheel.node(.relativeMinor, 0).chord == Chord(root: .a, quality: .minor))
        #expect(HarmonyWheel.node(.dominant, 0).chord == Chord(root: .g, quality: .dominant7))
        // Spoke 4 = E: C#m and B7.
        #expect(HarmonyWheel.node(.relativeMinor, 4).chord == Chord(root: .cSharp, quality: .minor))
        #expect(HarmonyWheel.node(.dominant, 4).chord == Chord(root: .b, quality: .dominant7))
    }

    @Test func movesFromCMajor() {
        let moves = HarmonyWheel.moves(from: HarmonyWheel.node(.majorKey, 0))
        let byKind = Dictionary(grouping: moves, by: \.kind)

        #expect(byKind[.toDominant]?.first?.to.chord == Chord(root: .g, quality: .dominant7))
        #expect(byKind[.fifthSharpward]?.first?.to.chord == Chord(root: .g, quality: .major))
        #expect(byKind[.fifthFlatward]?.first?.to.chord == Chord(root: .f, quality: .major))
        #expect(byKind[.relative]?.first?.to.chord == Chord(root: .a, quality: .minor))
    }

    @Test func dominantResolvesHomeAndDeceptively() {
        // G7 (spoke 0) resolves to C and to Am, and trades with a dim hub.
        let moves = HarmonyWheel.moves(from: HarmonyWheel.node(.dominant, 0))
        let targets = Set(moves.filter { $0.kind == .resolve }.map(\.to.chord))
        #expect(targets == [Chord(root: .c, quality: .major), Chord(root: .a, quality: .minor)])

        let hubMove = moves.first { $0.kind == .flatNine }
        // G7's third is B → the hub containing B (the D°7 family).
        #expect(hubMove?.to.ring == .diminished)
        #expect(hubMove?.to.index == HarmonyWheel.hub(containing: .b))
    }

    @Test func relativeMinorEscapesThroughItsOwnDominant() {
        // Am → E7 (the dominant chip on A major's spoke).
        let moves = HarmonyWheel.moves(from: HarmonyWheel.node(.relativeMinor, 0))
        let dominant = moves.first { $0.kind == .toDominant }
        #expect(dominant?.to.chord == Chord(root: .e, quality: .dominant7))
    }

    @Test func diminishedHubsAreFourWayInterchanges() {
        for hub in 0..<3 {
            let moves = HarmonyWheel.moves(from: HarmonyWheel.node(.diminished, hub))
            let leadingTone = moves.filter { $0.kind == .leadingTone }
            let flatNine = moves.filter { $0.kind == .flatNine }
            #expect(leadingTone.count == 4, "hub \(hub) resolves into 4 keys")
            #expect(flatNine.count == 4, "hub \(hub) trades with 4 dominants")

            // The four destination keys sit a minor third apart.
            let keyRoots = Set(leadingTone.map(\.to.chord.root.rawValue))
            #expect(keyRoots.count == 4)
            let sorted = keyRoots.sorted()
            #expect(sorted[1] - sorted[0] == 3 || true) // spacing checked below
            let spacings = zip(sorted, sorted.dropFirst()).map { $1 - $0 }
            #expect(spacings.allSatisfy { $0 == 3 })
        }
    }

    @Test func hubAssignmentPartitionsThePitchClasses() {
        // Every pitch class lands in exactly one of 3 hubs; members of a
        // dim7 chord share a hub.
        for pc in PitchClass.allCases {
            let hub = HarmonyWheel.hub(containing: pc)
            #expect(HarmonyWheel.hub(containing: pc.transposed(by: 3)) == hub)
            #expect(HarmonyWheel.hub(containing: pc.transposed(by: 6)) == hub)
            #expect(HarmonyWheel.hub(containing: pc.transposed(by: 1)) != hub)
        }
    }

    @Test func wheelIsFullyConnected() {
        // From C major you can reach every node by walking moves.
        var visited: Set<HarmonyWheel.Node> = []
        var frontier = [HarmonyWheel.node(.majorKey, 0)]
        while let next = frontier.popLast() {
            guard visited.insert(next).inserted else { continue }
            frontier += HarmonyWheel.moves(from: next).map(\.to)
        }
        #expect(visited.count == HarmonyWheel.nodes.count,
                "unreachable: \(Set(HarmonyWheel.nodes).subtracting(visited).map(\.id))")
    }
}
