import Foundation
import XCTest
@testable import OpenYap

@MainActor
final class HistoryStoreTests: XCTestCase {
    func testEntryIsCreatedOnceAndCanBeEdited() throws {
        let persistence = try PersistenceController(inMemory: true)
        let defaults = try makeDefaults()
        let store = HistoryStore(container: persistence.container, defaults: defaults)
        let id = UUID()
        let result = preparationResult(text: "Hello world")

        _ = store.createEntry(
            sessionID: id,
            startedAt: .now,
            endedAt: .now,
            localeIdentifier: "en_US",
            captureDuration: 4,
            isPartial: false,
            rawText: "um hello world",
            result: result
        )
        _ = store.createEntry(
            sessionID: id,
            startedAt: .now,
            endedAt: .now,
            localeIdentifier: "en_US",
            captureDuration: 4,
            isPartial: false,
            rawText: "duplicate",
            result: result
        )
        store.updateCurrentText(entryID: id, text: "Edited text")
        store.updateOutcome(sessionID: id, outcome: .delivered)

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.rawText, "um hello world")
        XCTAssertEqual(store.entries.first?.currentText, "Edited text")
        XCTAssertEqual(store.entries.first?.deliveryOutcome, .delivered)
    }

    func testThirtyDayRetentionDeletesOnlyExpiredEntries() throws {
        let persistence = try PersistenceController(inMemory: true)
        let defaults = try makeDefaults()
        defaults.set(HistoryRetentionPolicy.untilDeleted.rawValue, forKey: "historyRetentionDays")
        let store = HistoryStore(container: persistence.container, defaults: defaults)
        let now = Date()

        for age in [29, 31] {
            let date = Calendar.current.date(byAdding: .day, value: -age, to: now)!
            _ = store.createEntry(
                sessionID: UUID(),
                startedAt: date,
                endedAt: date,
                localeIdentifier: "en_US",
                captureDuration: 2,
                isPartial: false,
                rawText: "Entry \(age)",
                result: preparationResult(text: "Entry \(age)")
            )
        }

        store.setRetentionPolicy(.thirtyDays)
        store.purgeExpired(now: now)

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.rawText, "Entry 29")
    }

    func testAppliedReplacementSurvivesWithHistoryEntry() throws {
        let persistence = try PersistenceController(inMemory: true)
        let defaults = try makeDefaults()
        let store = HistoryStore(container: persistence.container, defaults: defaults)
        let ruleID = UUID()
        let result = TranscriptPreparationResult(
            formattedText: "open yap works",
            wordListText: "OpenYap works",
            initialDeliveryText: "OpenYap works\nRegards,\nPabu",
            formattingMode: .languageModel,
            appliedReplacements: [
                AppliedReplacementSnapshot(
                    sourceID: ruleID,
                    kind: .correction,
                    recognizedText: "open yap",
                    replacementText: "OpenYap",
                    occurrenceCount: 1
                ),
                AppliedReplacementSnapshot(
                    sourceID: UUID(),
                    kind: .snippet,
                    recognizedText: "my signature",
                    replacementText: "Regards,\nPabu",
                    occurrenceCount: 1
                )
            ]
        )

        let entry = store.createEntry(
            sessionID: UUID(),
            startedAt: .now,
            endedAt: .now,
            localeIdentifier: "en_US",
            captureDuration: 3,
            isPartial: true,
            rawText: "um open yap works",
            result: result
        )

        XCTAssertTrue(entry.isPartial)
        XCTAssertEqual(entry.wordListText, "OpenYap works")
        XCTAssertEqual(entry.initialDeliveryText, "OpenYap works\nRegards,\nPabu")
        XCTAssertEqual(entry.appliedReplacements.count, 2)
        let correction = entry.appliedReplacements.first { $0.kind == .correction }
        XCTAssertEqual(correction?.sourceID, ruleID)
        XCTAssertNotNil(entry.appliedReplacements.first { $0.kind == .snippet })
    }

    func testOlderEntryUsesInitialDeliveryTextForMissingWordListStage() {
        let entry = HistoryEntry(
            sessionID: UUID(),
            startedAt: .now,
            endedAt: .now,
            localeIdentifier: "en_US",
            captureDuration: 2,
            isPartial: false,
            formattingMode: .deterministic,
            rawText: "open yap",
            formattedText: "open yap",
            wordListText: nil,
            initialDeliveryText: "OpenYap",
            currentText: "OpenYap"
        )

        XCTAssertEqual(entry.effectiveWordListText, "OpenYap")
    }

    private func preparationResult(text: String) -> TranscriptPreparationResult {
        TranscriptPreparationResult(
            formattedText: text,
            initialDeliveryText: text,
            formattingMode: .deterministic,
            appliedReplacements: []
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "HistoryStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw NSError(domain: "HistoryStoreTests", code: 1)
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
