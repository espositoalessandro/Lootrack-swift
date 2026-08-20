internal import os
import Observation
import SwiftData

@MainActor
@Observable
final class TagService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /**
     * Tag is a local-only derived vocabulary.
     * Transactions are always authoritative.
     */
    func rebuild() {
        do {
            let transactions = try modelContext.fetch(TransactionQueries.active)
            let desiredNames = Set(transactions.flatMap(\.tags).flatMap {
                Tag.normalizedTokens(from: $0)
            })
            
            let existingTags = try modelContext.fetch(TagQueries.byName)
            let existingNames = Set(existingTags.map(\.name))
            
            try modelContext.transaction {
                for tag in existingTags where !desiredNames.contains(tag.name) {
                    modelContext.delete(tag)
                }
                
                for name in desiredNames where !existingNames.contains(name) {
                    modelContext.insert(Tag(name))
                }
            }
        } catch {
            /*
             * A cache failure must never make an
             * authoritative transaction operation fail.
             */
            modelContext.rollback()
            
            let errorDescription = String(describing: error)
            AppLogger.persistence.error("Failed to rebuild tag cache: \(errorDescription, privacy: .public)")
        }
    }
}
