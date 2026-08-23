import Foundation

struct TranscriptMetrics: Equatable, Sendable {
    let wordCount: Int
    let characterCount: Int

    static func measure(_ text: String, locale: Locale) -> TranscriptMetrics {
        let pattern = "[\\p{L}\\p{N}]+(?:['’][\\p{L}\\p{N}]+)*"
        let expression = try? NSRegularExpression(pattern: pattern)
        let wordCount = expression?.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) ?? 0
        return TranscriptMetrics(wordCount: wordCount, characterCount: text.count)
    }
}

enum TranscriptDiffKind: Sendable {
    case unchanged
    case removed
    case inserted
}

struct TranscriptDiffToken: Sendable {
    let text: String
    let kind: TranscriptDiffKind
}

enum TranscriptDiff {
    static func tokens(from oldText: String, to newText: String) -> [TranscriptDiffToken] {
        let oldTokens = tokenize(oldText)
        let newTokens = tokenize(newText)
        let oldCount = oldTokens.count
        let newCount = newTokens.count
        var lengths = Array(
            repeating: Array(repeating: 0, count: newCount + 1),
            count: oldCount + 1
        )

        if oldCount > 0, newCount > 0 {
            for oldIndex in stride(from: oldCount - 1, through: 0, by: -1) {
                for newIndex in stride(from: newCount - 1, through: 0, by: -1) {
                    if oldTokens[oldIndex] == newTokens[newIndex] {
                        lengths[oldIndex][newIndex] = lengths[oldIndex + 1][newIndex + 1] + 1
                    } else {
                        lengths[oldIndex][newIndex] = max(
                            lengths[oldIndex + 1][newIndex],
                            lengths[oldIndex][newIndex + 1]
                        )
                    }
                }
            }
        }

        var result: [TranscriptDiffToken] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < oldCount || newIndex < newCount {
            if oldIndex < oldCount,
               newIndex < newCount,
               oldTokens[oldIndex] == newTokens[newIndex] {
                result.append(.init(text: oldTokens[oldIndex], kind: .unchanged))
                oldIndex += 1
                newIndex += 1
            } else if newIndex < newCount,
                      oldIndex == oldCount || lengths[oldIndex][newIndex + 1] > lengths[oldIndex + 1][newIndex] {
                result.append(.init(text: newTokens[newIndex], kind: .inserted))
                newIndex += 1
            } else if oldIndex < oldCount {
                result.append(.init(text: oldTokens[oldIndex], kind: .removed))
                oldIndex += 1
            }
        }
        return result
    }

    private static func tokenize(_ text: String) -> [String] {
        let pattern = "[\\p{L}\\p{N}'’]+|\\s+|[^\\p{L}\\p{N}'’\\s]+"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [text] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}

enum TranscriptChangeMetrics {
    static func wordEditCount(from oldText: String, to newText: String) -> Int {
        let oldWords = words(in: oldText)
        let newWords = words(in: newText)
        var distances = Array(repeating: Array(repeating: 0, count: newWords.count + 1), count: oldWords.count + 1)

        for index in 0...oldWords.count { distances[index][0] = index }
        for index in 0...newWords.count { distances[0][index] = index }
        guard !oldWords.isEmpty, !newWords.isEmpty else { return max(oldWords.count, newWords.count) }

        for oldIndex in 1...oldWords.count {
            for newIndex in 1...newWords.count {
                let substitution = distances[oldIndex - 1][newIndex - 1]
                    + (oldWords[oldIndex - 1] == newWords[newIndex - 1] ? 0 : 1)
                distances[oldIndex][newIndex] = min(
                    min(
                        distances[oldIndex - 1][newIndex] + 1,
                        distances[oldIndex][newIndex - 1] + 1
                    ),
                    substitution
                )
            }
        }
        return distances[oldWords.count][newWords.count]
    }

    private static func words(in text: String) -> [String] {
        let pattern = "[\\p{L}\\p{N}]+(?:['’][\\p{L}\\p{N}]+)*"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return text[range].lowercased()
        }
    }
}
