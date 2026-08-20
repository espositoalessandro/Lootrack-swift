import Foundation
import SwiftData

enum MutationQueries {
    static func getEntitySyncState(_ key: SyncEntityKey) -> FetchDescriptor<EntitySyncState> {
        let entityId = key.id
        let entityType = key.type

        return FetchDescriptor(predicate: #Predicate<EntitySyncState> { state in
            state.entityId == entityId
                && state.entityType == entityType
        })
    }

    static var pendingByOldest: FetchDescriptor<Mutation> {
        FetchDescriptor(sortBy: [SortDescriptor(\Mutation.createdAt,
                                                order: .forward)])
    }
}
