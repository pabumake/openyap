import Foundation
import XCTest
@testable import OpenYap

@MainActor
final class StatisticsStoreTests: XCTestCase {
    func testAggregatesSessionsWithoutCountingDuplicates() throws {
        let persistence = try PersistenceController(inMemory: true)
        let store = StatisticsStore(
            container: persistence.container,
            defaults: try makeDefaults(),
            calendar: calendar
        )
        let now = date(2026, 8, 24)
        let correctionID = UUID()

        let first = StatisticsSessionInput(
            sessionID: UUID(),
            endedAt: now,
            localeIdentifier: "en_US",
            captureDuration: 5,
            rawText: "um one two three four five",
            formattedText: "One two three four five.",
            appliedReplacements: [
                .init(
                    sourceID: correctionID,
                    kind: .correction,
                    recognizedText: "four",
                    replacementText: "Four",
                    occurrenceCount: 2
                ),
                .init(
                    sourceID: UUID(),
                    kind: .snippet,
                    recognizedText: "signature",
                    replacementText: "Pabu",
                    occurrenceCount: 1
                )
            ],
            targetBundleIdentifier: "com.apple.Notes",
            targetApplicationName: "Notes"
        )
        let second = StatisticsSessionInput(
            sessionID: UUID(),
            endedAt: now,
            localeIdentifier: "en_US",
            captureDuration: 15,
            rawText: "one two three four five six seven eight nine ten",
            formattedText: "One two three four five six seven eight nine ten.",
            appliedReplacements: [],
            targetBundleIdentifier: "com.apple.TextEdit",
            targetApplicationName: "TextEdit"
        )

        store.record(first)
        store.record(first)
        store.record(second)
        let snapshot = store.snapshot(for: .allTime, now: now)

        XCTAssertEqual(snapshot.sessionCount, 2)
        XCTAssertEqual(snapshot.inputWordCount, 16)
        XCTAssertEqual(snapshot.inputCharacterCount, first.rawText.count + second.rawText.count)
        XCTAssertEqual(snapshot.captureDuration, 20)
        XCTAssertEqual(snapshot.wordsPerMinute, 48, accuracy: 0.001)
        XCTAssertEqual(snapshot.estimatedTimeSaved, 4, accuracy: 0.001)
        XCTAssertEqual(snapshot.smartCleanupEditCount, 1)
        XCTAssertEqual(snapshot.dictionaryFixCount, 2)
        XCTAssertEqual(snapshot.snippetExpansionCount, 1)
        XCTAssertEqual(snapshot.apps.map(\.applicationName), ["TextEdit", "Notes"])
    }

    func testResetDoesNotBackfillOldHistoryAgain() throws {
        let persistence = try PersistenceController(inMemory: true)
        let defaults = try makeDefaults()
        let history = HistoryStore(container: persistence.container, defaults: defaults)
        let store = StatisticsStore(container: persistence.container, defaults: defaults, calendar: calendar)
        let now = date(2026, 8, 24)
        _ = history.createEntry(
            sessionID: UUID(),
            startedAt: now.addingTimeInterval(-5),
            endedAt: now,
            localeIdentifier: "en_US",
            captureDuration: 5,
            isPartial: false,
            rawText: "hello world",
            result: preparationResult(text: "Hello world.")
        )

        store.backfill(history.entries)
        XCTAssertEqual(store.snapshot(for: .allTime, now: now).inputWordCount, 2)

        store.reset(now: now.addingTimeInterval(1))
        store.backfill(history.entries)
        XCTAssertEqual(store.snapshot(for: .allTime, now: now.addingTimeInterval(1)).inputWordCount, 0)

        store.record(session(words: "new words count", at: now.addingTimeInterval(2)))
        XCTAssertEqual(store.snapshot(for: .allTime, now: now.addingTimeInterval(2)).inputWordCount, 3)
    }

    func testPeriodAndStreakCalculationsUseLocalDays() throws {
        let persistence = try PersistenceController(inMemory: true)
        let store = StatisticsStore(
            container: persistence.container,
            defaults: try makeDefaults(),
            calendar: calendar
        )
        let now = date(2026, 8, 24)
        for offset in [-40, -3, -2, -1] {
            store.record(session(words: "one two", at: calendar.date(byAdding: .day, value: offset, to: now)!))
        }

        let recent = store.snapshot(for: .sevenDays, now: now)
        XCTAssertEqual(recent.inputWordCount, 6)
        XCTAssertEqual(recent.activeDayCount, 3)
        XCTAssertEqual(recent.currentStreak, 3)
        XCTAssertEqual(recent.longestStreak, 3)
        XCTAssertEqual(recent.heatmapDays.count, 84)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func session(words: String, at date: Date) -> StatisticsSessionInput {
        StatisticsSessionInput(
            sessionID: UUID(),
            endedAt: date,
            localeIdentifier: "en_US",
            captureDuration: 2,
            rawText: words,
            formattedText: words,
            appliedReplacements: [],
            targetBundleIdentifier: "com.apple.Notes",
            targetApplicationName: "Notes"
        )
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
        let suite = "StatisticsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw NSError(domain: "StatisticsStoreTests", code: 1)
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
