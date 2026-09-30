import MusicTheory

/// The bundled offline progression catalog shown in the control panel.
/// The backend's track library supersedes this once accounts/streaming land.
struct StarterProgression: Identifiable {
    let id: String
    let title: String
    let timeline: ChordTimeline

    static let all: [StarterProgression] = [
        .init(id: "blues-a", title: "12-Bar Blues in A",
              timeline: ProgressionTemplate.twelveBarBlues(in: .a)),
        .init(id: "blues-e", title: "12-Bar Blues in E",
              timeline: ProgressionTemplate.twelveBarBlues(in: .e)),
        .init(id: "blues-g", title: "12-Bar Blues in G",
              timeline: ProgressionTemplate.twelveBarBlues(in: .g)),
        .init(id: "251-c", title: "ii–V–I in C",
              timeline: ProgressionTemplate.twoFiveOne(in: .c)),
        .init(id: "pop-g", title: "Pop Loop in G (I–V–vi–IV)",
              timeline: ProgressionTemplate.popLoop(in: .g)),
    ]
}
