import SwiftUI
import MusicTheory

/// Browse backing tracks: bundled starter progressions (always available,
/// offline) plus the remote library when the backend is reachable. Selecting
/// a track loads its timeline into the backing controller and dismisses.
struct TrackLibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    enum RemotePhase {
        case loading
        case loaded([TrackSummary])
        case unavailable
    }

    @State private var remote: RemotePhase = .loading
    @State private var loadingTrackID: String?
    private let client = TrackLibraryClient()

    var body: some View {
        NavigationStack {
            List {
                Section("Bundled") {
                    ForEach(StarterProgression.all) { starter in
                        Button {
                            model.backing.load(starter.timeline, title: starter.title)
                            dismiss()
                        } label: {
                            LabeledContent(starter.title) {
                                keyBadge(starter.timeline.key)
                            }
                        }
                    }
                }

                Section("Library") {
                    switch remote {
                    case .loading:
                        HStack {
                            ProgressView()
                            Text("Loading library…").foregroundStyle(.secondary)
                        }
                    case .unavailable:
                        Label("Library unreachable — bundled tracks still work.",
                              systemImage: "wifi.exclamationmark")
                            .foregroundStyle(.secondary)
                        Button("Try Again") {
                            remote = .loading
                            Task { await loadRemote() }
                        }
                    case .loaded(let tracks) where tracks.isEmpty:
                        Text("No tracks in the library yet.")
                            .foregroundStyle(.secondary)
                    case .loaded(let tracks):
                        ForEach(tracks) { track in
                            Button {
                                Task { await select(track) }
                            } label: {
                                LabeledContent {
                                    if loadingTrackID == track.id {
                                        ProgressView()
                                    } else {
                                        keyBadge(track.key)
                                    }
                                } label: {
                                    Text(track.title)
                                    Text("\(Int(track.bpm)) bpm")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(loadingTrackID != nil)
                        }
                    }
                }
            }
            .navigationTitle("Backing Tracks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await loadRemote() }
    }

    @ViewBuilder
    private func keyBadge(_ key: Scale?) -> some View {
        if let key {
            Text(key.name)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.thinMaterial, in: .capsule)
        }
    }

    private func loadRemote() async {
        do {
            remote = .loaded(try await client.tracks())
        } catch {
            AppLog.network.error("Track list fetch failed: \(error)")
            remote = .unavailable
        }
    }

    private func select(_ track: TrackSummary) async {
        loadingTrackID = track.id
        defer { loadingTrackID = nil }
        do {
            let timeline = try await client.timeline(trackID: track.id)
            model.backing.load(timeline, title: track.title)
            dismiss()
        } catch TrackLibraryClient.ClientError.trackNotFound {
            model.presentedError = .trackNotFound
            await loadRemote() // refresh the stale list
        } catch {
            model.presentedError = .trackLibraryUnreachable
        }
    }
}
