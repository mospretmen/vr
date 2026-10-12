import Foundation
import MusicTheory

/// On-device phrase library: a JSON file in Application Support. Neon sync
/// can layer on later without touching callers.
@MainActor
@Observable
final class PhraseStore {
    private(set) var phrases: [Phrase] = []

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("Fretspace", isDirectory: true)
        try? FileManager.default.createDirectory(at: base,
                                                 withIntermediateDirectories: true)
        return base.appendingPathComponent("phrases.json")
    }

    init() {
        load()
    }

    func add(_ phrase: Phrase) {
        phrases.insert(phrase, at: 0)
        save()
    }

    func delete(_ phrase: Phrase) {
        phrases.removeAll { $0.id == phrase.id }
        save()
    }

    private func load() {
        do {
            let data = try Data(contentsOf: Self.fileURL)
            phrases = try JSONDecoder().decode([Phrase].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
        } catch CocoaError.fileReadNoSuchFile {
            phrases = []
        } catch {
            AppLog.state.error("Phrase library failed to load: \(error)")
            phrases = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(phrases)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            AppLog.state.error("Phrase library failed to save: \(error)")
        }
    }
}
