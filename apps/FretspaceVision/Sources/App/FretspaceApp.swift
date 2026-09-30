import SwiftUI

@main
struct FretspaceApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup(id: SceneID.controlPanel) {
            ControlPanelView()
                .environment(model)
        }
        .defaultSize(width: 480, height: 640)

        WindowGroup(id: SceneID.notation) {
            NotationPanelView()
                .environment(model)
        }
        .defaultSize(width: 700, height: 420)

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
    static let immersive = "fretboardSpace"
}
