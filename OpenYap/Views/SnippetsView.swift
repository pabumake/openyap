import SwiftUI

private struct SnippetDraft: Identifiable {
    let id = UUID()
    let sourceID: UUID?
    var triggerText: String
    var expansionText: String
    var scope: LexiconLanguageScope

    init(snippet: TextSnippet? = nil) {
        sourceID = snippet?.id
        triggerText = snippet?.triggerText ?? ""
        expansionText = snippet?.expansionText ?? ""
        scope = snippet?.languageScope ?? .any
    }
}

struct SnippetsView: View {
    @ObservedObject var store: SnippetStore
    @State private var searchText = ""
    @State private var draft: SnippetDraft?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snippets").font(.largeTitle.bold())
                    Text("Replace a spoken phrase with exact saved text.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add snippet", systemImage: "plus") { draft = SnippetDraft() }
                    .buttonStyle(.borderedProminent)
            }

            if store.snippets.isEmpty {
                ContentUnavailableView(
                    "No snippets",
                    systemImage: "text.badge.plus",
                    description: Text("Add a trigger for an address, signature, link, or other text you use often.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredSnippets) { snippet in
                    HStack(spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { snippet.isEnabled },
                            set: { store.setEnabled(snippet, isEnabled: $0) }
                        ))
                        .labelsHidden()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(snippet.triggerText)
                                .font(.body.weight(.medium))
                            Text(snippet.expansionText)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text(snippet.languageScope.title)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button("Edit", systemImage: "pencil") { draft = SnippetDraft(snippet: snippet) }
                            .labelStyle(.iconOnly)
                        Button("Delete", systemImage: "trash", role: .destructive) { store.delete(snippet) }
                            .labelStyle(.iconOnly)
                    }
                    .padding(.vertical, 5)
                    .contextMenu {
                        Button("Edit") { draft = SnippetDraft(snippet: snippet) }
                        Button("Delete", role: .destructive) { store.delete(snippet) }
                    }
                }
                .searchable(text: $searchText, prompt: "Search snippets")
            }
        }
        .padding(24)
        .sheet(item: $draft) { draft in
            SnippetEditor(draft: draft) { saved in
                do {
                    try store.save(
                        id: saved.sourceID,
                        triggerText: saved.triggerText,
                        expansionText: saved.expansionText,
                        scope: saved.scope
                    )
                    self.draft = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .alert("Could not save snippet", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var filteredSnippets: [TextSnippet] {
        store.matching(searchText)
    }
}

private struct SnippetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: SnippetDraft
    let onSave: (SnippetDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(draft.sourceID == nil ? "Add snippet" : "Edit snippet")
                .font(.title2.bold())

            TextField("Spoken trigger", text: $draft.triggerText)

            VStack(alignment: .leading, spacing: 6) {
                Text("Inserted text")
                    .font(.callout.weight(.medium))
                TextEditor(text: $draft.expansionText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 150)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                Text("\(draft.expansionText.count) characters")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Picker("Language", selection: $draft.scope) {
                ForEach(LexiconLanguageScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }

            Text("OpenYap matches the trigger as a complete phrase inside new dictations. It inserts the saved text without rewriting it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(draft) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
