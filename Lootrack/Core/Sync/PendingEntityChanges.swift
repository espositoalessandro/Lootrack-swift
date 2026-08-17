import Foundation

struct PendingEntityChanges: Identifiable {
    let mutations: [Mutation]

    init(mutations: [Mutation]) {
        precondition(!mutations.isEmpty)

        self.mutations = mutations
    }

    var id: SyncEntityKey {
        latestMutation.payload.key
    }

    var entity: EntitySnapshot {
        latestMutation.payload
    }

    var latestMutation: Mutation {
        mutations.last!
    }
}
