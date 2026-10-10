import Foundation

/// The harmony compass: twelve tonal COLUMNS arranged in fifths around a
/// wheel. Each column is a vertical family, read top to bottom:
///
///   outer ring   —  the major key and its relative minor, side by side
///   middle ring  —  the dominant that binds that pair (V7 of the minor,
///                   reached from the major as its secondary dominant):
///                   C · Am  over  E7
///   inner ring   —  that dominant's 7♭9 diminished (its leading-tone
///                   dim7):  E7  over  G♯°7
///
/// Straight down = deepen tension within the family; straight up =
/// resolve. Cross-wheel arrows carry everything else (G7 arriving at C
/// from another column, dominants resolving to their major a quarter-turn
/// away, and the diminished family arcs every three columns — the same
/// four pitches respelled, which is the minor-third modulation highway).
public enum HarmonyWheel {
    /// Column keys in circle-of-fifths order, clockwise = sharpward.
    public static let spokes: [PitchClass] = [
        .c, .g, .d, .a, .e, .b, .fSharp, .cSharp, .gSharp, .dSharp, .aSharp, .f,
    ]

    // MARK: - Nodes

    public enum Ring: String, Codable, Sendable, Hashable {
        case majorKey, relativeMinor, dominant, diminished
    }

    public struct Node: Codable, Sendable, Hashable, Identifiable {
        public let ring: Ring
        /// Column index 0..11 for every ring.
        public let index: Int
        public let chord: Chord

        public var id: String { "\(ring.rawValue)-\(index)" }
        public var label: String { chord.symbol }
    }

    /// Chord roots per column: key, key−3 (relative minor), key+4 (the
    /// pair's dominant: V7 of the minor), key+8 (that dominant's dim7).
    public static let nodes: [Node] = {
        var all: [Node] = []
        for (index, key) in spokes.enumerated() {
            all.append(Node(ring: .majorKey, index: index,
                            chord: Chord(root: key, quality: .major)))
            all.append(Node(ring: .relativeMinor, index: index,
                            chord: Chord(root: key.transposed(by: -3), quality: .minor)))
            all.append(Node(ring: .dominant, index: index,
                            chord: Chord(root: key.transposed(by: 4), quality: .dominant7)))
            all.append(Node(ring: .diminished, index: index,
                            chord: Chord(root: key.transposed(by: 8), quality: .diminished7)))
        }
        return all
    }()

    public static func node(_ ring: Ring, _ index: Int) -> Node {
        nodes.first { $0.ring == ring && $0.index == index }!
    }

    /// Enharmonic family (0..2) of a diminished chip — chips three columns
    /// apart share all four pitches, just respelled.
    public static func family(ofDiminishedAt index: Int) -> Int {
        node(.diminished, index).chord.root.rawValue % 3
    }

    // MARK: - Moves

    public enum MoveKind: String, Codable, Sendable, Hashable {
        case resolve            // V7 → i / I / vi · dim7 → its resolutions
        case toDominant         // a key (major or minor) → a V7 that serves it
        case fifthSharpward     // along the outer rim, clockwise
        case fifthFlatward      // along the outer rim, counterclockwise
        case relative           // major ↔ relative minor (same column, adjacent)
        case deepen             // dominant → its own 7♭9 diminished (straight down)
        case dimFamily          // dim ↔ dim three columns away (same four notes)
    }

    public struct Move: Codable, Sendable, Hashable {
        public let kind: MoveKind
        public let from: Node
        public let to: Node
    }

    /// The complete lattice — every move from every node, for always-on
    /// pathway rendering.
    public static let allMoves: [Move] = nodes.flatMap { moves(from: $0) }

    /// Every legal departure from a node.
    public static func moves(from node: Node) -> [Move] {
        var moves: [Move] = []
        func add(_ kind: MoveKind, _ ring: Ring, _ index: Int) {
            moves.append(Move(kind: kind, from: node,
                              to: Self.node(ring, ((index % 12) + 12) % 12)))
        }
        let i = node.index

        switch node.ring {
        case .majorKey:
            add(.relative, .relativeMinor, i)          // C → Am (adjacent)
            add(.toDominant, .dominant, i)             // C → E7 (straight down)
            add(.toDominant, .dominant, i + 9)         // C → G7 (its own V7)
            add(.fifthSharpward, .majorKey, i + 1)
            add(.fifthFlatward, .majorKey, i + 11)

        case .relativeMinor:
            add(.relative, .majorKey, i)               // Am → C
            add(.toDominant, .dominant, i)             // Am → E7 (straight down)
            add(.fifthSharpward, .relativeMinor, i + 1)
            add(.fifthFlatward, .relativeMinor, i + 11)

        case .dominant:
            add(.resolve, .relativeMinor, i)           // E7 → Am (straight up)
            add(.resolve, .majorKey, i + 3)            // E7 → A (cross-wheel)
            add(.resolve, .relativeMinor, i + 3)       // E7 → F♯m (deceptive)
            add(.deepen, .diminished, i)               // E7 → G♯°7 (straight down)

        case .diminished:
            add(.resolve, .relativeMinor, i)           // G♯°7 → Am (straight up)
            add(.resolve, .majorKey, i + 3)            // G♯°7 → A (cross-wheel)
            add(.resolve, .dominant, i)                // back up into E7 (7♭9)
            add(.dimFamily, .diminished, i + 3)        // same notes, respelled
            add(.dimFamily, .diminished, i + 9)
        }
        return moves
    }
}
