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

        #expect(cmTypes.contains(.phrygian))
        #expect(g7.map(\.type).contains(.altered))
        let halfDim = ChordScales.suggestions(for: Chord(root: .b, quality: .minor7b5))
        #expect(halfDim.map(\.type) == [.locrian, .locrianNatural2])
        // The FIRST suggestion is the chord's home scale and contains every
        // chord tone (the old augmented suggestion violated this); later
        // ones are tension colors that must still contain the root.
        for quality in ChordQuality.all {
            let chord = Chord(root: .c, quality: quality)
            let suggestions = ChordScales.suggestions(for: chord)
            for pc in chord.pitchClasses {
                #expect(suggestions.first?.contains(pc) == true,
                        "home scale of \(chord.symbol) missing \(pc.name())")
            }
            for scale in suggestions {
                #expect(scale.contains(chord.root))
            }
        }

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

@Suite("Chord voicings and triads")
struct ChordVoicingTests {
    @Test func minorKeyFrameReadsFromTheMinorTonic() {
        // Stand on Cm (relative minor of E♭, column 9): the wheel reads in C minor.
        let tonic = PitchClass.c
        #expect(HarmonyWheel.romanNumeral(
            for: HarmonyWheel.node(.relativeMinor, 9), inMinorKey: tonic) == "i")
        #expect(HarmonyWheel.romanNumeral(
            for: HarmonyWheel.node(.majorKey, 9), inMinorKey: tonic) == "III")
        // G7 sits in the E♭ column (root = D♯+4 = G): the V7 of C minor.
        #expect(HarmonyWheel.romanNumeral(
            for: HarmonyWheel.node(.dominant, 9), inMinorKey: tonic) == "V7")
        // A♭ major (column 8) is VI; B°7 (column 9's dim: D♯+8 = B) is vii°7.
        #expect(HarmonyWheel.romanNumeral(
            for: HarmonyWheel.node(.majorKey, 8), inMinorKey: tonic) == "VI")
        #expect(HarmonyWheel.romanNumeral(
            for: HarmonyWheel.node(.diminished, 9), inMinorKey: tonic) == "vii°7")
        // The Neapolitan: D♭ major against C minor.
        #expect(HarmonyWheel.romanNumeral(
            for: HarmonyWheel.node(.majorKey, 7), inMinorKey: tonic) == "♭II")
    }

    @Test func alterationsAreCoveredByTheirScales() {
        let qualities: [ChordQuality] = [.major, .major7, .minor, .minor7,
                                         .dominant7, .minor7b5, .diminished7,
                                         .augmented, .sus4]
        for quality in qualities {
            let base = Chord(root: .c, quality: quality)
            let options = ChordAlterations.options(for: base)
            #expect(!options.isEmpty)
            for alteration in options {
                let scale = Scale(root: base.root, type: alteration.scale)
                for pc in alteration.chord.pitchClasses {
                    #expect(scale.contains(pc),
                            "\(alteration.label): \(scale.name) missing \(pc.name())")
                }
                #expect(alteration.chord.root == base.root)
                // The chord's defining 3rd survives — unless the alteration
                // suspends it by name.
                if !alteration.label.contains("sus") {
                    #expect(alteration.chord.pitchClasses.contains(
                        base.pitchClasses[1]), "\(alteration.label)")
                }
            }
        }
        // Thorough menus: 19 dominant tensions; the basics are all present.
        let g7 = ChordAlterations.options(for: Chord(root: .g, quality: .dominant7))
        #expect(g7.count == 19)
        let cMajor = ChordAlterations.options(for: Chord(root: .c, quality: .major))
        #expect(cMajor.contains { $0.label == "Cmaj9" })
        #expect(cMajor.contains { $0.label == "Cmaj7♯5" })
        let dim = ChordAlterations.options(for: Chord(root: .gSharp, quality: .diminished7))
        #expect(dim.count == 1)
    }

    @Test func inversionGripsPutTheChosenToneInTheBass() {
        let c = Chord(root: .c, quality: .major)
        let board = FretboardModel()
        let overE = ChordVoicings.voicings(for: c, bass: .third)
        #expect(!overE.isEmpty)
        #expect(overE.contains(Voicing(frets: [0, 3, 2, 0, 1, 0])),
                "six-string C/E with the open low E in the bass")
        for voicing in overE {
            #expect(board.note(at: voicing.positions[0]).pitchClass == .e)
        }
        let overG = ChordVoicings.voicings(for: c, bass: .fifth)
        for voicing in overG {
            #expect(board.note(at: voicing.positions[0]).pitchClass == .g)
        }
    }

    @Test func chordDegreeLabelsSpellTrueQualities() {
        let dim7 = Chord(root: .c, quality: .diminished7)
        #expect(dim7.degreeLabel(of: .c) == "R")
        #expect(dim7.degreeLabel(of: .dSharp) == "♭3")
        #expect(dim7.degreeLabel(of: .fSharp) == "♭5")
        #expect(dim7.degreeLabel(of: .a) == "♭♭7")
        let g7 = Chord(root: .g, quality: .dominant7)
        #expect(g7.degreeLabel(of: .b) == "3")
        #expect(g7.degreeLabel(of: .f) == "♭7")
        // Extended chords match their tensions by pitch class (mod 12).
        let maj9 = Chord(root: .c, quality: ChordQuality(
            name: "maj9", symbol: "maj9", intervals: [0, 4, 7, 11, 14]))
        #expect(maj9.tone(of: .d) == .extended)
        #expect(maj9.degreeLabel(of: .d) == "9")
        let m6 = Chord(root: .c, quality: ChordQuality(
            name: "m6", symbol: "m6", intervals: [0, 3, 7, 9]))
        #expect(m6.degreeLabel(of: .a) == "6")
        let alt = Chord(root: .c, quality: ChordQuality(
            name: "7alt", symbol: "7alt", intervals: [0, 4, 10, 13, 15, 20]))
        #expect(alt.degreeLabel(of: .cSharp) == "♭9")
        #expect(alt.degreeLabel(of: .dSharp) == "♯9")
        #expect(alt.degreeLabel(of: .gSharp) == "♭13")
    }

    @Test func alteredChordsGetPlayableGrips() {
        let board = FretboardModel()
        for base in [Chord(root: .c, quality: .major),
                     Chord(root: .c, quality: .minor),
                     Chord(root: .g, quality: .dominant7)] {
            for alteration in ChordAlterations.options(for: base) {
                let grips = ChordVoicings.voicings(for: alteration.chord)
                #expect(!grips.isEmpty, "no grips for \(alteration.label)")
                let intervals = alteration.chord.quality.intervals
                let top = alteration.chord.root.transposed(by: intervals.last!)
                let third = alteration.chord.root.transposed(
                    by: alteration.chord.quality.intervals[1])
                for grip in grips {
                    let pcs = Set(grip.positions.map { board.note(at: $0).pitchClass })
                    #expect(pcs.contains(alteration.chord.root))
                    #expect(pcs.contains(top),
                            "\(alteration.label) grip missing its named color")
                    // The defining 3rd (or sus tone) is never dropped.
                    #expect(pcs.contains(third),
                            "\(alteration.label) grip missing its 3rd")
                }
            }
        }
    }

    @Test func shellVoicingsAreRootAndGuideTones() {
        let c7 = Chord(root: .c, quality: .dominant7)
        let shells = ChordVoicings.shells(for: c7)
        #expect(!shells.isEmpty)
        // The classic low-E shell: C at 8, B♭ on the D string, E on the G.
        #expect(shells.contains(Voicing(frets: [8, nil, 8, 9, nil, nil])))
        let board = FretboardModel()
        for shell in shells {
            let pcs = shell.positions.map { board.note(at: $0).pitchClass }
            #expect(Set(pcs) == [.c, .e, .aSharp], "root + guide tones only")
            #expect(pcs.first == .c, "root in the bass")
            #expect(shell.positions.count == 3)
        }
        // Triads have no shells.
        #expect(ChordVoicings.shells(for: Chord(root: .c, quality: .major)).isEmpty)
    }

    @Test func keysReachTheirSubstituteDominantDirectly() {
        // In the key of C, the tritone sub of G7 is D♭7 — visible from C itself.
        let c = HarmonyWheel.node(.majorKey, 0)
        let cSubs = HarmonyWheel.moves(from: c).filter { $0.kind == .tritoneSub }
        #expect(cSubs.map(\.to.chord) == [Chord(root: .cSharp, quality: .dominant7)])
        // And it is two-way: C departs onto the sub, and the sub carries a
        // resolution arrow back home (D♭7 → C, half-step down) — same
        // pattern as C ⇄ G7.
        #expect(cSubs.first.map { HarmonyWheel.isTwoWay($0) } == true)
        let dFlat7 = cSubs[0].to
        let home = HarmonyWheel.moves(from: dFlat7)
            .filter { $0.kind == .tritoneSub && $0.to.ring == .majorKey }
        #expect(home.map(\.to.id) == [c.id])
        // Am's V7 is E7, so Am reaches B♭7.
        let am = HarmonyWheel.node(.relativeMinor, 0)
        let amSubs = HarmonyWheel.moves(from: am).filter { $0.kind == .tritoneSub }
        #expect(amSubs.map(\.to.chord) == [Chord(root: .aSharp, quality: .dominant7)])
    }

    @Test func dominantsChainAroundTheCircle() {
        // E7 → A7 → D7 → … : resolve down a fifth, stay dominant.
        let e7 = HarmonyWheel.node(.dominant, 0)
        let down = HarmonyWheel.moves(from: e7)
            .filter { $0.kind == .fifthFlatward && $0.to.ring == .dominant }
        #expect(down.map(\.to.chord) == [Chord(root: .a, quality: .dominant7)])
        let up = HarmonyWheel.moves(from: e7)
            .filter { $0.kind == .fifthSharpward && $0.to.ring == .dominant }
        #expect(up.map(\.to.chord) == [Chord(root: .b, quality: .dominant7)])
        #expect(down.first.map { HarmonyWheel.isTwoWay($0) } == true)
    }

    @Test func tritoneSubstitutionsRunStraightAcross() {
        let e7 = HarmonyWheel.node(.dominant, 0) // E7 in the C column
        let subs = HarmonyWheel.moves(from: e7)
            .filter { $0.kind == .tritoneSub && $0.to.ring == .dominant }
        #expect(subs.count == 1)
        #expect(subs.first?.to.chord == Chord(root: .aSharp, quality: .dominant7),
                "E7's tritone sub is B♭7")
        #expect(subs.first.map { HarmonyWheel.isTwoWay($0) } == true)
        // The sub's root sits a half-step above the original's resolution
        // target: E7 → A, and B♭7 slides down into that same A.
        let e7Target = HarmonyWheel.moves(from: e7)
            .first { $0.kind == .resolve && $0.to.ring == .majorKey }!.to
        #expect(subs[0].to.chord.root == e7Target.chord.root.transposed(by: 1))
    }

    @Test func openGripsMatchTheClassics() {
        let c = ChordVoicings.voicings(for: Chord(root: .c, quality: .major))
        #expect(c.contains(Voicing(frets: [nil, 3, 2, 0, 1, 0])), "open C grip")
        let e = ChordVoicings.voicings(for: Chord(root: .e, quality: .major))
        #expect(e.contains(Voicing(frets: [0, 2, 2, 1, 0, 0])), "open E grip")
        let am = ChordVoicings.voicings(for: Chord(root: .a, quality: .minor))
        #expect(am.contains(Voicing(frets: [nil, 0, 2, 2, 1, 0])), "open Am grip")
    }

    @Test func everyVoicingIsPlayableAndCorrect() {
        let board = FretboardModel()
        for node in HarmonyWheel.nodes {
            for voicing in ChordVoicings.voicings(for: node.chord) {
                let sounded = voicing.positions
                #expect(sounded.count >= 4)
                #expect(board.note(at: sounded[0]).pitchClass == node.chord.root,
                        "root in the bass for \(node.chord.symbol)")
                let fretted = sounded.map(\.fret).filter { $0 > 0 }
                if let lo = fretted.min(), let hi = fretted.max() {
                    #expect(hi - lo <= 3, "span for \(node.chord.symbol)")
                }
                for position in sounded {
                    #expect(node.chord.contains(board.note(at: position).pitchClass))
                }
            }
            #expect(!ChordVoicings.voicings(for: node.chord).isEmpty,
                    "no voicings for \(node.chord.symbol)")
        }
    }

}
