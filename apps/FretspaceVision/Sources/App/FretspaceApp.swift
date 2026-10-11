import SwiftUI
import MusicTheory

@main
struct FretspaceApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        // The Harmony Compass is the app: it launches first, and every
        // other window originates from it.
        WindowGroup(id: SceneID.harmony) {
            HarmonyWheelView()
                .environment(model)
        }
        .defaultSize(width: 1180, height: 820)

        WindowGroup(id: SceneID.controlPanel) {
            ControlPanelView()
                .environment(model)
        }
        .defaultSize(width: 560, height: 700)

        WindowGroup(id: SceneID.notation) {
            NotationPanelView()
                .environment(model)
        }
        .defaultSize(width: 700, height: 420)

        WindowGroup(id: SceneID.scaleDetail, for: Scale.self) { $scale in
            if let scale {
                ScaleDetailView(scale: scale)
            }
        }
        .defaultSize(width: 1080, height: 690)
        .defaultWindowPlacement { _, context in
            // Scales open beside the compass, not on top of it.
            if let compass = context.windows.first(where: { $0.id == SceneID.harmony }) {
                return WindowPlacement(.trailing(compass))
            }
            return WindowPlacement()
        }

        WindowGroup(id: SceneID.chordDetail, for: Chord.self) { $chord in
            if let chord {
                ChordDetailView(chord: chord)
            }
        }
        .defaultSize(width: 1040, height: 560)
        .defaultWindowPlacement { _, context in
            if let compass = context.windows.first(where: { $0.id == SceneID.harmony }) {
                return WindowPlacement(.leading(compass))
            }
            return WindowPlacement()
        }

        ImmersiveSpace(id: SceneID.immersive) {
            ImmersiveView()
                .environment(model)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

enum SceneID {
    static let controlPanel = "controlPanel"
    static let notation = "notation"
    static let harmony = "harmonyWheel"
    static let scaleDetail = "scaleDetail"
    static let chordDetail = "chordDetail"
    static let compass3D = "compass3D"
    static let movement = "movement"
    static let immersive = "fretboardSpace"
}
