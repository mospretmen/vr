import Foundation
import MusicTheory

/// Best-effort sync of the local practice log to the backend. Anonymous
/// device identity (stable UUID) until accounts land; the server upserts by
/// session id, so re-posting the whole recent window is safe and simple.
struct PracticeSyncClient: Sendable {
    var baseURL: URL

    private static let deviceIDKey = "fretspace.deviceID.v1"

    init(baseURL: URL = URL(string: "http://localhost:3000")!) {
        self.baseURL = baseURL
    }

    /// Stable anonymous identity for this install.
    static var deviceID: UUID {
        if let stored = UserDefaults.standard.string(forKey: deviceIDKey),
           let id = UUID(uuidString: stored) {
            return id
        }
        let fresh = UUID()
        UserDefaults.standard.set(fresh.uuidString, forKey: deviceIDKey)
        return fresh
    }

    /// Pushes sessions; returns true on success. Failures are logged and
    /// swallowed — practice data stays local and re-syncs next time.
    @discardableResult
    func push(_ sessions: [PracticeSession]) async -> Bool {
        guard !sessions.isEmpty else { return true }

        struct WireSession: Encodable {
            let id: String
            let startedAt: String
            let durationS: Double
            let mode: String
        }
        struct Body: Encodable { let sessions: [WireSession] }

        let formatter = ISO8601DateFormatter()
        let body = Body(sessions: sessions.suffix(500).map {
            WireSession(id: $0.id.uuidString.lowercased(),
                        startedAt: formatter.string(from: $0.startedAt),
                        durationS: $0.duration,
                        mode: $0.mode.rawValue)
        })

        var request = URLRequest(url: baseURL.appending(path: "/v1/practice-sessions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.deviceID.uuidString.lowercased(),
                         forHTTPHeaderField: "x-device-id")
        request.timeoutInterval = 10

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                AppLog.network.error("Practice sync rejected: \(status)")
                return false
            }
            AppLog.network.info("Synced \(body.sessions.count) practice session(s)")
            return true
        } catch {
            AppLog.network.info("Practice sync deferred (offline?): \(error)")
            return false
        }
    }
}
