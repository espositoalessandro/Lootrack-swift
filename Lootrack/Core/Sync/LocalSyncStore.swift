import Foundation
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

nonisolated struct LocalSyncChanges {
    let remoteRecords: [RemoteSyncRecord]
    let mutationIdsToAcknowledge: [UUID]
}

nonisolated enum LocalSyncStoreError: Error {
    case duplicateRemoteRecord(SyncEntityKey)
    case invalidRemoteUpsert(SyncEntityKey)
    case invalidRemoteDelete(SyncEntityKey)
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

    func applyChanges(
        _ changes: LocalSyncChanges
    ) throws {
        let mutations = try modelContext.fetch(
            MutationQueries.pendingByOldest
        )

        let mutationIdsToAcknowledge = Set(
            changes.mutationIdsToAcknowledge
        )

        /*
         * Determine which mutations will still exist after
         * acknowledgement.
         *
         * This includes mutations created while the network
         * synchronization was in progress.
         */
        let remainingMutations = mutations.filter { mutation in
            !mutationIdsToAcknowledge.contains(mutation.id)
        }

        let pendingEntityKeys = Set(
            remainingMutations.map { mutation in
                mutation.payload.key
            }
        )

        /*
         * Validate the whole remote response before changing
         * persistent state.
         */
        let remoteRecordsToApply = try buildApplyPlan(
            remoteRecords: changes.remoteRecords,
            pendingEntityKeys: pendingEntityKeys
        )

        let transactions = try modelContext.fetch(
            FetchDescriptor<Transaction>()
        )

        let categories = try modelContext.fetch(
            FetchDescriptor<Category>()
        )

        let states = try modelContext.fetch(
            FetchDescriptor<EntitySyncState>()
        )

        var transactionsById = Dictionary(
            uniqueKeysWithValues: transactions.map { transaction in
                (transaction.id, transaction)
            }
        )

        var categoriesById = Dictionary(
            uniqueKeysWithValues: categories.map { category in
                (category.id, category)
            }
        )

        var statesByKey = Dictionary(
            uniqueKeysWithValues: states.map { state in
                (state.key, state)
            }
        )

        try modelContext.transaction {
            /*
             * Remove acknowledged mutations that still exist.
             */
            for mutation in mutations
            where mutationIdsToAcknowledge.contains(mutation.id) {
                modelContext.delete(mutation)
            }

            /*
             * Apply authoritative remote state.
             */
            for record in remoteRecordsToApply {
                switch record.payload {
                case .transaction(let snapshot):
                    apply(
                        snapshot,
                        transactionsById: &transactionsById
                    )

                case .category(let snapshot):
                    apply(
                        snapshot,
                        categoriesById: &categoriesById
                    )
                }

                applyMetadata(
                    record,
                    statesByKey: &statesByKey
                )
            }
        }
    }

    private func buildApplyPlan(
        remoteRecords: [RemoteSyncRecord],
        pendingEntityKeys: Set<SyncEntityKey>
    ) throws -> [RemoteSyncRecord] {
        var foundRemoteRecords = Set<SyncEntityKey>()
        var recordsToApply: [RemoteSyncRecord] = []

        for record in remoteRecords {
            let key = record.id

            guard foundRemoteRecords.insert(key).inserted else {
                throw
                    LocalSyncStoreError
                    .duplicateRemoteRecord(key)
            }

            try validate(record)

            /*
             * A newer local mutation exists for this entity.
             *
             * Applying this remote record would overwrite newer
             * local state with an older synchronization result.
             */
            guard !pendingEntityKeys.contains(key) else {
                continue
            }

            recordsToApply.append(record)
        }

        return recordsToApply
    }

    private func validate(
        _ record: RemoteSyncRecord
    ) throws {
        let deletedAt: Date?

        switch record.payload {
        case .transaction(let transaction):
            deletedAt = transaction.deletedAt

        case .category(let category):
            deletedAt = category.deletedAt
        }

        switch record.operation {
        case .upsert:
            guard deletedAt == nil else {
                throw
                    LocalSyncStoreError
                    .invalidRemoteUpsert(record.id)
            }

        case .delete:
            guard deletedAt != nil else {
                throw
                    LocalSyncStoreError
                    .invalidRemoteDelete(record.id)
            }
        }
    }

    private func apply(
        _ snapshot: TransactionDTO,
        transactionsById: inout [UUID: Transaction]
    ) {
        if let transaction = transactionsById[snapshot.id] {
            transaction.createdAt = snapshot.createdAt
            transaction.updatedAt = snapshot.updatedAt
            transaction.deletedAt = snapshot.deletedAt

            transaction.type = snapshot.type
            transaction.amountInCents = snapshot.amountInCents
            transaction.note = snapshot.note
            transaction.occurredOn = snapshot.occurredOn
            transaction.categoryId = snapshot.categoryId

            return
        }

        let transaction = Transaction(
            id: snapshot.id,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt,
            deletedAt: snapshot.deletedAt,
            type: snapshot.type,
            amountInCents: snapshot.amountInCents,
            note: snapshot.note,
            occurredOn: snapshot.occurredOn,
            categoryId: snapshot.categoryId
        )

        modelContext.insert(transaction)
        transactionsById[snapshot.id] = transaction
    }

    private func apply(
        _ snapshot: CategoryDTO,
        categoriesById: inout [UUID: Category]
    ) {
        if let category = categoriesById[snapshot.id] {
            category.createdAt = snapshot.createdAt
            category.updatedAt = snapshot.updatedAt
            category.deletedAt = snapshot.deletedAt
            category.type = snapshot.type
            category.name = snapshot.name
            category.note = snapshot.note

            return
        }

        let category = Category(
            id: snapshot.id,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt,
            deletedAt: snapshot.deletedAt,
            type: snapshot.type,
            name: snapshot.name,
            note: snapshot.note
        )

        modelContext.insert(category)

        categoriesById[snapshot.id] =
            category
    }
    private func applyMetadata(
        _ record: RemoteSyncRecord,
        statesByKey: inout [SyncEntityKey: EntitySyncState]
    ) {
        let key = record.id

        if let state = statesByKey[key] {
            state.revision = record.revision
            state.lastMutationId = record.mutationId

            return
        }

        let state = EntitySyncState(
            key: key,
            lastMutationId: record.mutationId,
            revision: record.revision
        )

        modelContext.insert(state)
        statesByKey[key] = state
    }
}
