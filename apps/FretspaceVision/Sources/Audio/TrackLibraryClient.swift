import Foundation
import MusicTheory

/// Thin async client for the Fretspace backend track API. All response
/// shapes are the shared Codable models in MusicTheory; the wire contract
/// is pinned by WireFormatTests in GuitarCore.
///
/// Resilience: 10s request timeout, one automatic retry with backoff on
/// transient transport failures. Errors are logged here and mapped to
/// `UserFacingError` at the call site.
struct TrackLibraryClient: Sendable {
    var baseURL: URL

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    init(baseURL: URL = URL(string: "http://localhost:3000")!) {
        self.baseURL = baseURL
    }

    enum ClientError: Error {
        case badStatus(Int)
        case trackNotFound(String)
        case unreachable(underlying: Error)
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
        var lastTransportError: Error?

        for attempt in 0..<2 {
            if attempt > 0 {
                try? await Task.sleep(for: .milliseconds(400))
                AppLog.network.info("Retrying \(path, privacy: .public)")
            }
            do {
                let (data, response) = try await Self.session.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    // Server answered; retrying won't change its mind.
                    AppLog.network.error(
                        "GET \(path, privacy: .public) → \(http.statusCode)")
                    throw ClientError.badStatus(http.statusCode)
                }
                return try JSONDecoder().decode(T.self, from: data)
            } catch let error as URLError {
                lastTransportError = error
                AppLog.network.error(
                    "GET \(path, privacy: .public) transport failure: \(error.code.rawValue)")
            }
        }
        throw ClientError.unreachable(underlying: lastTransportError ?? URLError(.unknown))
    }
}
