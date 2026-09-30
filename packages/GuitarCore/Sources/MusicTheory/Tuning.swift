/// The open-string notes of a stringed instrument, ordered from lowest-pitched
/// string to highest (string index 0 = low E on a standard guitar).
public struct Tuning: Codable, Sendable, Hashable {
    public let name: String
    public let openStrings: [Note]

    public init(name: String, openStrings: [Note]) {
        self.name = name
        self.openStrings = openStrings
    }

    public var stringCount: Int { openStrings.count }

    public static let standard = Tuning(name: "Standard", openStrings: [
        Note(.e, octave: 2), Note(.a, octave: 2), Note(.d, octave: 3),
        Note(.g, octave: 3), Note(.b, octave: 3), Note(.e, octave: 4),
    ])

    public static let dropD = Tuning(name: "Drop D", openStrings: [
        Note(.d, octave: 2), Note(.a, octave: 2), Note(.d, octave: 3),
        Note(.g, octave: 3), Note(.b, octave: 3), Note(.e, octave: 4),
    ])

    public static let eFlat = Tuning(name: "E♭ Standard", openStrings: [
        Note(.dSharp, octave: 2), Note(.gSharp, octave: 2), Note(.cSharp, octave: 3),
        Note(.fSharp, octave: 3), Note(.aSharp, octave: 3), Note(.dSharp, octave: 4),
    ])

    public static let openG = Tuning(name: "Open G", openStrings: [
        Note(.d, octave: 2), Note(.g, octave: 2), Note(.d, octave: 3),
        Note(.g, octave: 3), Note(.b, octave: 3), Note(.d, octave: 4),
    ])

    public static let all: [Tuning] = [.standard, .dropD, .eFlat, .openG]
}
