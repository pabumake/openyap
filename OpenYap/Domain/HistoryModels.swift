import Foundation
import SwiftData

enum LexiconLanguageScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case any
    case english
    case german

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any language"
        case .english: "English"
        case .german: "German"
        }
    }

    func matches(_ locale: Locale) -> Bool {
        guard self != .any else { return true }
        let language = locale.language.languageCode?.identifier
        return (self == .english && language == "en") || (self == .german && language == "de")
    }
}

enum DeliveryOutcome: String, Codable, Sendable {
    case awaitingDelivery
    case delivered
    case copied

    var title: String {
        switch self {
        case .awaitingDelivery: "Awaiting delivery"
        case .delivered: "Delivered"
        case .copied: "Copied"
        }
    }
}

enum TranscriptFormattingMode: String, Codable, Sendable {
    case raw
    case deterministic
    case languageModel

    var title: String {
        switch self {
        case .raw: "Raw transcript"
        case .deterministic: "Local cleanup"
        case .languageModel: "Smart cleanup"
        }
    }
}

enum ReplacementKind: String, Codable, Sendable {
    case term
    case correction
    case snippet

    var title: String {
        switch self {
        case .term: "Vocabulary term"
        case .correction: "Correction rule"
        case .snippet: "Snippet"
        }
    }
}

@Model
final class AppliedReplacement: Identifiable {
    @Attribute(.unique) var id: UUID
    var sourceID: UUID
    var kindRawValue: String
    var recognizedText: String
    var replacementText: String
    var occurrenceCount: Int
    var historyEntry: HistoryEntry?

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        kind: ReplacementKind,
        recognizedText: String,
        replacementText: String,
        occurrenceCount: Int
    ) {
        self.id = id
        self.sourceID = sourceID
        kindRawValue = kind.rawValue
        self.recognizedText = recognizedText
        self.replacementText = replacementText
        self.occurrenceCount = occurrenceCount
    }

    var kind: ReplacementKind {
        ReplacementKind(rawValue: kindRawValue) ?? .correction
    }
}

@Model
final class HistoryEntry: Identifiable {
    @Attribute(.unique) var sessionID: UUID
    var startedAt: Date
    var endedAt: Date
    var localeIdentifier: String
    var captureDuration: TimeInterval
    var isPartial: Bool
    var deliveryOutcomeRawValue: String
    var formattingModeRawValue: String
    var rawText: String
    var formattedText: String
    var wordListText: String?
    var initialDeliveryText: String
    var currentText: String
    @Relationship(deleteRule: .cascade, inverse: \AppliedReplacement.historyEntry)
    var appliedReplacements: [AppliedReplacement]

    init(
        sessionID: UUID,
        startedAt: Date,
        endedAt: Date,
        localeIdentifier: String,
        captureDuration: TimeInterval,
        isPartial: Bool,
        deliveryOutcome: DeliveryOutcome = .awaitingDelivery,
        formattingMode: TranscriptFormattingMode,
        rawText: String,
        formattedText: String,
        wordListText: String? = nil,
        initialDeliveryText: String,
        currentText: String,
        appliedReplacements: [AppliedReplacement] = []
    ) {
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.localeIdentifier = localeIdentifier
        self.captureDuration = captureDuration
        self.isPartial = isPartial
        deliveryOutcomeRawValue = deliveryOutcome.rawValue
        formattingModeRawValue = formattingMode.rawValue
        self.rawText = rawText
        self.formattedText = formattedText
        self.wordListText = wordListText
        self.initialDeliveryText = initialDeliveryText
        self.currentText = currentText
        self.appliedReplacements = appliedReplacements
    }

    var id: UUID { sessionID }
    var deliveryOutcome: DeliveryOutcome {
        get { DeliveryOutcome(rawValue: deliveryOutcomeRawValue) ?? .awaitingDelivery }
        set { deliveryOutcomeRawValue = newValue.rawValue }
    }
    var formattingMode: TranscriptFormattingMode {
        TranscriptFormattingMode(rawValue: formattingModeRawValue) ?? .raw
    }
    var effectiveWordListText: String {
        wordListText ?? initialDeliveryText
    }
}

@Model
final class LexiconTerm: Identifiable {
    @Attribute(.unique) var id: UUID
    var canonicalText: String
    var languageScopeRawValue: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        canonicalText: String,
        languageScope: LexiconLanguageScope,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.canonicalText = canonicalText
        languageScopeRawValue = languageScope.rawValue
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var languageScope: LexiconLanguageScope {
        get { LexiconLanguageScope(rawValue: languageScopeRawValue) ?? .any }
        set { languageScopeRawValue = newValue.rawValue }
    }
}

@Model
final class CorrectionRule: Identifiable {
    @Attribute(.unique) var id: UUID
    var recognizedText: String
    var replacementText: String
    var languageScopeRawValue: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recognizedText: String,
        replacementText: String,
        languageScope: LexiconLanguageScope,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.recognizedText = recognizedText
        self.replacementText = replacementText
        languageScopeRawValue = languageScope.rawValue
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var languageScope: LexiconLanguageScope {
        get { LexiconLanguageScope(rawValue: languageScopeRawValue) ?? .any }
        set { languageScopeRawValue = newValue.rawValue }
    }
}

struct LexiconTermDefinition: Identifiable, Sendable {
    let id: UUID
    let canonicalText: String
    let languageScope: LexiconLanguageScope
}

struct CorrectionRuleDefinition: Identifiable, Sendable {
    let id: UUID
    let recognizedText: String
    let replacementText: String
    let languageScope: LexiconLanguageScope
}

struct AppliedReplacementSnapshot: Sendable, Equatable {
    let sourceID: UUID
    let kind: ReplacementKind
    let recognizedText: String
    let replacementText: String
    let occurrenceCount: Int
}
