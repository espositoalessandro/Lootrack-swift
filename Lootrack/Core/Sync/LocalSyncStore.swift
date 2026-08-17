import SwiftData

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
    
    func getSnapshot() throws -> LocalSyncSnapshot

    func applyChanges(
        _ changes: LocalSyncChanges
    ) throws
}
