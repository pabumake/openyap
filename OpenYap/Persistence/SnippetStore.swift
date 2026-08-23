import Combine
import Foundation
import SwiftData

enum SnippetStoreError: LocalizedError, Equatable {
    case emptyTrigger
    case emptyExpansion
    case duplicateTrigger

    var errorDescription: String? {
        switch self {
        case .emptyTrigger: "Enter the words that should trigger this snippet."
        case .emptyExpansion: "Enter the text OpenYap should insert."
        case .duplicateTrigger: "A snippet already uses that trigger for this language."
        }
    }
}

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [TextSnippet] = []

    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
        refresh()
    }

    func definitions(for locale: Locale) -> [SnippetDefinition] {
        snippets.filter { $0.isEnabled && $0.languageScope.matches(locale) }.map {
            SnippetDefinition(
                id: $0.id,
                triggerText: $0.triggerText,
                expansionText: $0.expansionText,
                languageScope: $0.languageScope
            )
        }
    }

    func matching(_ query: String) -> [TextSnippet] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return snippets }
        return snippets.filter {
            $0.triggerText.localizedCaseInsensitiveContains(text) ||
            $0.expansionText.localizedCaseInsensitiveContains(text)
        }
    }

    func save(
        id: UUID?,
        triggerText: String,
        expansionText: String,
        scope: LexiconLanguageScope
    ) throws {
        let trigger = triggerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trigger.isEmpty else { throw SnippetStoreError.emptyTrigger }
        guard !expansionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SnippetStoreError.emptyExpansion
        }
        guard !snippets.contains(where: {
            $0.id != id &&
            $0.triggerText.caseInsensitiveCompare(trigger) == .orderedSame &&
            scopesOverlap($0.languageScope, scope)
        }) else { throw SnippetStoreError.duplicateTrigger }

        if let id, let snippet = snippets.first(where: { $0.id == id }) {
            snippet.triggerText = trigger
            snippet.expansionText = expansionText
            snippet.languageScope = scope
            snippet.updatedAt = .now
        } else {
            context.insert(TextSnippet(triggerText: trigger, expansionText: expansionText, languageScope: scope))
        }
        try context.save()
        refresh()
    }

    func setEnabled(_ snippet: TextSnippet, isEnabled: Bool) {
        snippet.isEnabled = isEnabled
        snippet.updatedAt = .now
        saveAndRefresh()
    }

    func delete(_ snippet: TextSnippet) {
        context.delete(snippet)
        saveAndRefresh()
    }

    private func scopesOverlap(_ first: LexiconLanguageScope, _ second: LexiconLanguageScope) -> Bool {
        first == .any || second == .any || first == second
    }

    private func refresh() {
        var descriptor = FetchDescriptor<TextSnippet>()
        descriptor.sortBy = [SortDescriptor(\TextSnippet.triggerText)]
        snippets = (try? context.fetch(descriptor)) ?? []
    }

    private func saveAndRefresh() {
        try? context.save()
        refresh()
    }
}
