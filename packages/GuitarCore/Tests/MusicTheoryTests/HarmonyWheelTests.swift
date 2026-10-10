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
        #expect(Set(familyHops.map(\.index)) == [3, 6, 9]) // full clique
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
        #expect(fromG7.contains { $0.kind == .deceptive
            && $0.to.chord == Chord(root: .a, quality: .minor) })
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

    @Test func minorsJumpIntoTheirTwoFiveDominant() {
        // Am is the ii of G: Am → D7. Dm is the ii of C: Dm → G7.
        let fromAm = HarmonyWheel.moves(from: HarmonyWheel.node(.relativeMinor, 0))
        #expect(fromAm.contains { $0.kind == .twoFive
            && $0.to.chord == Chord(root: .d, quality: .dominant7) })

        let dmColumn = HarmonyWheel.nodes.first {
            $0.ring == .relativeMinor && $0.chord.root == .d
        }!.index
        let fromDm = HarmonyWheel.moves(from: HarmonyWheel.node(.relativeMinor, dmColumn))
        #expect(fromDm.contains { $0.kind == .twoFive
            && $0.to.chord == Chord(root: .g, quality: .dominant7) })
    }

    @Test func passingDiminishedWalksUpAHalfStep() {
        // F → F♯°7 (the owner's chromatic walk: F, F♯°7, Gm, G♯°7...).
        let fColumn = HarmonyWheel.nodes.first {
            $0.ring == .majorKey && $0.chord.root == .f
        }!.index
        let fromF = HarmonyWheel.moves(from: HarmonyWheel.node(.majorKey, fColumn))
        let fDim = fromF.first { $0.kind == .passingDim }
        #expect(fDim?.to.chord == Chord(root: .fSharp, quality: .diminished7))

        // Gm → G♯°7, and F♯°7 → Gm already exists to chain them.
        let gmColumn = HarmonyWheel.nodes.first {
            $0.ring == .relativeMinor && $0.chord.root == .g
        }!.index
        let fromGm = HarmonyWheel.moves(from: HarmonyWheel.node(.relativeMinor, gmColumn))
        #expect(fromGm.first { $0.kind == .passingDim }?.to.chord
                == Chord(root: .gSharp, quality: .diminished7))
        let fSharpDimCol = HarmonyWheel.nodes.first {
            $0.ring == .diminished && $0.chord.root == .fSharp
        }!.index
        let fromFSharpDim = HarmonyWheel.moves(from: HarmonyWheel.node(.diminished, fSharpDimCol))
        #expect(fromFSharpDim.contains { $0.kind == .resolve
            && $0.to.chord == Chord(root: .g, quality: .minor) })
    }

    @Test func minorsRideTheRimToo() {
        // Am's rim neighbors are Em (sharpward) and Dm (flatward).
        let moves = HarmonyWheel.moves(from: HarmonyWheel.node(.relativeMinor, 0))
        #expect(moves.contains { $0.kind == .fifthSharpward
            && $0.to.chord == Chord(root: .e, quality: .minor) })
        #expect(moves.contains { $0.kind == .fifthFlatward
            && $0.to.chord == Chord(root: .d, quality: .minor) })
    }

    @Test func flatSideSpellsLikeARealCircleOfFifths() {
        // Columns 7–10 are the flat keys: D♭, A♭, E♭, B♭ — never sharps.
        #expect(HarmonyWheel.node(.majorKey, 7).label == "D♭")
        #expect(HarmonyWheel.node(.majorKey, 8).label == "A♭")
        #expect(HarmonyWheel.node(.majorKey, 9).label == "E♭")
        #expect(HarmonyWheel.node(.majorKey, 10).label == "B♭")
        #expect(HarmonyWheel.node(.relativeMinor, 7).label == "B♭m")
        // F♯ keeps its conventional sharp name.
        #expect(HarmonyWheel.node(.majorKey, 6).label == "F♯")
        // Leading-tone functions stay sharp even in flat columns:
        // B♭'s column carries F♯°7 (resolving to Gm), not G♭°7.
        #expect(HarmonyWheel.node(.diminished, 10).label == "F♯°7")
        // And naturals are untouched: B♭'s dominant chip is D7.
        #expect(HarmonyWheel.node(.dominant, 10).label == "D7")
    }

    @Test func oneWayStreetsAreKnown() {
        func move(_ fromRing: HarmonyWheel.Ring, _ fromIdx: Int,
                  _ kind: HarmonyWheel.MoveKind,
                  toChord: Chord) -> HarmonyWheel.Move? {
            HarmonyWheel.moves(from: HarmonyWheel.node(fromRing, fromIdx))
                .first { $0.kind == kind && $0.to.chord == toChord }
        }

        // Two-way: E7 ⇄ Am (resolve down ↔ toDominant up).
        let e7toAm = move(.dominant, 0, .resolve,
                          toChord: Chord(root: .a, quality: .minor))!
        #expect(HarmonyWheel.isTwoWay(e7toAm))
        // Two-way: relative pair, rim fifths.
        let cToAm = move(.majorKey, 0, .relative,
                         toChord: Chord(root: .a, quality: .minor))!
        #expect(HarmonyWheel.isTwoWay(cToAm))

        // One-way: C → E7 (E7 never resolves back to C).
        let cToE7 = move(.majorKey, 0, .toDominant,
                         toChord: Chord(root: .e, quality: .dominant7))!
        #expect(!HarmonyWheel.isTwoWay(cToE7))
        // One-way: the deceptive resolution G7 → Am.
        let g7toAm = move(.dominant, 9, .deceptive,
                          toChord: Chord(root: .a, quality: .minor))!
        #expect(!HarmonyWheel.isTwoWay(g7toAm))
        // One-way: the ii–V jump (G7 doesn't resolve to Dm).
        let dmCol = HarmonyWheel.nodes.first {
            $0.ring == .relativeMinor && $0.chord.root == .d
        }!.index
        let dmToG7 = move(.relativeMinor, dmCol, .twoFive,
                          toChord: Chord(root: .g, quality: .dominant7))!
        #expect(!HarmonyWheel.isTwoWay(dmToG7))
    }

    @Test func romanNumeralsReadLikeATextbookInC() {
        func numeral(_ ring: HarmonyWheel.Ring, _ root: PitchClass,
                     _ quality: ChordQuality) -> String {
            let node = HarmonyWheel.nodes.first {
                $0.ring == ring && $0.chord == Chord(root: root, quality: quality)
            }!
            return HarmonyWheel.romanNumeral(for: node, inKey: .c)
        }
        #expect(numeral(.majorKey, .c, .major) == "I")
        #expect(numeral(.majorKey, .f, .major) == "IV")
        #expect(numeral(.majorKey, .aSharp, .major) == "♭VII")
        #expect(numeral(.relativeMinor, .a, .minor) == "vi")
        #expect(numeral(.relativeMinor, .d, .minor) == "ii")
        #expect(numeral(.relativeMinor, .g, .minor) == "v")
        #expect(numeral(.dominant, .g, .dominant7) == "V7")
        #expect(numeral(.dominant, .e, .dominant7) == "V7/vi")
        #expect(numeral(.dominant, .d, .dominant7) == "V7/V")
        #expect(numeral(.dominant, .c, .dominant7) == "V7/IV")
        #expect(numeral(.diminished, .b, .diminished7) == "vii°7")
        #expect(numeral(.diminished, .gSharp, .diminished7) == "vii°7/vi")
        #expect(numeral(.diminished, .fSharp, .diminished7) == "vii°7/V")
    }

    @Test func chordScaleSuggestionsAreIdiomatic() {
        let cm = ChordScales.suggestions(for: Chord(root: .c, quality: .minor))
        let cmTypes = cm.map(\.type)
        #expect(cm.allSatisfy { $0.root == .c })
        #expect(cmTypes.contains(.naturalMinor))
        #expect(cmTypes.contains(.harmonicMinor))
        #expect(cmTypes.contains(.melodicMinor))
        #expect(cmTypes.contains(.dorian))
        #expect(cmTypes.contains(.minorPentatonic))

        let g7 = ChordScales.suggestions(for: Chord(root: .g, quality: .dominant7))
        #expect(g7.first == Scale(root: .g, type: .mixolydian))
        #expect(g7.map(\.type).contains(.lydianDominant))

        let dim = ChordScales.suggestions(for: Chord(root: .gSharp, quality: .diminished7))
        #expect(dim == [Scale(root: .gSharp, type: .wholeHalfDiminished)])
        // The whole-half scale actually contains its chord.
        let chord = Chord(root: .gSharp, quality: .diminished7)
        #expect(chord.pitchClasses.allSatisfy { dim[0].contains($0) })
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
