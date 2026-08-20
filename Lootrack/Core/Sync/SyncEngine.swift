import Foundation

nonisolated struct SyncRunConflictError: Error {
    let conflicts: [SyncConflictCandidate]

    init(_ conflicts: [SyncConflictCandidate]) {
        self.conflicts = conflicts
    }
}

@MainActor
final class SyncEngine {
    private let localStore: LocalSyncStore
    private let provider: any SyncProvider
    private let reconciler: SyncReconciler

    init(localStore: LocalSyncStore,
         provider: any SyncProvider,
         reconciler: SyncReconciler = SyncReconciler())
    {
        self.localStore = localStore
        self.provider = provider
        self.reconciler = reconciler
    }

    func synchronize() async throws {
        let localSnapshot = try localStore.getSnapshot()

        let remoteSnapshot = try await provider.pull()

        let plan = reconciler.reconcile(local: localSnapshot,
                                        remote: remoteSnapshot)

        guard plan.conflicts.isEmpty else {
            throw SyncRunConflictError(plan.conflicts)
        }

        let pushResult = try await provider.push(SyncPushRequest(mutations: plan.mutationsToPush))

        let pushedMutationIds = plan.mutationsToPush.map(\.id)

        /*
         * This is the only local write performed by a
         * successful synchronization run.
         *
         * LocalSyncStore also protects entities that received
         * newer mutations while the network operations were
         * running.
         */
        try localStore.applyChanges(LocalSyncChanges(remoteRecords:
            plan.remoteRecordsToApply
                + pushResult.records,

            mutationIdsToAcknowledge:
            plan.mutationIdsToAcknowledge
                + pushedMutationIds))
    }
}
