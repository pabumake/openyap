import AppIntents
import SwiftUI

@main
struct CapturePrototypeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = PrototypeController()

    var body: some Scene {
        WindowGroup {
            PrototypeContentView(controller: controller)
                .onOpenURL { url in
                    controller.handleOpenURL(url)
                }
                .task {
                    controller.startPolling()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            controller.recordScenePhase(String(describing: newPhase))
        }
    }
}

struct PrototypeAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPrototypeCaptureIntent(),
                phrases: ["Start \(.applicationName) prototype capture"],
            shortTitle: "Start OpenYap Capture",
            systemImageName: "waveform"
        )
    }
}
