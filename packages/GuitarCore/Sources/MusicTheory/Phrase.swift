import Foundation

/// A stored musical phrase — the user's own vocabulary, or a line in the
/// style of the masters: a note sequence on the fretboard, the chord it
/// lives over, and a one-line reason it works.
public struct Phrase: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    /// The chord context the phrase speaks over, if any.
    public var chord: Chord?
    public var steps: [ExerciseStep]
    /// "Targets the 3rd on the downbeat", "ii–V descent" — the why.
    public var remark: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, chord: Chord? = nil,
                steps: [ExerciseStep], remark: String = "",
                createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.chord = chord
        self.steps = steps
        self.remark = remark
        self.createdAt = createdAt
    }
}
