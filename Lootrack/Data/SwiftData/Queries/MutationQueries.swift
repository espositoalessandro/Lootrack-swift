import Foundation
import SwiftData

enum MutationQueries {
    static func getRelationshipsByEntityId(_ entityId: UUID) throws
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

    static var activeByMostRecent: FetchDescriptor<Transaction> {
        FetchDescriptor(
            predicate: #Predicate<Transaction> { transaction in
                transaction.deletedAt == nil
            },
            sortBy: [
                SortDescriptor(
                    \Transaction.occurredOn,
                    order: .reverse
                )
            ]
        )
    }
}
