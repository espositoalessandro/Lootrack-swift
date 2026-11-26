nonisolated enum SyncProviderError: Error {
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
    /// Whether the provider's account or connection is available for use.
    var isConnected: Bool { get }

    /// Whether the provider's sync destination has been configured.
    var isConfigured: Bool { get }

    func pull() async throws -> RemoteSyncSnapshot
    func push(_ request: SyncPushRequest) async throws -> SyncPushResult
    func replaceRemote(with snapshot: RemoteSyncSnapshot) async throws
}

extension SyncProvider {
    var isReady: Bool {
        isConnected && isConfigured
    }
}
