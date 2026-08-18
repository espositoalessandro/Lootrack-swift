import Foundation
import SwiftData

nonisolated enum SyncConflictReason: String, Codable {
    case diverged
    case remoteMissing = "remote-missing"
    case invalidLocalChain = "invalid-local-chain"
}

nonisolated struct SyncConflictCandidate: Identifiable {
    let key: SyncEntityKey
    let reason: SyncConflictReason

    let base: EntitySnapshot?
    let local: EntitySnapshot
    let remote: RemoteSyncRecord?

    let pendingMutations: [MutationDTO]

    var id: SyncEntityKey {
        key
    }
}

nonisolated struct SyncReconciliationPlan {
    let remoteRecordsToApply: [RemoteSyncRecord]
    let mutationsToPush: [MutationDTO]
    let mutationIdsToAcknowledge: [UUID]
    let conflicts: [SyncConflictCandidate]
}

nonisolated struct RemoteSyncRecord: Codable, Equatable, Identifiable {
    let operation: SyncOperation

    let revision: Int
    let mutationId: UUID

    let payload: EntitySnapshot

    var id: SyncEntityKey {
        payload.key
    }

    var entityId: UUID {
        payload.id
    }

    var entityType: SyncEntityType {
        payload.type
    }
}

nonisolated enum ConflictResolution {
    case keepLocal
    case keepRemote
}

nonisolated enum ConflictResolutionError: Error {
    case localEntityMissing(SyncEntityKey)
}

@MainActor
final class ConflictResolutionService {
    private let modelContext: ModelContext
    private let mutationService: MutationService

    init(
        modelContext: ModelContext,
        mutationService: MutationService
    ) {
        self.modelContext = modelContext
        self.mutationService = mutationService
    }

    func resolve(
        _ conflict: SyncConflictCandidate,
        using resolution: ConflictResolution
    ) throws {
        try modelContext.transaction {
            /*
             * Read the entity NOW rather than using conflict.local.
             *
             * The user may have changed the entity after the sync attempt
             * produced the conflict.
             *
             * This mirrors the Angular implementation.
             */
            let currentLocal = try currentLocalSnapshot(
                for: conflict.key
            )

            /*
             * Whatever resolution we choose, the old mutation chain
             * can no longer be used.
             */
            try removePendingMutations(
                for: conflict.key
            )

            switch resolution {
            case .keepRemote:
                try keepRemote(conflict)

            case .keepLocal:
                try keepLocal(
                    conflict,
                    currentLocal: currentLocal
                )
            }
        }
    }

    // MARK: - Resolution

    private func keepRemote(
        _ conflict: SyncConflictCandidate
    ) throws {
        /*
         * The entity no longer exists remotely.
         *
         * "Keep remote" therefore means removing it locally too,
         * including its obsolete synchronization metadata.
         */
        guard let remote = conflict.remote else {
            try deleteLocalEntity(
                for: conflict.key
            )

            try deleteSyncState(
                for: conflict.key
            )

            return
        }

        /*
         * Replace local state with the authoritative remote state.
         */
        try put(remote.payload)

        /*
         * The local synchronization metadata must now describe
         * exactly the remote version we just accepted.
         */
        try setSyncState(
            for: conflict.key,
            revision: remote.revision,
            lastMutationId: remote.mutationId
        )
    }

    private func keepLocal(
        _ conflict: SyncConflictCandidate,
        currentLocal: EntitySnapshot?
    ) throws {
        guard let currentLocal else {
            throw ConflictResolutionError.localEntityMissing(
                conflict.key
            )
        }

        /*
         * Rebase local state on top of the current remote version.
         *
         * MutationService determines expectedRevision /
         * expectedMutationId from EntitySyncState, so first restore
         * that state to the actual remote version.
         */
        if let remote = conflict.remote {
            try setSyncState(
                for: conflict.key,
                revision: remote.revision,
                lastMutationId: remote.mutationId
            )
        } else {
            /*
             * There is no remote entity.
             *
             * The rebased local mutation must therefore behave like
             * a mutation created from scratch.
             */
            try deleteSyncState(
                for: conflict.key
            )
        }

        let operation = operation(
            for: currentLocal
        )

        /*
         * Create ONE new mutation:
         *
         * current remote state -> current local state
         *
         * The whole stale mutation chain was removed above.
         */
        try mutationService.createMutation(
            from: conflict.remote?.payload,
            to: currentLocal,
            operation
        )
    }

    // MARK: - Mutations

    private func removePendingMutations(
        for key: SyncEntityKey
    ) throws {
        let mutations = try modelContext.fetch(
            MutationQueries.pendingByOldest
        )

        for mutation in mutations
        where mutation.payload.key == key {
            modelContext.delete(mutation)
        }
    }

    // MARK: - Current local entity

    private func currentLocalSnapshot(
        for key: SyncEntityKey
    ) throws -> EntitySnapshot? {
        switch key.type {
        case .transaction:
            let id = key.id

            let transaction = try modelContext.fetch(
                FetchDescriptor<Transaction>(
                    predicate: #Predicate<Transaction> { transaction in
                        transaction.id == id
                    }
                )
            ).first

            return transaction.map {
                .transaction(
                    TransactionDTO($0)
                )
            }

        case .category:
            let id = key.id

            let category = try modelContext.fetch(
                FetchDescriptor<Category>(
                    predicate: #Predicate<Category> { category in
                        category.id == id
                    }
                )
            ).first

            return category.map {
                .category(
                    CategoryDTO($0)
                )
            }
        }
    }

    // MARK: - Local entity writes

    private func put(
        _ snapshot: EntitySnapshot
    ) throws {
        switch snapshot {
        case .transaction(let dto):
            try put(dto)

        case .category(let dto):
            try put(dto)
        }
    }

    private func put(
        _ snapshot: TransactionDTO
    ) throws {
        let id = snapshot.id

        let existing = try modelContext.fetch(
            FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { transaction in
                    transaction.id == id
                }
            )
        ).first

        if let existing {
            existing.createdAt = snapshot.createdAt
            existing.updatedAt = snapshot.updatedAt
            existing.deletedAt = snapshot.deletedAt

            existing.type = snapshot.type
            existing.amountInCents = snapshot.amountInCents
            existing.note = snapshot.note
            existing.occurredOn = snapshot.occurredOn
            existing.categoryId = snapshot.categoryId

            return
        }

        modelContext.insert(
            Transaction(
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
        )
    }

    private func put(
        _ snapshot: CategoryDTO
    ) throws {
        let id = snapshot.id

        let existing = try modelContext.fetch(
            FetchDescriptor<Category>(
                predicate:
                    #Predicate<Category> { category in
                        category.id == id
                    }
            )
        ).first

        if let existing {
            existing.createdAt = snapshot.createdAt
            existing.updatedAt = snapshot.updatedAt
            existing.deletedAt = snapshot.deletedAt
            existing.type = snapshot.type
            existing.name = snapshot.name
            existing.note = snapshot.note

            return
        }

        modelContext.insert(
            Category(
                id: snapshot.id,
                createdAt: snapshot.createdAt,
                updatedAt: snapshot.updatedAt,
                deletedAt: snapshot.deletedAt,
                type: snapshot.type,
                name: snapshot.name,
                note: snapshot.note
            )
        )
    }

    private func deleteLocalEntity(
        for key: SyncEntityKey
    ) throws {
        switch key.type {
        case .transaction:
            let id = key.id

            if let transaction = try modelContext.fetch(
                FetchDescriptor<Transaction>(
                    predicate: #Predicate<Transaction> { transaction in
                        transaction.id == id
                    }
                )
            ).first {
                modelContext.delete(transaction)
            }

        case .category:
            let id = key.id

            if let category = try modelContext.fetch(
                FetchDescriptor<Category>(
                    predicate: #Predicate<Category> { category in
                        category.id == id
                    }
                )
            ).first {
                modelContext.delete(category)
            }
        }
    }

    // MARK: - Sync metadata

    private func setSyncState(
        for key: SyncEntityKey,
        revision: Int,
        lastMutationId: UUID
    ) throws {
        if let state = try modelContext.fetch(
            MutationQueries.getEntitySyncState(key)
        ).first {
            state.revision = revision
            state.lastMutationId = lastMutationId

            return
        }

        modelContext.insert(
            EntitySyncState(
                key: key,
                lastMutationId: lastMutationId,
                revision: revision
            )
        )
    }

    private func deleteSyncState(
        for key: SyncEntityKey
    ) throws {
        if let state = try modelContext.fetch(
            MutationQueries.getEntitySyncState(key)
        ).first {
            modelContext.delete(state)
        }
    }

    // MARK: - Helpers

    private func operation(
        for snapshot: EntitySnapshot
    ) -> SyncOperation {
        switch snapshot {
        case .transaction(let transaction):
            transaction.deletedAt == nil
                ? .upsert
                : .delete

        case .category(let category):
            category.deletedAt == nil
                ? .upsert
                : .delete
        }
    }
}
