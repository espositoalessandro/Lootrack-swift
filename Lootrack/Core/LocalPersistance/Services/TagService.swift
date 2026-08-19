import Observation
import SwiftData

@MainActor
@Observable
final class TagService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /*
     * Tag is a local-only derived vocabulary.
     * Transactions are always authoritative.
     */
    func rebuild() {
        do {
            let transactions = try modelContext.fetch(
                TransactionQueries.active
            )

            let desiredNames = Set(
                transactions
                    .flatMap(\.tags)
                    .flatMap {
                        Tag.normalizedTokens(
                            from: $0
                        )
                    }
            )

            let existingTags = try modelContext.fetch(
                TagQueries.byName
            )

            let existingNames = Set(
                existingTags.map(\.name)
            )

            for tag in existingTags
            where !desiredNames.contains(tag.name) {
                modelContext.delete(tag)
            }

            for name in desiredNames
            where !existingNames.contains(name) {
                modelContext.insert(
                    Tag(name)
                )
            }

            try modelContext.save()
        } catch {
            /*
             * A cache failure must never make an
             * authoritative transaction operation fail.
             */
            print(
                "FAILED TO REBUILD TAG CACHE:",
                error
            )
        }
    }
}
