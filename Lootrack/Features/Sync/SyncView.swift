import SwiftData
import SwiftUI

enum PendingMutationKind {
    case created
    case updated
    case deleted
    
    var displayName: String {
        switch self {
        case .created:
            return "Created"
        case .updated:
            return "Updated"
        case .deleted:
            return "Deleted"
        }
    }
}

extension Mutation {
    var kind: PendingMutationKind {
        if operation == .delete {
            return .deleted
        }

        if changes.contains(
            where: {
                $0.field == "createdAt"
                    && $0.before == .null
            }
        ) {
            return .created
        }

        return .updated
    }
}

extension MutationValue {
    var displayValue: String {
        switch self {
        case .string(let value):
            return value

        case .int(let value):
            return String(value)

        case .date(let value):
            return value.formatted(
                date: .abbreviated,
                time: .shortened
            )

        case .uuid(let value):
            return value.uuidString

        case .transactionType(let value):
            return value.rawValue.capitalized

        case .null:
            return "None"
        }
    }
}

struct SyncView: View {

    @Query(MutationQueries.pendingByOldest)
    private var mutations: [Mutation]

    private var pendingEntities: [PendingEntityChanges] {
        Dictionary(
            grouping: mutations,
            by: { $0.entity.key }
        )
        .values
        .compactMap { mutations in
            guard let first = mutations.first else {
                return nil
            }

            return PendingEntityChanges(
                entity: first.entity,
                mutations: mutations
            )
        }
        .sorted {
            $0.latestMutation.createdAt > $1.latestMutation.createdAt
        }
    }

    var body: some View {
        List {
            ForEach(pendingEntities) { pending in
                Section {
                    ForEach(pending.mutations.reversed()) { mutation in
                        DisclosureGroup {
                            VStack(
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(
                                    Array(mutation.changes.enumerated()),
                                    id: \.offset
                                ) { _, change in
                                    HStack {
                                        Text(change.field)

                                        Spacer()

                                        Text(change.before.displayValue)
                                            .foregroundStyle(.secondary)

                                        Image(systemName: "arrow.right")

                                        Text(change.after.displayValue)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        } label: {
                            HStack {
                                Text(mutation.kind.displayName)

                                Spacer()

                                Text(
                                    mutation.createdAt.formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    )
                                )
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    switch pending.entity {
                    case .transaction(let transaction):
                        Text(transaction.note)

                    case .category(let category):
                        Text(category.name)
                    }
                }
            }
        }
    }
}
