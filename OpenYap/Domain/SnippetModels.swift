import Foundation
import SwiftData

@Model
final class TextSnippet: Identifiable {
    @Attribute(.unique) var id: UUID
    var triggerText: String
    var expansionText: String
    var languageScopeRawValue: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        triggerText: String,
        expansionText: String,
        languageScope: LexiconLanguageScope,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.triggerText = triggerText
        self.expansionText = expansionText
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

struct SnippetDefinition: Identifiable, Sendable {
    let id: UUID
    let triggerText: String
    let expansionText: String
    let languageScope: LexiconLanguageScope
}
