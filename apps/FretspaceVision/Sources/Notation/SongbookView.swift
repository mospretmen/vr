import PDFKit
import SwiftUI

/// The songbook, in the headset: one search over the whole fake-book
/// index (bundled), favorites, and — when a remote library URL is
/// configured — the chart itself at the exact page via PDFKit.
struct SongEntry: Decodable, Identifiable, Hashable {
    let title: String
    let book: String
    let page: Int
    var id: String { "\(book)|\(title)|\(page)" }
}

enum SongbookCatalog {
    struct Book {
        let name: String
        let file: String
        let offset: Int
        /// Public-domain scores served by the site directly — no key needed.
        var url: String?
    }

    /// Book metadata + measured front-matter offsets (parity with the web).
    static let books: [String: Book] = [
        "realbk1": Book(name: "The Real Book I", file: "REALBK1.PDF", offset: 13),
        "realbk2": Book(name: "The Real Book II", file: "REALBK2.PDF", offset: 7),
        "realbk3": Book(name: "The Real Book III", file: "REALBK3.PDF", offset: 5),
        // The New Real Books are indexed in INDEXES.PDF but the PDFs aren't
        // in the library — re-add here once uploaded to the remote store.
        "jazzfake": Book(name: "The Jazz Fakebook", file: "JAZZFAKE-1.PDF", offset: -1),
        "colorado": Book(name: "The Colorado Cookbook", file: "COLOBK.PDF", offset: 3),
        "jazzltd": Book(name: "Jazz LTD", file: "JAZZLTD.PDF", offset: 7),
        "library": Book(name: "Library of Musicians' Jazz", file: "LIBRARY.PDF", offset: 4),
        "evansbk": Book(name: "The Bill Evans Fakebook", file: "EVANSBK.PDF", offset: 3),
        "thebook": Book(name: "The Book (commercial)", file: "THEBOOK.PDF", offset: 13),
        "monk": Book(name: "Thelonious Monk Compositions", file: "Thelonious_Monk_Compositions.pdf", offset: 0),
        "baden": Book(name: "Baden Powell Songbook vol. I", file: "Baden Pawel Vol. 1.pdf", offset: 0),
        "bach1007": Book(name: "Bach — Cello Suite No. 1, BWV 1007", file: "bwv1007-cello-suite-1.pdf", offset: 0,
                         url: "https://vr-music-app.netlify.app/scores/bwv1007-cello-suite-1.pdf"),
        "bach999": Book(name: "Bach — Prelude in C minor, BWV 999", file: "bwv999-prelude-c-minor.pdf", offset: 0,
                        url: "https://vr-music-app.netlify.app/scores/bwv999-prelude-c-minor.pdf"),
        "bach1000": Book(name: "Bach — Fugue in G minor, BWV 1000", file: "bwv1000-fugue-g-minor.pdf", offset: 0,
                         url: "https://vr-music-app.netlify.app/scores/bwv1000-fugue-g-minor.pdf"),
        "bwv1002": Book(name: "Bach — Partita No. 1, BWV 1002", file: "bwv1002-violin-partita-1.pdf", offset: 0,
                        url: "https://vr-music-app.netlify.app/scores/bwv1002-violin-partita-1.pdf"),
        "bach996": Book(name: "Bach — Lute Suite in E minor, BWV 996", file: "bwv996-lute-suite-e-minor.pdf", offset: 0,
                        url: "https://vr-music-app.netlify.app/scores/bwv996-lute-suite-e-minor.pdf"),
        "bach1001": Book(name: "Bach — Violin Sonata No. 1, BWV 1001", file: "bwv1001-violin-sonata-1.pdf", offset: 0,
                         url: "https://vr-music-app.netlify.app/scores/bwv1001-violin-sonata-1.pdf"),
        "bach1004": Book(name: "Bach — Partita No. 2 (Chaconne), BWV 1004", file: "bwv1004-violin-partita-2.pdf", offset: 0,
                         url: "https://vr-music-app.netlify.app/scores/bwv1004-violin-partita-2.pdf"),
        "bach1006": Book(name: "Bach — Violin Partita No. 3, BWV 1006", file: "bwv1006-violin-partita-3.pdf", offset: 0,
                         url: "https://vr-music-app.netlify.app/scores/bwv1006-violin-partita-3.pdf"),
    ]

    static let all: [SongEntry] = {
        guard let url = Bundle.main.url(forResource: "songIndex", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([SongEntry].self, from: data)
        else {
            AppLog.state.error("Song index failed to load from bundle")
            return []
        }
        // Only tunes whose book we can actually serve.
        return entries.filter { books[$0.book] != nil }
    }()

    static func search(_ query: String, limit: Int = 60) -> [SongEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        var starts: [SongEntry] = []
        var within: [SongEntry] = []
        for entry in all {
            let t = entry.title.lowercased()
            if t.hasPrefix(q) {
                starts.append(entry)
                if starts.count >= limit { break }
            } else if t.contains(q) {
                within.append(entry)
            }
        }
        return Array((starts + within).prefix(limit))
    }
}

struct SongbookView: View {
    @State private var query = ""
    @State private var favorites: Set<String> =
        Set(UserDefaults.standard.stringArray(forKey: "songbook.favorites") ?? [])
    @State private var remoteURL: String =
        UserDefaults.standard.string(forKey: "songbook.remoteURL") ?? ""
    @State private var remoteKey: String =
        UserDefaults.standard.string(forKey: "songbook.remoteKey") ?? ""
    @State private var viewing: SongEntry?
    @State private var showSettings = false

    private var rows: [SongEntry] {
        if query.trimmingCharacters(in: .whitespaces).count >= 2 {
            return SongbookCatalog.search(query)
        }
        return SongbookCatalog.all.filter { favorites.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            searchField
            resultsList
        }
        .padding(20)
        .sheet(item: $viewing) { entry in
            SongSheetView(entry: entry, remoteURL: remoteURL)
        }
        .sheet(isPresented: $showSettings) { settingsSheet }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Songbook").font(.title2.bold())
                Text("\(SongbookCatalog.all.count) tunes — search, tap, play.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
        }
    }

    private var searchField: some View {
        TextField("Search a tune — “All The Things”, “Desafinado”…", text: $query)
            .textFieldStyle(.roundedBorder)
            .font(.body)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if rows.isEmpty {
                    Text(query.count >= 2
                         ? "Nothing in the index for “\(query)”."
                         : "Search the shelf, or star tunes to pin them here.")
                        .font(.callout).foregroundStyle(.secondary)
                        .padding(.top, 20)
                }
                ForEach(rows) { entry in
                    songRow(entry)
                }
            }
        }
    }

    private func songRow(_ entry: SongEntry) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleFavorite(entry)
            } label: {
                Image(systemName: favorites.contains(entry.id) ? "star.fill" : "star")
                    .foregroundStyle(favorites.contains(entry.id) ? .orange : .secondary)
            }
            .buttonStyle(.borderless)
            Button {
                viewing = entry
            } label: {
                HStack {
                    Text(entry.title).fontWeight(.medium).lineLimit(1)
                    Spacer()
                    Text("\(SongbookCatalog.books[entry.book]?.name ?? entry.book) · p.\(entry.page)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
    }

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Remote library").font(.title3.bold())
            Text("A private URL that serves your book PDFs by file name. With it set, tunes open right here at the exact page.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("https://your-site/book?f=", text: $remoteURL)
                .textFieldStyle(.roundedBorder)
                .onChange(of: remoteURL) { _, value in
                    UserDefaults.standard.set(value, forKey: "songbook.remoteURL")
                }
            TextField("Access key (optional)", text: $remoteKey)
                .textFieldStyle(.roundedBorder)
                .onChange(of: remoteKey) { _, value in
                    UserDefaults.standard.set(value, forKey: "songbook.remoteKey")
                }
            Button("Done") { showSettings = false }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 520)
    }

    private func toggleFavorite(_ entry: SongEntry) {
        if favorites.contains(entry.id) {
            favorites.remove(entry.id)
        } else {
            favorites.insert(entry.id)
        }
        UserDefaults.standard.set(Array(favorites), forKey: "songbook.favorites")
    }
}

/// One tune: the chart via the remote library when configured, otherwise
/// a clear pointer to the book and page.
struct SongSheetView: View {
    let entry: SongEntry
    let remoteURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    @State private var failed = false

    private var book: SongbookCatalog.Book? { SongbookCatalog.books[entry.book] }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(.title3.bold())
                    Text("\(book?.name ?? entry.book) · p.\(entry.page)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }
            content
        }
        .padding(18)
        .frame(minWidth: 700, minHeight: 760)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let document {
            SongPDFView(document: document,
                        page: max(1, entry.page + (book?.offset ?? 0)))
        } else if failed || (remoteURL.isEmpty && book?.url == nil) {
            VStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.system(size: 44)).foregroundStyle(.secondary)
                Text("Open **\(book?.name ?? entry.book)** to page **\(entry.page)**.")
                Text(remoteURL.isEmpty
                     ? "Set a remote library in ⚙ to read charts right here."
                     : "The remote library didn't serve this book.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView("Fetching the book…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func load() async {
        guard let book else { return }
        // Site-served public-domain scores need no remote library or key.
        if let direct = book.url {
            await fetch(direct, withKey: false)
            return
        }
        guard !remoteURL.isEmpty else { return }
        // Supports plain hosts (…/dir/<file>) and function endpoints
        // (…/book?f=<file>) — same convention as the web app.
        let base = remoteURL.trimmingCharacters(in: .whitespaces)
        guard let encoded = book.file.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) else {
            failed = true
            return
        }
        let target: String
        if base.contains("{f}") {
            target = base.replacingOccurrences(of: "{f}", with: encoded)
        } else if base.contains("?") {
            target = base.hasSuffix("=") || base.hasSuffix("?")
                ? base + encoded : base + "&f=" + encoded
        } else {
            target = (base.hasSuffix("/") ? String(base.dropLast()) : base) + "/" + encoded
        }
        await fetch(target, withKey: true)
    }

    private func fetch(_ target: String, withKey: Bool) async {
        guard let url = URL(string: target) else {
            failed = true
            return
        }
        do {
            var request = URLRequest(url: url)
            if withKey,
               let key = UserDefaults.standard.string(forKey: "songbook.remoteKey"),
               !key.isEmpty {
                request.setValue(key, forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let doc = PDFDocument(data: data) else {
                failed = true
                return
            }
            document = doc
        } catch {
            AppLog.state.error("Songbook fetch failed for \(target): \(error)")
            failed = true
        }
    }
}

/// PDFKit wrapper that lands on the requested page.
struct SongPDFView: UIViewRepresentable {
    let document: PDFDocument
    let page: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        if let target = document.page(at: min(max(0, page - 1), document.pageCount - 1)) {
            view.go(to: target)
        }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if let target = document.page(at: min(max(0, page - 1), document.pageCount - 1)) {
            view.go(to: target)
        }
    }
}
