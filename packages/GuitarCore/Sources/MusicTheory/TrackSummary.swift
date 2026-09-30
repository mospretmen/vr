/// A backing track as listed by the API (`GET /v1/tracks`). The chord
/// timeline is fetched separately per track.
public struct TrackSummary: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let artist: String?
    public let bpm: Double
    /// Harmonic context of the track; drives the scale layer of the overlay.
    public let key: Scale?

    public init(id: String, title: String, artist: String?, bpm: Double, key: Scale?) {
        self.id = id
        self.title = title
        self.artist = artist
        self.bpm = bpm
        self.key = key
    }
}
