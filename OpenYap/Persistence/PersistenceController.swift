import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared: PersistenceController = {
        do {
            return try PersistenceController()
        } catch {
            fatalError("OpenYap could not open its local database: \(error.localizedDescription)")
        }
    }()

    let container: ModelContainer

    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(
            for: HistoryEntry.self,
            AppliedReplacement.self,
            LexiconTerm.self,
            CorrectionRule.self,
            TextSnippet.self,
            UsageDay.self,
            UsageAppDay.self,
            UsageReceipt.self,
            configurations: configuration
        )
    }
}
