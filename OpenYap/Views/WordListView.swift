import SwiftUI

private enum WordListSection: String, CaseIterable, Identifiable {
    case terms
    case corrections

    var id: String { rawValue }
    var title: String { self == .terms ? "Terms" : "Corrections" }
}

private struct TermDraft: Identifiable {
    let id = UUID()
    let sourceID: UUID?
    var text: String
    var scope: LexiconLanguageScope

    init(term: LexiconTerm? = nil) {
        sourceID = term?.id
        text = term?.canonicalText ?? ""
        scope = term?.languageScope ?? .any
    }
}

private struct RuleDraft: Identifiable {
    let id = UUID()
    let sourceID: UUID?
    var recognizedText: String
    var replacementText: String
    var scope: LexiconLanguageScope

    init(rule: CorrectionRule? = nil) {
        sourceID = rule?.id
        recognizedText = rule?.recognizedText ?? ""
        replacementText = rule?.replacementText ?? ""
        scope = rule?.languageScope ?? .any
    }
}

struct WordListView: View {
    @ObservedObject var store: LexiconStore
    @State private var selectedSection: WordListSection = .terms
    @State private var termDraft: TermDraft?
    @State private var ruleDraft: RuleDraft?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Word List").font(.largeTitle.bold())
                    Text("Fix spellings and phrases before OpenYap pastes them.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add \(selectedSection == .terms ? "term" : "correction")", systemImage: "plus") {
                    if selectedSection == .terms { termDraft = TermDraft() }
                    else { ruleDraft = RuleDraft() }
                }
                .buttonStyle(.borderedProminent)
            }

            Picker("Word list section", selection: $selectedSection) {
                ForEach(WordListSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            Group {
                if selectedSection == .terms { termsList }
                else { correctionsList }
            }
        }
        .padding(24)
        .sheet(item: $termDraft) { draft in
            TermEditor(draft: draft) { saved in
                do {
                    try store.saveTerm(id: saved.sourceID, canonicalText: saved.text, scope: saved.scope)
                    termDraft = nil
                } catch { errorMessage = error.localizedDescription }
            }
        }
        .sheet(item: $ruleDraft) { draft in
            RuleEditor(draft: draft) { saved in
                do {
                    try store.saveRule(
                        id: saved.sourceID,
                        recognizedText: saved.recognizedText,
                        replacementText: saved.replacementText,
                        scope: saved.scope
                    )
                    ruleDraft = nil
                } catch { errorMessage = error.localizedDescription }
            }
        }
        .alert("Could not save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var termsList: some View {
        Group {
            if store.terms.isEmpty {
                ContentUnavailableView(
                    "No vocabulary terms",
                    systemImage: "character.book.closed",
                    description: Text("Add names, products, and acronyms with their preferred spelling.")
                )
            } else {
                List(store.terms) { term in
                    HStack(spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { term.isEnabled },
                            set: { store.setEnabled(term: term, isEnabled: $0) }
                        ))
                        .labelsHidden()
                        VStack(alignment: .leading, spacing: 3) {
                            Text(term.canonicalText).font(.body.weight(.medium))
                            Text(term.languageScope.title).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit", systemImage: "pencil") { termDraft = TermDraft(term: term) }
                            .labelStyle(.iconOnly)
                        Button("Delete", systemImage: "trash", role: .destructive) { store.delete(term) }
                            .labelStyle(.iconOnly)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var correctionsList: some View {
        Group {
            if store.rules.isEmpty {
                ContentUnavailableView(
                    "No correction rules",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("Add a phrase OpenYap hears and the exact text it should use.")
                )
            } else {
                List(store.rules) { rule in
                    HStack(spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { rule.isEnabled },
                            set: { store.setEnabled(rule: rule, isEnabled: $0) }
                        ))
                        .labelsHidden()
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(rule.recognizedText)
                                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                                Text(rule.replacementText).fontWeight(.medium)
                            }
                            Text(rule.languageScope.title).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit", systemImage: "pencil") { ruleDraft = RuleDraft(rule: rule) }
                            .labelStyle(.iconOnly)
                        Button("Delete", systemImage: "trash", role: .destructive) { store.delete(rule) }
                            .labelStyle(.iconOnly)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct TermEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: TermDraft
    let onSave: (TermDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(draft.sourceID == nil ? "Add vocabulary term" : "Edit vocabulary term")
                .font(.title2.bold())
            TextField("Preferred spelling", text: $draft.text)
            languagePicker(selection: $draft.scope)
            Text("Terms normalize matching spelling and capitalization. Use a correction rule for a phrase Apple hears differently.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(draft) }.buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 430)
    }
}

private struct RuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: RuleDraft
    let onSave: (RuleDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(draft.sourceID == nil ? "Add correction" : "Edit correction")
                .font(.title2.bold())
            TextField("OpenYap hears", text: $draft.recognizedText)
            TextField("Replace with", text: $draft.replacementText)
            languagePicker(selection: $draft.scope)
            Text("Corrections match whole words or phrases, ignoring capitalization. They affect new dictations only.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(draft) }.buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 430)
    }
}

@ViewBuilder
private func languagePicker(selection: Binding<LexiconLanguageScope>) -> some View {
    Picker("Language", selection: selection) {
        ForEach(LexiconLanguageScope.allCases) { scope in
            Text(scope.title).tag(scope)
        }
    }
}
