/// A location on the fretboard. `string` 0 is the lowest-pitched string;
/// `fret` 0 is the open string.
public struct FretPosition: Codable, Sendable, Hashable {
    public var string: Int
    public var fret: Int

    public init(string: Int, fret: Int) {
        self.string = string
        self.fret = fret
    }
}

/// Why a position is highlighted, and its role — drives color/size in the overlay.
public enum HighlightRole: Codable, Sendable, Hashable {
    case scaleDegree(Int)     // 1-based degree within the active scale
    case chordTone(ChordTone) // role within the active chord
    case exerciseStep(isCurrent: Bool) // target in a drill; current pops, upcoming dims
}

/// A single highlighted position, ready for the render layer.
public struct FretboardHighlight: Codable, Sendable, Hashable {
    public let position: FretPosition
    public let note: Note
    public let role: HighlightRole

    public init(position: FretPosition, note: Note, role: HighlightRole) {
        self.position = position
        self.note = note
        self.role = role
    }
}

/// Maps musical content onto string/fret positions for a given tuning.
/// Pure logic — geometry (where positions sit in 3D space) lives in FretboardKit.
public struct FretboardModel: Codable, Sendable, Hashable {
    public var tuning: Tuning
    public var fretCount: Int

    public init(tuning: Tuning = .standard, fretCount: Int = 22) {
        self.tuning = tuning
        self.fretCount = fretCount
    }

    /// The sounding note at a position.
    public func note(at position: FretPosition) -> Note {
        precondition(position.string >= 0 && position.string < tuning.stringCount, "String out of range")
        precondition(position.fret >= 0 && position.fret <= fretCount, "Fret out of range")
        return tuning.openStrings[position.string].transposed(by: position.fret)
    }

    /// Every position across the neck sounding the given pitch class.
    public func positions(of pitchClass: PitchClass) -> [FretPosition] {
        allPositions.filter { note(at: $0).pitchClass == pitchClass }
    }

    /// All highlights for a scale, tagged with scale degrees.
    public func highlights(for scale: Scale) -> [FretboardHighlight] {
        allPositions.compactMap { position in
            let note = note(at: position)
            guard let degree = scale.degree(of: note.pitchClass) else { return nil }
            return FretboardHighlight(position: position, note: note, role: .scaleDegree(degree))
        }
    }

    /// All highlights for a chord, tagged with chord-tone roles.
    public func highlights(for chord: Chord) -> [FretboardHighlight] {
        allPositions.compactMap { position in
            let note = note(at: position)
            guard let tone = chord.tone(of: note.pitchClass) else { return nil }
            return FretboardHighlight(position: position, note: note, role: .chordTone(tone))
        }
    }

    /// Chord highlights restricted to positions also inside a scale — the
    /// "chord over backing track" view: scale as context, chord tones emphasized.
    public func highlights(for chord: Chord, within scale: Scale) -> [FretboardHighlight] {
        allPositions.compactMap { position in
            let note = note(at: position)
            if let tone = chord.tone(of: note.pitchClass) {
                return FretboardHighlight(position: position, note: note, role: .chordTone(tone))
            }
            if let degree = scale.degree(of: note.pitchClass) {
                return FretboardHighlight(position: position, note: note, role: .scaleDegree(degree))
            }
            return nil
        }
    }

    public var allPositions: [FretPosition] {
        (0..<tuning.stringCount).flatMap { string in
            (0...fretCount).map { fret in FretPosition(string: string, fret: fret) }
        }
    }
}
