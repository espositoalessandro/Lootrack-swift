import SwiftData
import Foundation

nonisolated struct SyncMetadata: Codable, Equatable {
    let revision: Int
    let lastMutationId: UUID?
}

nonisolated struct LocalSyncSnapshot {
    let transactions: [TransactionDTO]
    let categories: [CategoryDTO]
    let metadata: [SyncEntityKey: SyncMetadata]
    let mutations: [MutationDTO]
}

@MainActor
final class LocalSyncStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getSnapshot() throws -> LocalSyncSnapshot {
        let transactions = try modelContext.fetch(
            FetchDescriptor<Transaction>()
        )

        let categories = try modelContext.fetch(
            FetchDescriptor<Category>()
        )

        let states = try modelContext.fetch(
            FetchDescriptor<EntitySyncState>()
        )

        let mutations = try modelContext.fetch(
            MutationQueries.pendingByOldest
        )

        let metadata = Dictionary(
            uniqueKeysWithValues: states.map { state in
                (
                    state.key,
                    SyncMetadata(
                        revision: state.revision,
                        lastMutationId: state.lastMutationId
                    )
                )
            }
        )

        return LocalSyncSnapshot(
            transactions: transactions.map(TransactionDTO.init),
            categories: categories.map(CategoryDTO.init),
            metadata: metadata,
            mutations: mutations.map(MutationDTO.init)
        )
    }
}
