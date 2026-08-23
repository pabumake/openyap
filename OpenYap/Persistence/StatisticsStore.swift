import Combine
import Foundation
import SwiftData

struct StatisticsSessionInput: Sendable {
    let sessionID: UUID
    let endedAt: Date
    let localeIdentifier: String
    let captureDuration: TimeInterval
    let rawText: String
    let formattedText: String
    let appliedReplacements: [AppliedReplacementSnapshot]
    let targetBundleIdentifier: String?
    let targetApplicationName: String?
}

@MainActor
final class StatisticsStore: ObservableObject {
    @Published private(set) var revision = 0

    private let context: ModelContext
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let resetKey = "statisticsResetAt"
    private var days: [UsageDay] = []
    private var appDays: [UsageAppDay] = []
    private var receiptIDs: Set<UUID> = []

    init(
        container: ModelContainer,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        context = ModelContext(container)
        self.defaults = defaults
        self.calendar = calendar
        refresh()
    }

    func record(_ input: StatisticsSessionInput) {
        guard record(input, persist: false) else { return }
        saveAndRefresh()
    }

    func backfill(_ entries: [HistoryEntry]) {
        var changed = false
        for entry in entries {
            let replacements = entry.appliedReplacements.map {
                AppliedReplacementSnapshot(
                    sourceID: $0.sourceID,
                    kind: $0.kind,
                    recognizedText: $0.recognizedText,
                    replacementText: $0.replacementText,
                    occurrenceCount: $0.occurrenceCount
                )
            }
            changed = record(
                StatisticsSessionInput(
                    sessionID: entry.sessionID,
                    endedAt: entry.endedAt,
                    localeIdentifier: entry.localeIdentifier,
                    captureDuration: entry.captureDuration,
                    rawText: entry.rawText,
                    formattedText: entry.formattedText,
                    appliedReplacements: replacements,
                    targetBundleIdentifier: nil,
                    targetApplicationName: nil
                ),
                persist: false
            ) || changed
        }
        if changed { saveAndRefresh() }
    }

    func snapshot(for period: StatisticsPeriod, now: Date = .now) -> StatisticsSnapshot {
        let startDate = period.startDate(now: now, calendar: calendar)
        let selectedDays = days.filter { day in
            guard let startDate else { return true }
            return day.dayStart >= startDate && day.dayStart <= now
        }
        let selectedAppDays = appDays.filter { day in
            guard let startDate else { return true }
            return day.dayStart >= startDate && day.dayStart <= now
        }

        let wordCount = selectedDays.reduce(0) { $0 + $1.inputWordCount }
        let captureDuration = selectedDays.reduce(0) { $0 + $1.captureDuration }
        let wpm = captureDuration > 0 ? Double(wordCount) * 60 / captureDuration : 0
        let typingDuration = Double(wordCount) * 60 / 40
        let appSummaries = Dictionary(grouping: selectedAppDays, by: \.bundleIdentifier)
            .map { bundleIdentifier, values in
                UsageAppSummary(
                    bundleIdentifier: bundleIdentifier,
                    applicationName: values.last?.applicationName ?? "Unknown app",
                    sessionCount: values.reduce(0) { $0 + $1.sessionCount },
                    inputWordCount: values.reduce(0) { $0 + $1.inputWordCount },
                    inputCharacterCount: values.reduce(0) { $0 + $1.inputCharacterCount },
                    captureDuration: values.reduce(0) { $0 + $1.captureDuration }
                )
            }
            .sorted {
                if $0.inputWordCount == $1.inputWordCount {
                    return $0.applicationName.localizedCaseInsensitiveCompare($1.applicationName) == .orderedAscending
                }
                return $0.inputWordCount > $1.inputWordCount
            }

        return StatisticsSnapshot(
            sessionCount: selectedDays.reduce(0) { $0 + $1.sessionCount },
            inputWordCount: wordCount,
            inputCharacterCount: selectedDays.reduce(0) { $0 + $1.inputCharacterCount },
            captureDuration: captureDuration,
            smartCleanupEditCount: selectedDays.reduce(0) { $0 + $1.smartCleanupEditCount },
            dictionaryFixCount: selectedDays.reduce(0) { $0 + $1.dictionaryFixCount },
            snippetExpansionCount: selectedDays.reduce(0) { $0 + $1.snippetExpansionCount },
            wordsPerMinute: wpm,
            estimatedTimeSaved: max(0, typingDuration - captureDuration),
            monthToDateWordChange: monthToDateWordChange(now: now),
            activeDayCount: selectedDays.filter { $0.inputWordCount > 0 }.count,
            currentStreak: currentStreak(now: now),
            longestStreak: longestStreak(),
            heatmapDays: heatmap(now: now),
            apps: appSummaries
        )
    }

    func reset(now: Date = .now) {
        for day in days { context.delete(day) }
        for appDay in appDays { context.delete(appDay) }
        let receipts = (try? context.fetch(FetchDescriptor<UsageReceipt>())) ?? []
        for receipt in receipts { context.delete(receipt) }
        defaults.set(now, forKey: resetKey)
        saveAndRefresh()
    }

    private func record(_ input: StatisticsSessionInput, persist: Bool) -> Bool {
        guard !receiptIDs.contains(input.sessionID) else { return false }
        if let resetAt = defaults.object(forKey: resetKey) as? Date, input.endedAt <= resetAt {
            return false
        }

        let locale = Locale(identifier: input.localeIdentifier)
        let metrics = TranscriptMetrics.measure(input.rawText, locale: locale)
        let dayStart = calendar.startOfDay(for: input.endedAt)
        let dayKey = Self.dayKey(for: input.endedAt, calendar: calendar)
        let day = days.first { $0.dayKey == dayKey } ?? {
            let value = UsageDay(dayKey: dayKey, dayStart: dayStart)
            context.insert(value)
            days.append(value)
            return value
        }()
        day.sessionCount += 1
        day.inputWordCount += metrics.wordCount
        day.inputCharacterCount += metrics.characterCount
        day.captureDuration += max(0, input.captureDuration)
        day.smartCleanupEditCount += TranscriptChangeMetrics.wordEditCount(
            from: input.rawText,
            to: input.formattedText
        )
        day.dictionaryFixCount += input.appliedReplacements
            .filter { $0.kind == .term || $0.kind == .correction }
            .reduce(0) { $0 + $1.occurrenceCount }
        day.snippetExpansionCount += input.appliedReplacements
            .filter { $0.kind == .snippet }
            .reduce(0) { $0 + $1.occurrenceCount }

        let bundleIdentifier = input.targetBundleIdentifier ?? "unknown"
        let applicationName = input.targetApplicationName ?? "Unknown app"
        let aggregateKey = "\(dayKey)|\(bundleIdentifier)"
        let appDay = appDays.first { $0.aggregateKey == aggregateKey } ?? {
            let value = UsageAppDay(
                aggregateKey: aggregateKey,
                dayKey: dayKey,
                dayStart: dayStart,
                bundleIdentifier: bundleIdentifier,
                applicationName: applicationName
            )
            context.insert(value)
            appDays.append(value)
            return value
        }()
        appDay.applicationName = applicationName
        appDay.sessionCount += 1
        appDay.inputWordCount += metrics.wordCount
        appDay.inputCharacterCount += metrics.characterCount
        appDay.captureDuration += max(0, input.captureDuration)

        context.insert(UsageReceipt(sessionID: input.sessionID))
        receiptIDs.insert(input.sessionID)
        if persist { saveAndRefresh() }
        return true
    }

    private func monthToDateWordChange(now: Date) -> Double? {
        guard let currentMonth = calendar.dateInterval(of: .month, for: now),
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonth.start)
        else { return nil }
        let elapsedDayCount = max(1, calendar.dateComponents([.day], from: currentMonth.start, to: now).day.map { $0 + 1 } ?? 1)
        guard let previousEnd = calendar.date(byAdding: .day, value: elapsedDayCount, to: previousMonthStart) else {
            return nil
        }
        let currentWords = days
            .filter { $0.dayStart >= currentMonth.start && $0.dayStart <= now }
            .reduce(0) { $0 + $1.inputWordCount }
        let previousWords = days
            .filter { $0.dayStart >= previousMonthStart && $0.dayStart < previousEnd }
            .reduce(0) { $0 + $1.inputWordCount }
        guard previousWords > 0 else { return nil }
        return Double(currentWords - previousWords) / Double(previousWords)
    }

    private func currentStreak(now: Date) -> Int {
        let activeDays = Set(days.filter { $0.inputWordCount > 0 }.map { calendar.startOfDay(for: $0.dayStart) })
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        guard var cursor = activeDays.contains(today) ? today : yesterday,
              activeDays.contains(cursor)
        else { return 0 }
        var count = 0
        while activeDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private func longestStreak() -> Int {
        let activeDays = Set(days.filter { $0.inputWordCount > 0 }.map { calendar.startOfDay(for: $0.dayStart) })
        guard !activeDays.isEmpty else { return 0 }
        var longest = 0
        for day in activeDays {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day),
                  !activeDays.contains(previous)
            else { continue }
            var cursor = day
            var length = 0
            while activeDays.contains(cursor) {
                length += 1
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            longest = max(longest, length)
        }
        return longest
    }

    private func heatmap(now: Date) -> [UsageHeatmapDay] {
        let today = calendar.startOfDay(for: now)
        var counts: [Date: (words: Int, sessions: Int)] = [:]
        for day in days {
            let date = calendar.startOfDay(for: day.dayStart)
            let existing = counts[date] ?? (0, 0)
            counts[date] = (existing.words + day.inputWordCount, existing.sessions + day.sessionCount)
        }
        return (0..<84).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 83, to: today) else { return nil }
            let values = counts[date] ?? (0, 0)
            return UsageHeatmapDay(date: date, inputWordCount: values.words, sessionCount: values.sessions)
        }
    }

    private func refresh() {
        var dayDescriptor = FetchDescriptor<UsageDay>()
        dayDescriptor.sortBy = [SortDescriptor(\UsageDay.dayStart)]
        days = (try? context.fetch(dayDescriptor)) ?? []
        appDays = (try? context.fetch(FetchDescriptor<UsageAppDay>())) ?? []
        let receipts = (try? context.fetch(FetchDescriptor<UsageReceipt>())) ?? []
        receiptIDs = Set(receipts.map(\.sessionID))
        revision += 1
    }

    private func saveAndRefresh() {
        try? context.save()
        refresh()
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
