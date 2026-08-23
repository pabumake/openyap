import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var session: DictationSession? {
        didSet {
            overlay.update(state: state, transcript: transcript, issue: session?.issue)
        }
    }
    @Published var localeIdentifier = "en_US"
    @Published var smartFormattingEnabled: Bool {
        didSet { UserDefaults.standard.set(smartFormattingEnabled, forKey: "smartFormattingEnabled") }
    }
    @Published private(set) var shortcut: ShortcutDefinition
    @Published private(set) var isRecordingShortcut = false
    @Published private(set) var inputMonitoringGranted = false
    @Published var audioInputSelection: AudioInputSelection {
        didSet { Self.saveAudioInputSelection(audioInputSelection) }
    }
    @Published private(set) var audioInputDevices: [AudioInputDevice] = []
    @Published private(set) var activeAudioInputName: String?
    @Published var appTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme")
            overlay.updateTheme(appTheme)
        }
    }
    @Published var minimizeWhenRecording: Bool {
        didSet { UserDefaults.standard.set(minimizeWhenRecording, forKey: "minimizeWhenRecording") }
    }
    @Published var startInMenuBarOnly: Bool {
        didSet { UserDefaults.standard.set(startInMenuBarOnly, forKey: "startInMenuBarOnly") }
    }
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginNeedsApproval = false
    @Published private(set) var shouldAskLaunchAtLogin: Bool
    @Published var settingsIssue: String?

    let historyStore: HistoryStore
    let statisticsStore: StatisticsStore
    let changelogStore: ChangelogStore
    let lexiconStore: LexiconStore
    let snippetStore: SnippetStore

    private let speechEngine = AppleSpeechEngine()
    private let transcriptPipeline = TranscriptPreparationPipeline()
    private let delivery = MacTextDelivery()
    private let overlay = DictationOverlayController()
    private let audioInputCatalog = AudioInputDeviceCatalog()
    private let launchAtLoginService = LaunchAtLoginService()
    private var shortcutMonitor: GlobalShortcutMonitor?
    private var shortcutRecordingMonitor: Any?
    private var previouslyActiveApplication: NSRunningApplication?

    var state: DictationState { session?.state ?? .idle }
    var transcript: String {
        guard let session else { return "" }
        return session.volatileText.isEmpty ? session.rawTranscript : session.volatileText
    }

    var canStart: Bool {
        session == nil || [.delivered, .failed, .awaitingDelivery].contains(state)
    }

    init(persistence: PersistenceController = .shared) {
        historyStore = HistoryStore(container: persistence.container)
        statisticsStore = StatisticsStore(container: persistence.container)
        changelogStore = ChangelogStore()
        lexiconStore = LexiconStore(container: persistence.container)
        snippetStore = SnippetStore(container: persistence.container)
        statisticsStore.backfill(historyStore.entries)
        lexiconStore.installStarterLexiconIfNeeded()
        smartFormattingEnabled = UserDefaults.standard.object(forKey: "smartFormattingEnabled") as? Bool ?? true
        shortcut = Self.loadShortcut()
        audioInputSelection = Self.loadAudioInputSelection()
        appTheme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .system
        minimizeWhenRecording = UserDefaults.standard.object(forKey: "minimizeWhenRecording") as? Bool ?? true
        startInMenuBarOnly = UserDefaults.standard.bool(forKey: "startInMenuBarOnly")
        shouldAskLaunchAtLogin = !UserDefaults.standard.bool(forKey: "didAskLaunchAtLogin")
        shortcutMonitor = GlobalShortcutMonitor(shortcut: shortcut) { [weak self] in self?.toggleCapture() }
        inputMonitoringGranted = shortcutMonitor?.start() == true
        refreshAudioInputDevices()
        refreshLaunchAtLoginStatus()
        overlay.updateTheme(appTheme)
        applyLaunchPresentation()
    }

    func toggleCapture() {
        switch state {
        case .preparing, .capturing:
            stop()
        case .finalizing, .preparingText, .delivering:
            break
        default:
            start()
        }
    }

    func start() {
        guard canStart else { return }
        previouslyActiveApplication = NSWorkspace.shared.frontmostApplication
        session = DictationSession(localeIdentifier: localeIdentifier)
        minimizeOpenYapWindowsIfNeeded()

        Task {
            do {
                let sessionLocale = session?.localeIdentifier ?? localeIdentifier
                let inputDevice = try await speechEngine.start(
                    locale: Locale(identifier: sessionLocale),
                    inputSelection: audioInputSelection
                ) { [weak self] text, isFinal in
                    self?.receive(text: text, isFinal: isFinal)
                }
                activeAudioInputName = inputDevice.name
                refreshAudioInputDevices()
                guard session?.state == .preparing else { return }
                session?.state = .capturing
                session?.captureStartedAt = .now
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func stop() {
        guard state == .capturing || state == .preparing else { return }
        session?.state = .finalizing
        session?.captureEndedAt = .now
        Task {
            do {
                try await speechEngine.stop()
                await finishAndDeliver()
            } catch {
                if session?.rawTranscript.isEmpty == false {
                    session?.isPartial = true
                    session?.issue = "Capture ended early. The recognized text was kept."
                    await finishAndDeliver()
                } else {
                    fail(error.localizedDescription)
                }
            }
        }
    }

    func cancel() {
        Task { await speechEngine.cancel() }
        session = nil
    }

    func copyAgain() {
        guard let session else { return }
        let text = historyStore.entry(for: session.id)?.currentText ?? session.deliveryText
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func retryDelivery() {
        guard state == .awaitingDelivery, let session else { return }
        let text = historyStore.entry(for: session.id)?.currentText ?? session.deliveryText
        Task { await attemptDelivery(text, sessionID: session.id) }
    }

    func requestAccessibility() {
        delivery.requestAccessibility()
    }

    func requestInputMonitoring() {
        inputMonitoringGranted = GlobalShortcutMonitor.requestInputMonitoringAccess()
        if inputMonitoringGranted {
            inputMonitoringGranted = shortcutMonitor?.start() == true
        }
    }

    func refreshAudioInputDevices() {
        audioInputDevices = audioInputCatalog.availableDevices()
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = launchAtLoginService.isRegistered
        launchAtLoginNeedsApproval = launchAtLoginService.requiresApproval
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool, openSystemSettings: Bool = false) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            refreshLaunchAtLoginStatus()
            settingsIssue = nil
            if enabled && (openSystemSettings || launchAtLoginNeedsApproval) {
                launchAtLoginService.openSystemSettings()
            }
        } catch {
            refreshLaunchAtLoginStatus()
            settingsIssue = error.localizedDescription
        }
    }

    func answerLaunchAtLoginPrompt(enable: Bool) {
        UserDefaults.standard.set(true, forKey: "didAskLaunchAtLogin")
        shouldAskLaunchAtLogin = false
        guard enable else { return }
        setLaunchAtLoginEnabled(true, openSystemSettings: true)
    }

    func openLoginItemsSettings() {
        launchAtLoginService.openSystemSettings()
    }

    func activateMainWindow() {
        NSApp.activate()
    }

    var selectedAudioInputIsUnavailable: Bool {
        guard case let .device(uid) = audioInputSelection else { return false }
        return !audioInputDevices.contains { $0.id == uid }
    }

    func beginShortcutRecording() {
        guard !isRecordingShortcut else {
            cancelShortcutRecording()
            return
        }
        isRecordingShortcut = true
        shortcutMonitor?.stop()
        shortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            Task { @MainActor in self?.captureShortcut(from: event) }
            return nil
        }
    }

    func resetShortcut() {
        saveShortcut(.rightOption)
    }

    private func captureShortcut(from event: NSEvent) {
        guard let captured = ShortcutDefinition.capture(from: event) else { return }
        saveShortcut(captured)
        cancelShortcutRecording()
    }

    private func cancelShortcutRecording() {
        if let shortcutRecordingMonitor { NSEvent.removeMonitor(shortcutRecordingMonitor) }
        shortcutRecordingMonitor = nil
        isRecordingShortcut = false
        inputMonitoringGranted = shortcutMonitor?.start() == true
    }

    private func saveShortcut(_ newShortcut: ShortcutDefinition) {
        shortcut = newShortcut
        shortcutMonitor?.update(shortcut: newShortcut)
        if let data = try? JSONEncoder().encode(newShortcut) {
            UserDefaults.standard.set(data, forKey: "dictationShortcut")
        }
    }

    private static func loadShortcut() -> ShortcutDefinition {
        guard let data = UserDefaults.standard.data(forKey: "dictationShortcut"),
              let shortcut = try? JSONDecoder().decode(ShortcutDefinition.self, from: data)
        else {
            return .rightOption
        }
        return shortcut
    }

    private static func loadAudioInputSelection() -> AudioInputSelection {
        guard let data = UserDefaults.standard.data(forKey: "audioInputSelection"),
              let selection = try? JSONDecoder().decode(AudioInputSelection.self, from: data)
        else {
            return .automatic
        }
        return selection
    }

    private static func saveAudioInputSelection(_ selection: AudioInputSelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: "audioInputSelection")
    }

    private func minimizeOpenYapWindowsIfNeeded() {
        guard minimizeWhenRecording else { return }
        for window in NSApp.windows where window.isVisible && !window.isMiniaturized && !(window is NSPanel) {
            window.miniaturize(nil)
        }
    }

    private func applyLaunchPresentation() {
        guard startInMenuBarOnly else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NSApp.setActivationPolicy(.accessory)
            for window in NSApp.windows where window.isVisible && !(window is NSPanel) {
                window.orderOut(nil)
            }
        }
    }

    private func receive(text: String, isFinal: Bool) {
        guard session?.state == .capturing || session?.state == .finalizing else { return }
        if isFinal {
            session?.finalSegments.append(text)
            session?.volatileText = ""
        } else {
            session?.volatileText = text
        }
    }

    private func finishAndDeliver() async {
        guard var current = session else { return }
        let raw = current.rawTranscript
        guard !raw.isEmpty else {
            fail("No speech was recognized. Try speaking closer to the microphone.")
            return
        }

        current.state = .preparingText
        session = current

        let locale = Locale(identifier: current.localeIdentifier)
        let terms = lexiconStore.termDefinitions(for: locale)
        let rules = lexiconStore.ruleDefinitions(for: locale)
        let snippets = snippetStore.definitions(for: locale)
        let prepared = await transcriptPipeline.prepare(
            rawTranscript: raw,
            locale: locale,
            smartFormattingEnabled: smartFormattingEnabled,
            terms: terms,
            rules: rules,
            snippets: snippets
        )

        guard var formattedSession = session, formattedSession.id == current.id else { return }
        formattedSession.deliveryText = prepared.initialDeliveryText
        formattedSession.issue = nil
        formattedSession.state = .awaitingDelivery
        session = formattedSession
        let endedAt = formattedSession.captureEndedAt ?? .now
        _ = historyStore.createEntry(
            sessionID: formattedSession.id,
            startedAt: formattedSession.startedAt,
            endedAt: endedAt,
            localeIdentifier: formattedSession.localeIdentifier,
            captureDuration: formattedSession.captureDuration,
            isPartial: formattedSession.isPartial,
            rawText: raw,
            result: prepared
        )
        statisticsStore.record(
            StatisticsSessionInput(
                sessionID: formattedSession.id,
                endedAt: endedAt,
                localeIdentifier: formattedSession.localeIdentifier,
                captureDuration: formattedSession.captureDuration,
                rawText: raw,
                formattedText: prepared.formattedText,
                appliedReplacements: prepared.appliedReplacements,
                targetBundleIdentifier: previouslyActiveApplication?.bundleIdentifier,
                targetApplicationName: previouslyActiveApplication?.localizedName
            )
        )
        await attemptDelivery(prepared.initialDeliveryText, sessionID: formattedSession.id)
    }

    private func attemptDelivery(_ text: String, sessionID: UUID) async {
        session?.state = .delivering
        if let target = previouslyActiveApplication, !target.isTerminated {
            target.activate()
        }
        let result = await delivery.deliver(text)
        switch result {
        case .pasted:
            session?.state = .delivered
            session?.issue = nil
            historyStore.updateOutcome(sessionID: sessionID, outcome: .delivered)
        case .copied:
            session?.state = .awaitingDelivery
            session?.issue = "Copied to the clipboard. Grant Accessibility access for automatic paste."
            historyStore.updateOutcome(sessionID: sessionID, outcome: .copied)
        }
    }

    private func fail(_ message: String) {
        session?.state = .failed
        session?.issue = message
    }
}
