import SwiftData

nonisolated struct LocalSyncSnapshot {
    let transactions: [TransactionDTO]
    let categories: [CategoryDTO]
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
