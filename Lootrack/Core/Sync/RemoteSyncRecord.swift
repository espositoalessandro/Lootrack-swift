import Foundation

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

nonisolated struct RemoteSyncSnapshot: Codable, Equatable {
    let records: [RemoteSyncRecord]
}

nonisolated struct SyncPushRequest: Codable {
    let mutations: [MutationDTO]
}

nonisolated struct SyncPushResult: Codable, Equatable {
    let records: [RemoteSyncRecord]
}
