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
    }

    /// Book metadata + measured front-matter offsets (parity with the web).
    static let books: [String: Book] = [
        "realbk1": Book(name: "The Real Book I", file: "REALBK1.PDF", offset: 13),
        "realbk2": Book(name: "The Real Book II", file: "REALBK2.PDF", offset: 7),
        "realbk3": Book(name: "The Real Book III", file: "REALBK3.PDF", offset: 5),
        "newreal1": Book(name: "The New Real Book I", file: "NEWREAL1.PDF", offset: 0),
        "newreal2": Book(name: "The New Real Book II", file: "NEWREAL2.PDF", offset: 0),
        "newreal3": Book(name: "The New Real Book III", file: "NEWREAL3.PDF", offset: 0),
        "jazzfake": Book(name: "The Jazz Fakebook", file: "JAZZFAKE-1.PDF", offset: -1),
        "colorado": Book(name: "The Colorado Cookbook", file: "COLOBK.PDF", offset: 3),
        "jazzltd": Book(name: "Jazz LTD", file: "JAZZLTD.PDF", offset: 7),
        "library": Book(name: "Library of Musicians' Jazz", file: "LIBRARY.PDF", offset: 4),
        "evansbk": Book(name: "The Bill Evans Fakebook", file: "EVANSBK.PDF", offset: 3),
        "thebook": Book(name: "The Book (commercial)", file: "THEBOOK.PDF", offset: 13),
    ]

    static let all: [SongEntry] = {
        guard let url = Bundle.main.url(forResource: "songIndex", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([SongEntry].self, from: data)
        else {
            AppLog.state.error("Song index failed to load from bundle")
            return []
        }
        return entries
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
            TextField("https://your-bucket.example.com/songbooks", text: $remoteURL)
                .textFieldStyle(.roundedBorder)
                .onChange(of: remoteURL) { _, value in
                    UserDefaults.standard.set(value, forKey: "songbook.remoteURL")
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
        } else if failed || remoteURL.isEmpty {
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
        guard !remoteURL.isEmpty, let book else { return }
        let base = remoteURL.hasSuffix("/") ? String(remoteURL.dropLast()) : remoteURL
        guard let encoded = book.file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(base)/\(encoded)") else {
            failed = true
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let doc = PDFDocument(data: data) else {
                failed = true
                return
            }
            document = doc
        } catch {
            AppLog.state.error("Songbook fetch failed for \(book.file): \(error)")
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
