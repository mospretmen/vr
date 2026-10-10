import Foundation

/// The harmony compass: a three-ring navigable map of functional harmony.
///
///  - Outer ring: the 12 keys in fifths order, each spoke carrying the
///    major key and its relative minor.
///  - Middle ring: each key's dominant seventh, docked on its key's spoke.
///  - Inner ring: the three diminished-seventh hubs. Each dim7 chord is
///    enharmonically the rootless 7♭9 of four dominants, so every hub is a
///    four-way interchange between keys a minor third apart — the
///    modulation highways.
///
/// Pure graph: nodes + directed moves. Rendering decides geometry.
public enum HarmonyWheel {
    /// Spokes in circle-of-fifths order, clockwise = sharpward.
    public static let spokes: [PitchClass] = [
        .c, .g, .d, .a, .e, .b, .fSharp, .cSharp, .gSharp, .dSharp, .aSharp, .f,
    ]

    // MARK: - Nodes

    public enum Ring: String, Codable, Sendable, Hashable {
        case majorKey, relativeMinor, dominant, diminished
    }

    public struct Node: Codable, Sendable, Hashable, Identifiable {
        public let ring: Ring
        /// Spoke index 0..11 for the three outer rings; hub index 0..2 for
        /// the diminished ring.
        public let index: Int
        public let chord: Chord

        public var id: String { "\(ring.rawValue)-\(index)" }

        public var label: String { chord.symbol }
    }

    /// All 39 nodes: 12 majors, 12 relative minors, 12 dominants, 3 hubs.
    public static let nodes: [Node] = {
        var all: [Node] = []
        for (index, key) in spokes.enumerated() {
            all.append(Node(ring: .majorKey, index: index,
                            chord: Chord(root: key, quality: .major)))
            all.append(Node(ring: .relativeMinor, index: index,
                            chord: Chord(root: key.transposed(by: -3), quality: .minor)))
            all.append(Node(ring: .dominant, index: index,
                            chord: Chord(root: key.transposed(by: 7), quality: .dominant7)))
        }
        for hub in 0..<3 {
            all.append(Node(ring: .diminished, index: hub,
                            chord: Chord(root: PitchClass(rawValue: hub)!,
                                         quality: .diminished7)))
        }
        return all
    }()

    public static func node(_ ring: Ring, _ index: Int) -> Node {
        nodes.first { $0.ring == ring && $0.index == index }!
    }

    /// The diminished hub (0..2) containing the given pitch class as one of
    /// its four enharmonic roots.
    public static func hub(containing pitchClass: PitchClass) -> Int {
        pitchClass.rawValue % 3
    }

    // MARK: - Moves

    public enum MoveKind: String, Codable, Sendable, Hashable {
        case resolve            // V7 → I, vi (deceptive), or i (minor home)
        case toDominant         // key → its own V7 (depart / tonicize)
        case secondaryDominant  // major → V7 of its relative minor (C → E7)
        case fifthSharpward     // key → neighbor clockwise (adds a sharp)
        case fifthFlatward      // key → neighbor counterclockwise
        case relative           // major ↔ relative minor (same spoke)
        case leadingTone        // dim7 hub → key a half-step above a hub root
        case flatNine           // dominant ↔ dim hub (7♭9 equivalence)
        case dimShift           // dim hub ↔ dim hub (chromatic planing)
    }

    public struct Move: Codable, Sendable, Hashable {
        public let kind: MoveKind
        public let from: Node
        public let to: Node
    }

    /// The complete lattice — every move from every node, for always-on
    /// pathway rendering.
    public static let allMoves: [Move] = nodes.flatMap { moves(from: $0) }

    /// Every legal departure from a node — the arrows the UI draws when the
    /// player stands on that chord.
    public static func moves(from node: Node) -> [Move] {
        var moves: [Move] = []
        func add(_ kind: MoveKind, to: Node) {
            moves.append(Move(kind: kind, from: node, to: to))
        }

        switch node.ring {
        case .majorKey:
            let i = node.index
            add(.toDominant, to: Self.node(.dominant, i))
            // V7 of the relative minor (C → E7): three spokes sharpward.
            add(.secondaryDominant, to: Self.node(.dominant, (i + 3) % 12))
            add(.fifthSharpward, to: Self.node(.majorKey, (i + 1) % 12))
            add(.fifthFlatward, to: Self.node(.majorKey, (i + 11) % 12))
            add(.relative, to: Self.node(.relativeMinor, i))

        case .relativeMinor:
            let i = node.index
            add(.relative, to: Self.node(.majorKey, i))
            // The minor key's own V7 (harmonic-minor dominant): E7 for Am.
            // That chip lives on the parallel major's spoke (E7 is A major's
            // dominant chip), so Am's escape hatch points there.
            if let parallelMajorSpoke = spokes.firstIndex(of: node.chord.root) {
                add(.toDominant, to: Self.node(.dominant, parallelMajorSpoke))
            }

        case .dominant:
            let i = node.index
            add(.resolve, to: Self.node(.majorKey, i))
            // Deceptive: resolve into the target key's relative minor (vi).
            add(.resolve, to: Self.node(.relativeMinor, i))
            // Minor home: V → i (E7 → Am). The minor with the same tonic as
            // this chip's major target lives three spokes sharpward.
            add(.resolve, to: Self.node(.relativeMinor, (i + 9) % 12))
            // 7♭9 ↔ diminished: the dim7 on this dominant's third.
            let third = node.chord.root.transposed(by: 4)
            add(.flatNine, to: Self.node(.diminished, hub(containing: third)))

        case .diminished:
            // Chromatic planing: slide to either of the other two families.
            add(.dimShift, to: Self.node(.diminished, (node.index + 1) % 3))
            add(.dimShift, to: Self.node(.diminished, (node.index + 2) % 3))
            // Each hub root is a leading tone: resolves up a half-step.
            let roots = (0..<4).map { node.chord.root.transposed(by: 3 * $0) }
            for root in roots {
                let target = root.transposed(by: 1)
                if let spoke = spokes.firstIndex(of: target) {
                    add(.leadingTone, to: Self.node(.majorKey, spoke))
                }
                // And back out through any of its four dominants.
                let dominantRoot = root.transposed(by: -4) // dim root = 3rd of dom
                if let domSpoke = spokes.firstIndex(of: dominantRoot.transposed(by: -7)) {
                    add(.flatNine, to: Self.node(.dominant, domSpoke))
                }
            }
        }
        return moves
    }
}
