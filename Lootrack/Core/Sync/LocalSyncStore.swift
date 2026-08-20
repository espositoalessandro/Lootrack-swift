import Foundation
import SwiftData

nonisolated struct SyncMetadata:
    Codable,
    Equatable
{
    let revision: Int
    let lastMutationId: UUID?
}

nonisolated struct LocalSyncSnapshot {
    let transactions: [TransactionDTO]
    let categories: [CategoryDTO]
    let subcategories: [SubcategoryDTO]
    let metadata: [SyncEntityKey: SyncMetadata]
    let mutations: [MutationDTO]
}

nonisolated struct LocalSyncChanges {
    let remoteRecords: [RemoteSyncRecord]
    let mutationIdsToAcknowledge: [UUID]
}

nonisolated enum LocalSyncStoreError:
    Error
{
    case duplicateRemoteRecord(SyncEntityKey)

    case invalidRemoteUpsert(SyncEntityKey)

    case invalidRemoteDelete(SyncEntityKey)
}

@MainActor
final class LocalSyncStore {
    private let modelContext: ModelContext
    private let tagService: TagService

    init(modelContext: ModelContext,
         tagService: TagService)
    {
        self.modelContext =
            modelContext
        self.tagService =
            tagService
    }

    func getSnapshot() throws -> LocalSyncSnapshot {
        let transactions =
            try modelContext.fetch(FetchDescriptor<Transaction>())

        let categories =
            try modelContext.fetch(FetchDescriptor<Category>())

        let subcategories =
            try modelContext.fetch(FetchDescriptor<Subcategory>())

        let states =
            try modelContext.fetch(FetchDescriptor<EntitySyncState>())

        let mutations =
            try modelContext.fetch(MutationQueries
                .pendingByOldest)

        let metadata = Dictionary(uniqueKeysWithValues:
            states.map { state in
                (state.key,
                 SyncMetadata(revision:
                     state.revision,
                     lastMutationId:
                     state
                         .lastMutationId))
            })

        return LocalSyncSnapshot(transactions:
            transactions.map(TransactionDTO.init),
            categories:
            categories.map(CategoryDTO.init),
            subcategories:
            subcategories.map(SubcategoryDTO.init),
            metadata: metadata,
            mutations:
            mutations.map(MutationDTO.init))
    }

    func applyChanges(_ changes: LocalSyncChanges) throws {
        let mutations =
            try modelContext.fetch(MutationQueries
                .pendingByOldest)

        let mutationIdsToAcknowledge =
            Set(changes
                .mutationIdsToAcknowledge)

        let remainingMutations =
            mutations.filter {
                mutation in
                !mutationIdsToAcknowledge
                    .contains(mutation.id)
            }

        let pendingEntityKeys =
            Set(remainingMutations.map {
                mutation in
                mutation.payload.key
            })

        let remoteRecordsToApply =
            try buildApplyPlan(remoteRecords:
                changes
                    .remoteRecords,
                pendingEntityKeys:
                pendingEntityKeys)

        let transactions =
            try modelContext.fetch(FetchDescriptor<Transaction>())

        let categories =
            try modelContext.fetch(FetchDescriptor<Category>())

        let subcategories =
            try modelContext.fetch(FetchDescriptor<Subcategory>())

        let states =
            try modelContext.fetch(FetchDescriptor<EntitySyncState>())

        var transactionsById =
            Dictionary(uniqueKeysWithValues:
                transactions.map {
                    transaction in
                    (transaction.id,
                     transaction)
                })

        var categoriesById =
            Dictionary(uniqueKeysWithValues:
                categories.map {
                    category in
                    (category.id,
                     category)
                })

        var subcategoriesById =
            Dictionary(uniqueKeysWithValues:
                subcategories.map {
                    subcategory in
                    (subcategory.id,
                     subcategory)
                })

        var statesByKey =
            Dictionary(uniqueKeysWithValues:
                states.map { state in
                    (state.key,
                     state)
                })

        try modelContext.transaction {
            for mutation in mutations
                where
                mutationIdsToAcknowledge
                .contains(mutation.id)
            {
                modelContext.delete(mutation)
            }

            for record
                in remoteRecordsToApply
            {
                switch record.payload {
                case let .transaction(snapshot):
                    apply(snapshot,
                          transactionsById:
                          &transactionsById)

                case let .category(snapshot):
                    apply(snapshot,
                          categoriesById:
                          &categoriesById)

                case let .subcategory(snapshot):
                    apply(snapshot,
                          subcategoriesById:
                          &subcategoriesById)
                }

                applyMetadata(record,
                              statesByKey:
                              &statesByKey)
            }
        }

        if remoteRecordsToApply.contains(where: {
            $0.entityType == .transaction
        }) {
            tagService.rebuild()
        }
    }

    private func buildApplyPlan(remoteRecords:
        [RemoteSyncRecord],
        pendingEntityKeys:
        Set<SyncEntityKey>) throws -> [RemoteSyncRecord]
    {
        var foundRemoteRecords =
            Set<SyncEntityKey>()

        var recordsToApply: [RemoteSyncRecord] = []

        for record in remoteRecords {
            let key = record.id

            guard
                foundRemoteRecords
                .insert(key)
                .inserted
            else {
                throw
                    LocalSyncStoreError
                    .duplicateRemoteRecord(key)
            }

            try validate(record)

            guard
                !pendingEntityKeys
                .contains(key)
            else {
                continue
            }

            recordsToApply.append(record)
        }

        return recordsToApply
    }

    private func validate(_ record: RemoteSyncRecord) throws {
        let deletedAt: Date? = switch record.payload {
        case let .transaction(transaction):
            transaction.deletedAt

        case let .category(category):
            category.deletedAt

        case let .subcategory(subcategory):
            subcategory.deletedAt
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

    private func apply(_ snapshot: TransactionDTO,
                       transactionsById:
                       inout [UUID: Transaction])
    {
        if let transaction =
            transactionsById[snapshot.id]
        {
            transaction.apply(snapshot)
            return
        }

        let transaction =
            Transaction(snapshot)

        modelContext.insert(transaction)

        transactionsById[snapshot.id] = transaction
    }

    private func apply(_ snapshot: CategoryDTO,
                       categoriesById:
                       inout [UUID: Category])
    {
        if let category =
            categoriesById[snapshot.id]
        {
            category.apply(snapshot)
            return
        }

        let category =
            Category(snapshot)

        modelContext.insert(category)

        categoriesById[snapshot.id] = category
    }

    private func apply(_ snapshot: SubcategoryDTO,
                       subcategoriesById:
                       inout [UUID: Subcategory])
    {
        if let subcategory =
            subcategoriesById[snapshot.id]
        {
            subcategory.apply(snapshot)
            return
        }

        let subcategory =
            Subcategory(snapshot)

        modelContext.insert(subcategory)

        subcategoriesById[snapshot.id] = subcategory
    }

    private func applyMetadata(_ record: RemoteSyncRecord,
                               statesByKey:
                               inout [SyncEntityKey:
                                   EntitySyncState])
    {
        let key = record.id

        if let state =
            statesByKey[key]
        {
            state.revision =
                record.revision

            state.lastMutationId =
                record.mutationId

            return
        }

        let state =
            EntitySyncState(key: key,
                            lastMutationId:
                            record.mutationId,
                            revision:
                            record.revision)

        modelContext.insert(state)
        statesByKey[key] = state
    }
}
