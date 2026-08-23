import Foundation

struct TranscriptPreparationResult: Sendable {
    let formattedText: String
    let wordListText: String
    let initialDeliveryText: String
    let formattingMode: TranscriptFormattingMode
    let appliedReplacements: [AppliedReplacementSnapshot]

    init(
        formattedText: String,
        wordListText: String? = nil,
        initialDeliveryText: String,
        formattingMode: TranscriptFormattingMode,
        appliedReplacements: [AppliedReplacementSnapshot]
    ) {
        self.formattedText = formattedText
        self.wordListText = wordListText ?? initialDeliveryText
        self.initialDeliveryText = initialDeliveryText
        self.formattingMode = formattingMode
        self.appliedReplacements = appliedReplacements
    }
}

actor TranscriptPreparationPipeline {
    private let formatter = AppleTranscriptFormatter()

    func prepare(
        rawTranscript: String,
        locale: Locale,
        smartFormattingEnabled: Bool,
        terms: [LexiconTermDefinition],
        rules: [CorrectionRuleDefinition],
        snippets: [SnippetDefinition]
    ) async -> TranscriptPreparationResult {
        let formatted: PreparedTranscript
        if smartFormattingEnabled {
            formatted = await formatter.prepare(rawTranscript, locale: locale)
        } else {
            formatted = PreparedTranscript(text: rawTranscript, usedLanguageModel: false)
        }

        let replacementResult = LexiconProcessor.apply(
            to: formatted.text,
            locale: locale,
            terms: terms,
            rules: rules
        )
        let snippetResult = SnippetProcessor.apply(
            to: replacementResult.text,
            locale: locale,
            snippets: snippets
        )
        let mode: TranscriptFormattingMode
        if !smartFormattingEnabled {
            mode = .raw
        } else if formatted.usedLanguageModel {
            mode = .languageModel
        } else {
            mode = .deterministic
        }

        return TranscriptPreparationResult(
            formattedText: formatted.text,
            wordListText: replacementResult.text,
            initialDeliveryText: snippetResult.text,
            formattingMode: mode,
            appliedReplacements: replacementResult.replacements + snippetResult.replacements
        )
    }
}

enum SnippetProcessor {
    private struct Match {
        let definition: SnippetDefinition
        let range: NSRange
    }

    static func apply(
        to input: String,
        locale: Locale,
        snippets: [SnippetDefinition]
    ) -> LexiconProcessingResult {
        let candidates = snippets.filter { $0.languageScope.matches(locale) }
        let fullRange = NSRange(input.startIndex..., in: input)
        var matches: [Match] = []

        for snippet in candidates {
            let escaped = NSRegularExpression.escapedPattern(for: snippet.triggerText)
            let pattern = "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"
            guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            matches += expression.matches(in: input, range: fullRange).map {
                Match(definition: snippet, range: $0.range)
            }
        }

        matches.sort {
            if $0.range.length != $1.range.length { return $0.range.length > $1.range.length }
            if $0.range.location != $1.range.location { return $0.range.location < $1.range.location }
            return $0.definition.id.uuidString < $1.definition.id.uuidString
        }

        var accepted: [Match] = []
        for match in matches where !accepted.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) {
            accepted.append(match)
        }

        var output = input
        for match in accepted.sorted(by: { $0.range.location > $1.range.location }) {
            guard let range = Range(match.range, in: output) else { continue }
            output.replaceSubrange(range, with: match.definition.expansionText)
        }

        let grouped = Dictionary(grouping: accepted, by: { $0.definition.id })
        let replacements = grouped.values.compactMap { group -> AppliedReplacementSnapshot? in
            guard let first = group.first else { return nil }
            return AppliedReplacementSnapshot(
                sourceID: first.definition.id,
                kind: .snippet,
                recognizedText: first.definition.triggerText,
                replacementText: first.definition.expansionText,
                occurrenceCount: group.count
            )
        }.sorted { $0.recognizedText.localizedCaseInsensitiveCompare($1.recognizedText) == .orderedAscending }

        return LexiconProcessingResult(text: output, replacements: replacements)
    }
}

struct LexiconProcessingResult: Sendable, Equatable {
    let text: String
    let replacements: [AppliedReplacementSnapshot]
}

enum LexiconProcessor {
    private struct Candidate {
        let id: UUID
        let kind: ReplacementKind
        let recognized: String
        let replacement: String
    }

    static func apply(
        to input: String,
        locale: Locale,
        terms: [LexiconTermDefinition],
        rules: [CorrectionRuleDefinition]
    ) -> LexiconProcessingResult {
        let termCandidates = terms
            .filter { $0.languageScope.matches(locale) }
            .map {
                Candidate(
                    id: $0.id,
                    kind: .term,
                    recognized: $0.canonicalText,
                    replacement: $0.canonicalText
                )
            }
        let ruleCandidates = rules
            .filter { $0.languageScope.matches(locale) }
            .map {
                Candidate(
                    id: $0.id,
                    kind: .correction,
                    recognized: $0.recognizedText,
                    replacement: $0.replacementText
                )
            }
        let candidates = (termCandidates + ruleCandidates).sorted {
            if $0.recognized.count == $1.recognized.count {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.recognized.count > $1.recognized.count
        }

        var output = input
        var applied: [AppliedReplacementSnapshot] = []
        for candidate in candidates {
            let escaped = NSRegularExpression.escapedPattern(for: candidate.recognized)
            let pattern = "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"
            guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let matches = expression.matches(
                in: output,
                range: NSRange(output.startIndex..., in: output)
            )
            guard !matches.isEmpty else { continue }

            var changedCount = 0
            for match in matches.reversed() {
                guard let range = Range(match.range, in: output) else { continue }
                let matchedText = String(output[range])
                guard matchedText != candidate.replacement else { continue }
                output.replaceSubrange(range, with: candidate.replacement)
                changedCount += 1
            }
            if changedCount > 0 {
                applied.append(
                    AppliedReplacementSnapshot(
                        sourceID: candidate.id,
                        kind: candidate.kind,
                        recognizedText: candidate.recognized,
                        replacementText: candidate.replacement,
                        occurrenceCount: changedCount
                    )
                )
            }
        }
        return LexiconProcessingResult(text: output, replacements: applied)
    }
}
