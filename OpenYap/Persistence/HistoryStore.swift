import Combine
import Foundation
import SwiftData

enum HistoryRetentionPolicy: Int, CaseIterable, Identifiable, Sendable {
    case thirtyDays = 30
    case ninetyDays = 90
    case untilDeleted = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .untilDeleted: "Until deleted"
        }
    }

    var retentionDays: Int? {
        self == .untilDeleted ? nil : rawValue
    }

    func isStricter(than other: HistoryRetentionPolicy) -> Bool {
        switch (retentionDays, other.retentionDays) {
        case let (.some(new), .some(old)): new < old
        case (.some, .none): true
        default: false
        }
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    @Published private(set) var retentionPolicy: HistoryRetentionPolicy

    private let context: ModelContext
    private let defaults: UserDefaults
    private let retentionKey = "historyRetentionDays"

    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        context = ModelContext(container)
        self.defaults = defaults
        let storedValue = defaults.object(forKey: retentionKey) as? Int
        retentionPolicy = storedValue.flatMap(HistoryRetentionPolicy.init(rawValue:)) ?? .thirtyDays
        purgeExpired()
        refresh()
    }

    @discardableResult
    func createEntry(
        sessionID: UUID,
        startedAt: Date,
        endedAt: Date,
        localeIdentifier: String,
        captureDuration: TimeInterval,
        isPartial: Bool,
        rawText: String,
        result: TranscriptPreparationResult
    ) -> HistoryEntry {
        if let existing = entry(for: sessionID) { return existing }
        let replacements = result.appliedReplacements.map {
            AppliedReplacement(
                sourceID: $0.sourceID,
                kind: $0.kind,
                recognizedText: $0.recognizedText,
                replacementText: $0.replacementText,
                occurrenceCount: $0.occurrenceCount
            )
        }
        let entry = HistoryEntry(
            sessionID: sessionID,
            startedAt: startedAt,
            endedAt: endedAt,
            localeIdentifier: localeIdentifier,
            captureDuration: captureDuration,
            isPartial: isPartial,
            formattingMode: result.formattingMode,
            rawText: rawText,
            formattedText: result.formattedText,
            wordListText: result.wordListText,
            initialDeliveryText: result.initialDeliveryText,
            currentText: result.initialDeliveryText,
            appliedReplacements: replacements
        )
        context.insert(entry)
        saveAndRefresh()
        purgeExpired()
        return entry
    }

    func updateOutcome(sessionID: UUID, outcome: DeliveryOutcome) {
        guard let entry = entry(for: sessionID) else { return }
        entry.deliveryOutcome = outcome
        saveAndRefresh()
    }

    func updateCurrentText(entryID: UUID, text: String) {
        guard let entry = entry(for: entryID), entry.currentText != text else { return }
        entry.currentText = text
        saveAndRefresh()
    }

    func delete(_ entry: HistoryEntry) {
        context.delete(entry)
        saveAndRefresh()
    }

    func clear() {
        for entry in entries {
            context.delete(entry)
        }
        saveAndRefresh()
    }

    func setRetentionPolicy(_ policy: HistoryRetentionPolicy) {
        retentionPolicy = policy
        defaults.set(policy.rawValue, forKey: retentionKey)
        purgeExpired()
        refresh()
    }

    func purgeExpired(now: Date = .now) {
        guard let days = retentionPolicy.retentionDays,
              let cutoff = Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: now)
        else { return }
        let descriptor = FetchDescriptor<HistoryEntry>()
        guard let storedEntries = try? context.fetch(descriptor) else { return }
        var changed = false
        for entry in storedEntries where entry.endedAt < cutoff {
            context.delete(entry)
            changed = true
        }
        if changed { saveAndRefresh() }
    }

    func entry(for id: UUID) -> HistoryEntry? {
        entries.first { $0.sessionID == id }
    }

    private func refresh() {
        var descriptor = FetchDescriptor<HistoryEntry>()
        descriptor.sortBy = [SortDescriptor(\HistoryEntry.endedAt, order: .reverse)]
        entries = (try? context.fetch(descriptor)) ?? []
    }

    private func saveAndRefresh() {
        try? context.save()
        refresh()
    }
}
