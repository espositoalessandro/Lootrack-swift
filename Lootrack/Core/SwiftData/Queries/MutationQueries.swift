import Foundation
import SwiftData

enum MutationQueries {
    static func getEntitySyncState(_ entityId: UUID) throws
        -> FetchDescriptor<EntitySyncState>
    {
        FetchDescriptor(
            predicate: #Predicate<EntitySyncState> { mutation in
                mutation.entityId == entityId
            },
            sortBy: [
                SortDescriptor(\EntitySyncState.revision, order: .reverse)
            ]
        )
    }

    static var pendingByOldest: FetchDescriptor<Mutation> {
        FetchDescriptor(
            sortBy: [
                SortDescriptor(
                    \Mutation.createdAt,
                     order: .forward
                )
            ]
        )
    }
}
