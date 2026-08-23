import Combine
import Foundation
import SwiftData

enum LexiconStoreError: LocalizedError, Equatable {
    case emptyTerm
    case emptyRecognizedText
    case emptyReplacementText
    case duplicateTerm
    case duplicateRule

    var errorDescription: String? {
        switch self {
        case .emptyTerm: "Enter a vocabulary term."
        case .emptyRecognizedText: "Enter the words OpenYap should look for."
        case .emptyReplacementText: "Enter the replacement text."
        case .duplicateTerm: "A vocabulary term already covers that language."
        case .duplicateRule: "A correction rule already covers that phrase and language."
        }
    }
}

@MainActor
final class LexiconStore: ObservableObject {
    @Published private(set) var terms: [LexiconTerm] = []
    @Published private(set) var rules: [CorrectionRule] = []

    private let context: ModelContext

    private static let starterLexiconVersion = 1
    private static let starterLexiconVersionKey = "starterLexiconVersion"
    private static let starterTerms: [(String, LexiconLanguageScope)] = [
        ("OpenYap", .any),
        ("AirPods", .any),
        ("AirDrop", .any),
        ("AirPlay", .any),
        ("App Store", .any),
        ("Apple Intelligence", .any),
        ("Apple Music", .any),
        ("Apple Silicon", .any),
        ("Apple TV", .any),
        ("Apple Watch", .any),
        ("CarPlay", .any),
        ("HomePod", .any),
        ("iCloud", .any),
        ("iOS", .any),
        ("iPadOS", .any),
        ("MacBook", .any),
        ("macOS", .any),
        ("visionOS", .any),
        ("watchOS", .any)
    ]
    private static let starterRules: [(String, String, LexiconLanguageScope)] = [
        ("open yap", "OpenYap", .any),
        ("open yet", "OpenYap", .english),
        ("air pods", "AirPods", .any),
        ("airports", "AirPods", .english),
        ("mac os", "macOS", .any)
    ]

    init(container: ModelContainer) {
        context = ModelContext(container)
        refresh()
    }

    func installStarterLexiconIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.integer(forKey: Self.starterLexiconVersionKey) < Self.starterLexiconVersion else { return }

        for (text, scope) in Self.starterTerms where !terms.contains(where: {
            $0.canonicalText.caseInsensitiveCompare(text) == .orderedSame && scopesOverlap($0.languageScope, scope)
        }) {
            context.insert(LexiconTerm(canonicalText: text, languageScope: scope))
        }

        for (recognized, replacement, scope) in Self.starterRules where !rules.contains(where: {
            $0.recognizedText.caseInsensitiveCompare(recognized) == .orderedSame && scopesOverlap($0.languageScope, scope)
        }) {
            context.insert(
                CorrectionRule(
                    recognizedText: recognized,
                    replacementText: replacement,
                    languageScope: scope
                )
            )
        }

        do {
            try context.save()
            defaults.set(Self.starterLexiconVersion, forKey: Self.starterLexiconVersionKey)
            refresh()
        } catch {
            context.rollback()
        }
    }

    func termDefinitions(for locale: Locale) -> [LexiconTermDefinition] {
        terms.filter { $0.isEnabled && $0.languageScope.matches(locale) }.map {
            LexiconTermDefinition(id: $0.id, canonicalText: $0.canonicalText, languageScope: $0.languageScope)
        }
    }

    func ruleDefinitions(for locale: Locale) -> [CorrectionRuleDefinition] {
        rules.filter { $0.isEnabled && $0.languageScope.matches(locale) }.map {
            CorrectionRuleDefinition(
                id: $0.id,
                recognizedText: $0.recognizedText,
                replacementText: $0.replacementText,
                languageScope: $0.languageScope
            )
        }
    }

    func saveTerm(id: UUID?, canonicalText: String, scope: LexiconLanguageScope) throws {
        let text = canonicalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw LexiconStoreError.emptyTerm }
        guard !terms.contains(where: {
            $0.id != id && $0.canonicalText.caseInsensitiveCompare(text) == .orderedSame && scopesOverlap($0.languageScope, scope)
        }) else { throw LexiconStoreError.duplicateTerm }

        if let id, let term = terms.first(where: { $0.id == id }) {
            term.canonicalText = text
            term.languageScope = scope
            term.updatedAt = .now
        } else {
            context.insert(LexiconTerm(canonicalText: text, languageScope: scope))
        }
        saveAndRefresh()
    }

    func saveRule(
        id: UUID?,
        recognizedText: String,
        replacementText: String,
        scope: LexiconLanguageScope
    ) throws {
        let recognized = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = replacementText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recognized.isEmpty else { throw LexiconStoreError.emptyRecognizedText }
        guard !replacement.isEmpty else { throw LexiconStoreError.emptyReplacementText }
        guard !rules.contains(where: {
            $0.id != id && $0.recognizedText.caseInsensitiveCompare(recognized) == .orderedSame && scopesOverlap($0.languageScope, scope)
        }) else { throw LexiconStoreError.duplicateRule }

        if let id, let rule = rules.first(where: { $0.id == id }) {
            rule.recognizedText = recognized
            rule.replacementText = replacement
            rule.languageScope = scope
            rule.updatedAt = .now
        } else {
            context.insert(
                CorrectionRule(
                    recognizedText: recognized,
                    replacementText: replacement,
                    languageScope: scope
                )
            )
        }
        saveAndRefresh()
    }

    func setEnabled(term: LexiconTerm, isEnabled: Bool) {
        term.isEnabled = isEnabled
        term.updatedAt = .now
        saveAndRefresh()
    }

    func setEnabled(rule: CorrectionRule, isEnabled: Bool) {
        rule.isEnabled = isEnabled
        rule.updatedAt = .now
        saveAndRefresh()
    }

    func delete(_ term: LexiconTerm) {
        context.delete(term)
        saveAndRefresh()
    }

    func delete(_ rule: CorrectionRule) {
        context.delete(rule)
        saveAndRefresh()
    }

    private func scopesOverlap(_ first: LexiconLanguageScope, _ second: LexiconLanguageScope) -> Bool {
        first == .any || second == .any || first == second
    }

    private func refresh() {
        var termDescriptor = FetchDescriptor<LexiconTerm>()
        termDescriptor.sortBy = [SortDescriptor(\LexiconTerm.canonicalText)]
        terms = (try? context.fetch(termDescriptor)) ?? []

        var ruleDescriptor = FetchDescriptor<CorrectionRule>()
        ruleDescriptor.sortBy = [SortDescriptor(\CorrectionRule.recognizedText)]
        rules = (try? context.fetch(ruleDescriptor)) ?? []
    }

    private func saveAndRefresh() {
        try? context.save()
        refresh()
    }
}
