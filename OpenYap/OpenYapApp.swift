import SwiftUI

@main
struct OpenYapApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var updates = AppUpdateController()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("OpenYap", id: "main") {
            ContentView(model: model, updates: updates)
                .openYapTheme(model.appTheme)
        }
        .defaultSize(width: 1_080, height: 720)

        MenuBarExtra {
            Button("Open OpenYap") {
                openWindow(id: "main")
                model.activateMainWindow()
            }

            Divider()
            Button(menuBarActionTitle) {
                model.toggleCapture()
            }
            .keyboardShortcut("d")

            if !model.transcript.isEmpty {
                Divider()
                Text(model.transcript)
                    .lineLimit(3)
                Button("Copy transcript") {
                    model.copyAgain()
                }
            }

            Divider()
            Button("Check for Updates...") {
                updates.checkForUpdates()
            }
            .disabled(!updates.canCheckForUpdates)
            SettingsLink()
            Button("Quit OpenYap") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "waveform")
                .accessibilityLabel("OpenYap")
        }

        Settings {
            AppSettingsView(
                model: model,
                history: model.historyStore,
                statistics: model.statisticsStore,
                updates: updates
            )
                .frame(width: 620, height: 560)
                .openYapTheme(model.appTheme)
        }
    }

    private var menuBarActionTitle: String {
        switch model.state {
        case .capturing, .preparing: "Stop dictation"
        default: "Start dictation"
        }
    }
}
