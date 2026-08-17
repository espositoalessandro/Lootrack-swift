nonisolated protocol SyncProvider {
    func pull() async throws -> RemoteSyncSnapshot

    func push(
        _ request: SyncPushRequest
    ) async throws -> SyncPushResult
}
