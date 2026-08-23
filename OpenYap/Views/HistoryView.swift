import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var history: HistoryStore
    @State private var selectedID: UUID?
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("History").font(.largeTitle.bold())
            CaptureCard(model: model)

            if history.entries.isEmpty {
                ContentUnavailableView(
                    "No transcriptions yet",
                    systemImage: "text.bubble",
                    description: Text("Completed dictations with useful text will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    historyList
                        .frame(minWidth: 240, idealWidth: 290, maxWidth: 360)
                    if let entry = selectedEntry {
                        HistoryDetailView(entry: entry, history: history)
                            .id(entry.sessionID)
                            .frame(minWidth: 440)
                    } else {
                        ContentUnavailableView("Select a transcription", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(20)
        .onAppear { selectFirstIfNeeded() }
        .onChange(of: history.entries.map(\.sessionID)) { _, _ in selectFirstIfNeeded() }
    }

    private var historyList: some View {
        List(selection: $selectedID) {
            ForEach(groupedEntries, id: \.day) { group in
                Section(group.day.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(group.entries) { entry in
                        HistoryRow(entry: entry)
                            .tag(entry.sessionID)
                            .contextMenu {
                                Button("Delete", role: .destructive) { history.delete(entry) }
                            }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search history")
    }

    private var filteredEntries: [HistoryEntry] {
        guard !searchText.isEmpty else { return history.entries }
        return history.entries.filter {
            $0.currentText.localizedCaseInsensitiveContains(searchText) ||
            $0.rawText.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedEntries: [(day: Date, entries: [HistoryEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEntries) { calendar.startOfDay(for: $0.endedAt) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    private var selectedEntry: HistoryEntry? {
        guard let selectedID else { return nil }
        return history.entry(for: selectedID)
    }

    private func selectFirstIfNeeded() {
        if let selectedID, history.entry(for: selectedID) != nil { return }
        selectedID = filteredEntries.first?.sessionID
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.currentText)
                .font(.callout)
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(entry.endedAt.formatted(date: .omitted, time: .shortened))
                Text("·")
                Text(Locale(identifier: entry.localeIdentifier).language.languageCode?.identifier.uppercased() ?? entry.localeIdentifier)
                if entry.isPartial {
                    Text("Partial").foregroundStyle(.orange)
                }
                Spacer()
                Image(systemName: entry.deliveryOutcome == .delivered ? "checkmark.circle.fill" : "doc.on.clipboard")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

private struct HistoryDetailView: View {
    let entry: HistoryEntry
    @ObservedObject var history: HistoryStore
    @State private var editedText: String
    @State private var confirmDelete = false

    init(entry: HistoryEntry, history: HistoryStore) {
        self.entry = entry
        self.history = history
        _editedText = State(initialValue: entry.currentText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.endedAt.formatted(date: .long, time: .shortened))
                            .font(.title3.bold())
                        Text("\(entry.deliveryOutcome.title) · \(entry.formattingMode.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        .labelStyle(.iconOnly)
                    Button("Copy", systemImage: "doc.on.doc") { copyCurrentText() }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current text").font(.headline)
                    TextEditor(text: $editedText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 150)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                    HStack {
                        Text("Edits save automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Revert to initial text") { editedText = entry.initialDeliveryText }
                            .disabled(editedText == entry.initialDeliveryText)
                    }
                }

                MetricsView(entry: entry, currentText: editedText)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Changes").font(.headline)
                    TranscriptDiffView(title: "Smart cleanup", oldText: entry.rawText, newText: entry.formattedText)
                    TranscriptDiffView(title: "Word list", oldText: entry.formattedText, newText: wordListText)
                    TranscriptDiffView(title: "Snippets", oldText: wordListText, newText: entry.initialDeliveryText)
                    if !entry.appliedReplacements.isEmpty {
                        ForEach(entry.appliedReplacements) { replacement in
                            Label(
                                "\(replacement.recognizedText) → \(replacement.replacementText) ×\(replacement.occurrenceCount)",
                                systemImage: replacementIcon(replacement.kind)
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    TranscriptDiffView(title: "Manual edit", oldText: entry.initialDeliveryText, newText: editedText)
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
        }
        .task(id: editedText) {
            do {
                try await Task.sleep(for: .milliseconds(500))
                history.updateCurrentText(entryID: entry.sessionID, text: editedText)
            } catch {}
        }
        .onDisappear { history.updateCurrentText(entryID: entry.sessionID, text: editedText) }
        .alert("Delete this transcription?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { history.delete(entry) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the raw transcript and edited text from this Mac.")
        }
    }

    private func copyCurrentText() {
        history.updateCurrentText(entryID: entry.sessionID, text: editedText)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(editedText, forType: .string)
    }

    private var wordListText: String {
        entry.effectiveWordListText
    }

    private func replacementIcon(_ kind: ReplacementKind) -> String {
        switch kind {
        case .term: "textformat"
        case .correction: "arrow.left.arrow.right"
        case .snippet: "text.badge.plus"
        }
    }
}

private struct MetricsView: View {
    let entry: HistoryEntry
    let currentText: String

    var body: some View {
        let locale = Locale(identifier: entry.localeIdentifier)
        let raw = TranscriptMetrics.measure(entry.rawText, locale: locale)
        let current = TranscriptMetrics.measure(currentText, locale: locale)
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
            GridRow {
                metric("Words", value: "\(raw.wordCount) → \(current.wordCount)", delta: current.wordCount - raw.wordCount)
                metric("Characters", value: "\(raw.characterCount) → \(current.characterCount)", delta: current.characterCount - raw.characterCount)
            }
            GridRow {
                metric("Duration", value: durationText, delta: nil)
                metric("Speaking rate", value: wordsPerMinuteText, delta: nil)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }

    private func metric(_ title: String, value: String, delta: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 5) {
                Text(value).font(.callout.monospacedDigit())
                if let delta, delta != 0 {
                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var durationText: String {
        Duration.seconds(entry.captureDuration).formatted(.time(pattern: .minuteSecond))
    }

    private var wordsPerMinuteText: String {
        guard entry.captureDuration > 0 else { return "—" }
        let rawWords = TranscriptMetrics.measure(entry.rawText, locale: Locale(identifier: entry.localeIdentifier)).wordCount
        return "\(Int((Double(rawWords) * 60 / entry.captureDuration).rounded())) WPM"
    }
}

private struct TranscriptDiffView: View {
    let title: String
    let oldText: String
    let newText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if oldText == newText {
                Text("No changes")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text(attributedDiff)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 9))
    }

    private var attributedDiff: AttributedString {
        var output = AttributedString()
        for token in TranscriptDiff.tokens(from: oldText, to: newText) {
            var part = AttributedString(token.text)
            switch token.kind {
            case .unchanged:
                break
            case .removed:
                part.foregroundColor = .red
                part.strikethroughStyle = .single
                part.backgroundColor = .red.opacity(0.1)
            case .inserted:
                part.foregroundColor = .green
                part.backgroundColor = .green.opacity(0.12)
            }
            output.append(part)
        }
        return output
    }
}
