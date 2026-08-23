import Foundation
import SwiftData

@Model
final class UsageDay {
    @Attribute(.unique) var dayKey: String
    var dayStart: Date
    var sessionCount: Int
    var inputWordCount: Int
    var inputCharacterCount: Int
    var captureDuration: TimeInterval
    var smartCleanupEditCount: Int
    var dictionaryFixCount: Int
    var snippetExpansionCount: Int

    init(
        dayKey: String,
        dayStart: Date,
        sessionCount: Int = 0,
        inputWordCount: Int = 0,
        inputCharacterCount: Int = 0,
        captureDuration: TimeInterval = 0,
        smartCleanupEditCount: Int = 0,
        dictionaryFixCount: Int = 0,
        snippetExpansionCount: Int = 0
    ) {
        self.dayKey = dayKey
        self.dayStart = dayStart
        self.sessionCount = sessionCount
        self.inputWordCount = inputWordCount
        self.inputCharacterCount = inputCharacterCount
        self.captureDuration = captureDuration
        self.smartCleanupEditCount = smartCleanupEditCount
        self.dictionaryFixCount = dictionaryFixCount
        self.snippetExpansionCount = snippetExpansionCount
    }
}

@Model
final class UsageAppDay {
    @Attribute(.unique) var aggregateKey: String
    var dayKey: String
    var dayStart: Date
    var bundleIdentifier: String
    var applicationName: String
    var sessionCount: Int
    var inputWordCount: Int
    var inputCharacterCount: Int
    var captureDuration: TimeInterval

    init(
        aggregateKey: String,
        dayKey: String,
        dayStart: Date,
        bundleIdentifier: String,
        applicationName: String,
        sessionCount: Int = 0,
        inputWordCount: Int = 0,
        inputCharacterCount: Int = 0,
        captureDuration: TimeInterval = 0
    ) {
        self.aggregateKey = aggregateKey
        self.dayKey = dayKey
        self.dayStart = dayStart
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.sessionCount = sessionCount
        self.inputWordCount = inputWordCount
        self.inputCharacterCount = inputCharacterCount
        self.captureDuration = captureDuration
    }
}

@Model
final class UsageReceipt {
    @Attribute(.unique) var sessionID: UUID

    init(sessionID: UUID) {
        self.sessionID = sessionID
    }
}

enum StatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
    case sevenDays
    case thirtyDays
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .allTime: "All time"
        }
    }

    func startDate(now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -6, to: today)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -29, to: today)
        case .allTime:
            return nil
        }
    }
}

struct UsageAppSummary: Identifiable, Equatable, Sendable {
    let bundleIdentifier: String
    let applicationName: String
    let sessionCount: Int
    let inputWordCount: Int
    let inputCharacterCount: Int
    let captureDuration: TimeInterval

    var id: String { bundleIdentifier }
}

struct UsageHeatmapDay: Identifiable, Equatable, Sendable {
    let date: Date
    let inputWordCount: Int
    let sessionCount: Int

    var id: Date { date }
}

struct StatisticsSnapshot: Equatable, Sendable {
    let sessionCount: Int
    let inputWordCount: Int
    let inputCharacterCount: Int
    let captureDuration: TimeInterval
    let smartCleanupEditCount: Int
    let dictionaryFixCount: Int
    let snippetExpansionCount: Int
    let wordsPerMinute: Double
    let estimatedTimeSaved: TimeInterval
    let monthToDateWordChange: Double?
    let activeDayCount: Int
    let currentStreak: Int
    let longestStreak: Int
    let heatmapDays: [UsageHeatmapDay]
    let apps: [UsageAppSummary]

    static let empty = StatisticsSnapshot(
        sessionCount: 0,
        inputWordCount: 0,
        inputCharacterCount: 0,
        captureDuration: 0,
        smartCleanupEditCount: 0,
        dictionaryFixCount: 0,
        snippetExpansionCount: 0,
        wordsPerMinute: 0,
        estimatedTimeSaved: 0,
        monthToDateWordChange: nil,
        activeDayCount: 0,
        currentStreak: 0,
        longestStreak: 0,
        heatmapDays: [],
        apps: []
    )
}
