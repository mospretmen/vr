import SwiftUI

@main
struct FretspaceApp: App {
    @State private var model = AppModel()

    var body: some Scene {
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

        WindowGroup(id: SceneID.harmony) {
            HarmonyWheelView()
        }
        .defaultSize(width: 780, height: 840)

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
    static let immersive = "fretboardSpace"
}
