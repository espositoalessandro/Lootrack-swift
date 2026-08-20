import SwiftData
import SwiftUI

enum PendingMutationKind {
    case created
    case updated
    case deleted

    var displayName: String {
        switch self {
        case .created:
            "Created"

        case .updated:
            "Updated"

        case .deleted:
            "Deleted"
        }
    }
}

extension Mutation {
    var kind: PendingMutationKind {
        if operation == .delete {
            return .deleted
        }

        if base == nil {
            return .created
        }

        return .updated
    }
}

private extension SyncConflictCandidate {
    var title: String {
        switch local {
        case let .transaction(transaction):
            let note =
                transaction.note
                    .trimmingCharacters(in:
                        .whitespacesAndNewlines)

            return note.isEmpty
                ? String(localized:
                    "Transaction")
                : note

        case let .category(category):
            return category.name

        case let .subcategory(subcategory):
            return subcategory.name
        }
    }

    var entityName: String {
        switch key.type {
        case .transaction:
            String(localized:
                "Transaction")

        case .category:
            String(localized:
                "Category")

        case .subcategory:
            String(localized:
                "Subcategory")
        }
    }

    var message: String {
        switch reason {
        case .diverged:
            String(localized:
                "This item changed both on this device and in Google Sheets.")

        case .remoteMissing:
            String(localized:
                "This item exists on this device but is missing from Google Sheets.")

        case .invalidLocalChain:
            String(localized:
                "Lootrack could not safely replay your local changes on top of the Google Sheets version.")
        }
    }
}

struct SyncView: View {
    @Environment(SyncCoordinator.self)
    private var syncCoordinator

    @Query(MutationQueries
        .pendingByOldest)
    private var mutations: [Mutation]

    private var pendingEntities: [PendingEntityChanges] {
        Dictionary(grouping: mutations,
                   by: {
                       $0.payload.key
                   })
                   .values
                   .map { mutations in
                       PendingEntityChanges(mutations:
                           mutations)
                   }
                   .sorted {
                       $0.latestMutation
                           .createdAt
                           > $1.latestMutation
                           .createdAt
                   }
    }

    var body: some View {
        if let syncResult = syncCoordinator.syncResult {
            Section {
                Text(syncResult)
                    .font(.footnote)
                    .foregroundStyle(syncResult.hasPrefix("ERROR:")
                        ? .red
                        : .secondary)
                    .textSelection(.enabled)
            } header: {
                Text("Synchronization")
            }
        }
        List {
            if !syncCoordinator
                .conflicts
                .isEmpty
            {
                Section {
                    ForEach(syncCoordinator
                        .conflicts)
                    { conflict in
                        VStack(alignment:
                            .leading,
                            spacing: 12)
                        {
                            HStack {
                                Image(systemName:
                                    "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)

                                VStack(alignment:
                                    .leading,
                                    spacing: 2)
                                {
                                    Text(conflict
                                        .title)
                                        .fontWeight(.semibold)

                                    Text(conflict
                                        .entityName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(conflict
                                .message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button {
                                    syncCoordinator
                                        .resolveConflict(conflict,
                                                         using:
                                                         .keepRemote)
                                } label: {
                                    Text(conflict
                                        .remote
                                        == nil
                                        ? "Discard local"
                                        : "Use remote")
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                Button {
                                    syncCoordinator
                                        .resolveConflict(conflict,
                                                         using:
                                                         .keepLocal)
                                } label: {
                                    Text("Keep mine")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical,
                                 6)
                    }
                } header: {
                    Label(syncCoordinator
                        .conflicts
                        .count
                        == 1
                        ? "1 conflict needs attention"
                        : "\(syncCoordinator.conflicts.count) conflicts need attention",
                        systemImage:
                        "exclamationmark.triangle")
                } footer: {
                    Text("Synchronization is paused until these conflicts are resolved.")
                }
            }

            ForEach(pendingEntities) { pending in
                Section {
                    ForEach(pending
                        .mutations
                        .reversed())
                    { mutation in
                        DisclosureGroup {
                            VStack(alignment:
                                .leading,
                                spacing: 12)
                            {
                                Text("Base")
                                    .font(.headline)

                                Text(mutation
                                    .base
                                    .map {
                                        String(describing:
                                            $0)
                                    }
                                    ?? "nil")
                                    .font(.caption
                                        .monospaced())

                                Divider()

                                Text("Payload")
                                    .font(.headline)

                                Text(String(describing:
                                    mutation
                                        .payload))
                                    .font(.caption
                                        .monospaced())

                                Divider()

                                Text("""
                                expectedRevision: \(String(describing: mutation.expectedRevision))
                                expectedMutationId: \(String(describing: mutation.expectedMutationId))
                                """)
                                .font(.caption
                                    .monospaced())
                            }
                            .padding(.vertical,
                                     8)

                        } label: {
                            HStack {
                                Text(mutation
                                    .kind
                                    .displayName)

                                Spacer()

                                Text(mutation
                                    .createdAt
                                    .formatted(date:
                                        .abbreviated,
                                        time:
                                        .shortened))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                } header: {
                    switch pending.entity {
                    case let .transaction(transaction):
                        Text(transaction.note)

                    case let .category(category):
                        Text(category.name)

                    case let .subcategory(subcategory):
                        Text(subcategory.name)
                    }
                }
            }
        }
        .navigationTitle("Pending modifications")
    }
}
