import Foundation

nonisolated struct RemoteSyncSnapshot:
    Codable,
    Equatable
{
    let records: [RemoteSyncRecord]
}

nonisolated struct SyncPushRequest:
    Codable
{
    let mutations: [MutationDTO]
}

nonisolated struct SyncPushResult:
    Codable,
    Equatable
{
    let records: [RemoteSyncRecord]
}

nonisolated struct SyncReconciler {
    func reconcile(local: LocalSyncSnapshot,
                   remote: RemoteSyncSnapshot) -> SyncReconciliationPlan
    {
        var localEntities:
            [SyncEntityKey:
                EntitySnapshot] = [:]

        for transaction
            in local.transactions
        {
            let snapshot =
                EntitySnapshot
                    .transaction(transaction)

            localEntities[snapshot.key] = snapshot
        }

        for category
            in local.categories
        {
            let snapshot =
                EntitySnapshot
                    .category(category)

            localEntities[snapshot.key] = snapshot
        }

        for subcategory
            in local.subcategories
        {
            let snapshot =
                EntitySnapshot
                    .subcategory(subcategory)

            localEntities[snapshot.key] = snapshot
        }

        let remoteRecords =
            Dictionary(uniqueKeysWithValues:
                remote.records.map {
                    record in
                    (record.id,
                     record)
                })

        let pendingByEntity =
            Dictionary(grouping:
                local.mutations,
                by: { mutation in
                    mutation.payload.key
                })
            .mapValues {
                mutations in
                mutations.sorted {
                    $0.createdAt
                        < $1.createdAt
                }
            }

        var keys =
            Set(localEntities.keys)

        keys.formUnion(remoteRecords.keys)

        keys.formUnion(pendingByEntity.keys)

        var remoteRecordsToApply: [RemoteSyncRecord] = []

        var mutationsToPush: [MutationDTO] = []

        var mutationIdsToAcknowledge: [UUID] = []

        var conflicts: [SyncConflictCandidate] = []

        for key in keys {
            let localEntity =
                localEntities[key]

            let remoteRecord =
                remoteRecords[key]

            let pending =
                pendingByEntity[key]
                    ?? []

            /*
             * No local pending changes:
             * remote state is authoritative.
             */
            if pending.isEmpty {
                guard let remoteRecord
                else {
                    if let localEntity {
                        conflicts.append(SyncConflictCandidate(key: key,
                                                               reason:
                                                               .remoteMissing,
                                                               base:
                                                               localEntity,
                                                               local:
                                                               localEntity,
                                                               remote: nil,
                                                               pendingMutations: []))
                    }

                    continue
                }

                if localEntity == nil
                    || !sameRemoteVersion(metadata:
                        local
                            .metadata[key],
                        remote:
                        remoteRecord)
                {
                    remoteRecordsToApply
                        .append(remoteRecord)
                }

                continue
            }

            guard let firstPending =
                pending.first,
                let lastPending =
                pending.last
            else {
                continue
            }

            /*
             * Recovery from an uncertain
             * previous push.
             */
            if let remoteRecord,
               let remotelyAppliedIndex =
               pending.firstIndex(where: {
                   mutation in
                   mutation.id
                       == remoteRecord
                       .mutationId
               })
            {
                let acknowledged =
                    pending[...remotelyAppliedIndex]

                let remaining =
                    pending.dropFirst(remotelyAppliedIndex
                        + 1)

                mutationIdsToAcknowledge
                    .append(contentsOf:
                        acknowledged
                            .map(\.id))

                if remaining.isEmpty {
                    continue
                }

                guard let firstRemaining =
                    remaining.first
                else {
                    continue
                }

                if !remoteMatchesExpectedBase(remote:
                    remoteRecord,
                    mutation:
                    firstRemaining)
                {
                    conflicts.append(SyncConflictCandidate(key: key,
                                                           reason:
                                                           .invalidLocalChain,
                                                           base:
                                                           firstRemaining
                                                               .base,
                                                           local:
                                                           lastPending
                                                               .payload,
                                                           remote:
                                                           remoteRecord,
                                                           pendingMutations:
                                                           pending))

                    continue
                }

                mutationsToPush
                    .append(contentsOf:
                        remaining)

                continue
            }

            /*
             * Ordinary non-conflicting
             * pending chain.
             */
            if remoteMatchesExpectedBase(remote: remoteRecord,
                                         mutation: firstPending)
            {
                mutationsToPush.append(contentsOf: pending)

                continue
            }

            /*
             * Remote changed since the first
             * local mutation was based on it.
             */
            conflicts.append(SyncConflictCandidate(key: key,
                                                   reason:
                                                   remoteRecord == nil
                                                       ? .remoteMissing
                                                       : .diverged,
                                                   base:
                                                   firstPending.base,
                                                   local:
                                                   lastPending
                                                       .payload,
                                                   remote:
                                                   remoteRecord,
                                                   pendingMutations:
                                                   pending))
        }

        return SyncReconciliationPlan(remoteRecordsToApply:
            remoteRecordsToApply,
            mutationsToPush:
            mutationsToPush,
            mutationIdsToAcknowledge:
            mutationIdsToAcknowledge,
            conflicts: conflicts)
    }

    private func remoteMatchesExpectedBase(remote: RemoteSyncRecord?,
                                           mutation: MutationDTO) -> Bool
    {
        guard let remote else {
            return mutation
                .expectedRevision
                == nil
                && mutation
                .expectedMutationId
                == nil
        }

        return mutation
            .expectedRevision
            == remote.revision
            && mutation
            .expectedMutationId
            == remote.mutationId
    }

    private func sameRemoteVersion(metadata: SyncMetadata?,
                                   remote: RemoteSyncRecord) -> Bool
    {
        guard let metadata else {
            return false
        }

        return metadata.revision
            == remote.revision
            && metadata
            .lastMutationId
            == remote.mutationId
    }
}
