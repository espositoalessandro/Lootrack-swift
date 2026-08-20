nonisolated
enum SyncProviderError: Error {
    case authenticationRequired
    case permissionDenied
    case configurationRequired
    case connectionUnavailable
    case remoteUnavailable
    case rateLimited
    case serviceUnavailable
    case invalidRemoteData
    case remoteChanged
}

protocol SyncProvider {
    func pull() async throws -> RemoteSyncSnapshot
    func push(_ request: SyncPushRequest) async throws -> SyncPushResult
}
