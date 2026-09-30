import Foundation
import MusicTheory

/// Thin async client for the Fretspace backend track API. All response
/// shapes are the shared Codable models in MusicTheory; the wire contract
/// is pinned by WireFormatTests in GuitarCore.
struct TrackLibraryClient: Sendable {
    var baseURL: URL

    init(baseURL: URL = URL(string: "http://localhost:3000")!) {
        self.baseURL = baseURL
    }

    enum ClientError: Error {
        case badStatus(Int)
        case trackNotFound(String)
    }

    func tracks() async throws -> [TrackSummary] {
        try await get([TrackSummary].self, path: "/v1/tracks")
    }

    func timeline(trackID: String) async throws -> ChordTimeline {
        do {
            return try await get(ChordTimeline.self, path: "/v1/tracks/\(trackID)/timeline")
        } catch ClientError.badStatus(404) {
            throw ClientError.trackNotFound(trackID)
        }
    }

    private func get<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        let url = baseURL.appending(path: path)
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ClientError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
