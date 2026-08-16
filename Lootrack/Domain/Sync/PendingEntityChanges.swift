import Foundation

struct PendingEntityChanges: Identifiable {
    let entity: EntityRef
    let mutations: [Mutation]

    var id: SyncEntityKey {
        entity.key
    }

    var latestMutation: Mutation {
        mutations.last!
    }
}
