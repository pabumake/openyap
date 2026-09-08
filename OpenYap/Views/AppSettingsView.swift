import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var history: HistoryStore
    @ObservedObject var statistics: StatisticsStore
    @ObservedObject var updates: AppUpdateController
    @Environment(\.openYapTheme) private var theme
    @State private var pendingRetention: HistoryRetentionPolicy?
    @State private var confirmRetentionChange = false
    @State private var confirmClearHistory = false
    @State private var confirmResetStatistics = false

    var body: some View {
        Form {
            Section("Dictation") {
                Picker("Speech language", selection: $model.localeIdentifier) {
                    Text("English (US)").tag("en_US")
                    Text("German (Germany)").tag("de_DE")
                }
                Picker("Microphone", selection: $model.audioInputSelection) {
                    Text("Automatic").tag(AudioInputSelection.automatic)
                    ForEach(model.audioInputDevices) { device in
                        Text(device.name).tag(AudioInputSelection.device(uid: device.id))
                    }
                    if model.selectedAudioInputIsUnavailable {
                        Text("Selected microphone (not connected)").tag(model.audioInputSelection)
                    }
                }
                if model.selectedAudioInputIsUnavailable {
                    Label(
                        "The selected microphone is not connected. Connect it or choose Automatic.",
                        systemImage: "mic.slash"
                    )
                    .foregroundStyle(.orange)
                } else if model.audioInputDevices.isEmpty {
                    Label("No microphone is available.", systemImage: "mic.slash")
                        .foregroundStyle(.orange)
                }
                if let activeInputName = model.activeAudioInputName {
                    LabeledContent("Last used", value: activeInputName)
                }
                HStack {
                    Text("Automatic prefers connected AirPods, then the built-in microphone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") { model.refreshAudioInputDevices() }
                }
                Toggle("Smart formatting with the local language model", isOn: $model.smartFormattingEnabled)
                Toggle("Minimize OpenYap when recording starts", isOn: $model.minimizeWhenRecording)
                Button("Enable automatic paste") { model.requestAccessibility() }
            }

            Section("General") {
                Toggle("Launch OpenYap at login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                ))
                Toggle("Start in menu bar only", isOn: $model.startInMenuBarOnly)
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.automaticallyChecksForUpdates = $0 }
                ))
                HStack {
                    Text("Automatic checks run once a day. OpenYap asks before it downloads and installs an update.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check Now") { updates.checkForUpdates() }
                        .disabled(!updates.canCheckForUpdates)
                }
                Text("Hides the main window and Dock icon the next time OpenYap starts. Use the menu bar icon to open the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.launchAtLoginNeedsApproval {
                    LabeledContent {
                        Button("Open Login Items") { model.openLoginItemsSettings() }
                    } label: {
                        Label("macOS needs approval before OpenYap can launch at login.", systemImage: "person.badge.key")
                            .foregroundStyle(.orange)
                    }
                }
                Picker("Appearance", selection: $model.appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        HStack {
                            Circle().fill(theme.palette.accent).frame(width: 10, height: 10)
                            Text(theme.title)
                        }
                        .tag(theme)
                    }
                }
            }

            Section("Shortcut") {
                LabeledContent("Dictation shortcut") {
                    HStack {
                        Button(model.isRecordingShortcut ? "Press a shortcut..." : model.shortcut.displayName) {
                            model.beginShortcutRecording()
                        }
                        Button("Reset") { model.resetShortcut() }
                            .disabled(model.shortcut == .rightOption)
                    }
                }
                if !model.inputMonitoringGranted {
                    LabeledContent {
                        Button("Enable shortcut") { model.requestInputMonitoring() }
                    } label: {
                        Label("Input Monitoring is required for the global shortcut.", systemImage: "keyboard.badge.ellipsis")
                            .foregroundStyle(.orange)
                    }
                }
                Text("Press \(model.shortcut.displayName) anywhere to start or stop dictation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("History") {
                Picker("Keep transcriptions", selection: Binding(
                    get: { history.retentionPolicy },
                    set: { requestRetentionChange($0) }
                )) {
                    ForEach(HistoryRetentionPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                Button("Clear history", role: .destructive) { confirmClearHistory = true }
                    .disabled(history.entries.isEmpty)
                Text("Clearing transcripts does not reset your numeric usage statistics. OpenYap never stores microphone audio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Statistics") {
                Button("Reset statistics", role: .destructive) { confirmResetStatistics = true }
                    .disabled(statistics.snapshot(for: .allTime).sessionCount == 0)
                Text("Statistics contain daily counts and destination app names, but no transcript text or audio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(theme.palette.base)
        .padding(20)
        .navigationTitle("Settings")
        .onAppear { model.refreshAudioInputDevices() }
        .onAppear { model.refreshLaunchAtLoginStatus() }
        .alert("Could not update the setting", isPresented: Binding(
            get: { model.settingsIssue != nil },
            set: { if !$0 { model.settingsIssue = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(model.settingsIssue ?? "Unknown error")
        }
        .alert("Shorten history retention?", isPresented: $confirmRetentionChange) {
            Button("Apply", role: .destructive) {
                if let pendingRetention { history.setRetentionPolicy(pendingRetention) }
                pendingRetention = nil
            }
            Button("Cancel", role: .cancel) { pendingRetention = nil }
        } message: {
            Text("Transcriptions older than the new limit will be deleted from this Mac.")
        }
        .alert("Clear all history?", isPresented: $confirmClearHistory) {
            Button("Clear history", role: .destructive) { history.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every saved transcript and edit from this Mac. Statistics remain available.")
        }
        .alert("Reset all statistics?", isPresented: $confirmResetStatistics) {
            Button("Reset statistics", role: .destructive) { statistics.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes usage totals, streaks, and app breakdowns. Saved transcripts remain in History.")
        }
    }

    private func requestRetentionChange(_ policy: HistoryRetentionPolicy) {
        if policy.isStricter(than: history.retentionPolicy) {
            pendingRetention = policy
            confirmRetentionChange = true
        } else {
            history.setRetentionPolicy(policy)
        }
    }
}
