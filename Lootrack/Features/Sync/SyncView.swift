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

        if base == nil {
            return .created
        }

        return .updated
    }
}

extension SyncConflictCandidate {
    fileprivate var title: String {
        switch local {
        case .transaction(let transaction):
            let note = transaction.note.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            return note.isEmpty
                ? String(localized: "Transaction")
                : note

        case .category(let category):
            return category.name
        }
    }

    fileprivate var entityName: String {
        switch key.type {
        case .transaction:
            return String(localized: "Transaction")

        case .category:
            return String(localized: "Category")
        }
    }

    fileprivate var message: String {
        switch reason {
        case .diverged:
            return String(
                localized:
                    "This item changed both on this device and in Google Sheets."
            )

        case .remoteMissing:
            return String(
                localized:
                    "This item exists on this device but is missing from Google Sheets."
            )

        case .invalidLocalChain:
            return String(
                localized:
                    "Lootrack could not safely replay your local changes on top of the Google Sheets version."
            )
        }
    }
}

struct SyncView: View {
    let syncEngine: SyncEngine
    let conflictResolutionService: ConflictResolutionService

    @State private var isSyncing = false
    @State private var syncResult: String?

    /*
     * Conflicts deliberately aren't persisted.
     *
     * They describe one particular reconciliation attempt.
     */
    @State private var conflicts: [SyncConflictCandidate] = []

    @Query(MutationQueries.pendingByOldest)
    private var mutations: [Mutation]

    private var pendingEntities: [PendingEntityChanges] {
        Dictionary(
            grouping: mutations,
            by: { $0.payload.key }
        )
        .values
        .map { mutations in
            PendingEntityChanges(
                mutations: mutations
            )
        }
        .sorted {
            $0.latestMutation.createdAt
                > $1.latestMutation.createdAt
        }
    }

    private func synchronize() async {
        isSyncing = true

        /*
         * A new synchronization attempt produces a completely
         * new reconciliation result.
         */
        conflicts = []
        syncResult = nil

        defer {
            isSyncing = false
        }

        do {
            try await syncEngine.synchronize()

            syncResult = "Synchronization completed"

        } catch let error as SyncRunConflictError {
            conflicts = error.conflicts

        } catch {
            conflicts = []

            syncResult =
                "ERROR: \(String(describing: error))"

            print(
                "Synchronization failed:",
                error
            )
        }
    }

    private func resolveConflict(
        _ conflict: SyncConflictCandidate,
        using resolution: ConflictResolution
    ) {
        do {
            try conflictResolutionService.resolve(
                conflict,
                using: resolution
            )

            /*
             * Only this conflict was resolved.
             *
             * Other conflicts still belong to the same failed
             * synchronization attempt and remain visible.
             */
            conflicts.removeAll {
                $0.id == conflict.id
            }

            if conflicts.isEmpty {
                syncResult =
                    "Conflicts resolved. Synchronize again to continue."
            }

        } catch {
            syncResult =
                "ERROR: \(String(describing: error))"

            print(
                "Conflict resolution failed:",
                error
            )
        }
    }

    var body: some View {
        List {
            Section("Synchronization") {
                Button {
                    Task {
                        await synchronize()
                    }
                } label: {
                    if isSyncing {
                        ProgressView()
                    } else {
                        Text("Synchronize")
                    }
                }
                .disabled(isSyncing)

                if let syncResult {
                    Text(syncResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !conflicts.isEmpty {
                Section {
                    ForEach(conflicts) { conflict in
                        VStack(
                            alignment: .leading,
                            spacing: 12
                        ) {
                            HStack {
                                Image(
                                    systemName:
                                        "exclamationmark.triangle.fill"
                                )
                                .foregroundStyle(.orange)

                                VStack(
                                    alignment: .leading,
                                    spacing: 2
                                ) {
                                    Text(conflict.title)
                                        .fontWeight(.semibold)

                                    Text(conflict.entityName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(conflict.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button {
                                    resolveConflict(
                                        conflict,
                                        using: .keepRemote
                                    )
                                } label: {
                                    Text(
                                        conflict.remote == nil
                                            ? "Discard local"
                                            : "Use remote"
                                    )
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                Button {
                                    resolveConflict(
                                        conflict,
                                        using: .keepLocal
                                    )
                                } label: {
                                    Text("Keep mine")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Label(
                        conflicts.count == 1
                            ? "1 conflict needs attention"
                            : "\(conflicts.count) conflicts need attention",
                        systemImage: "exclamationmark.triangle"
                    )
                } footer: {
                    Text(
                        "Synchronization is paused until these conflicts are resolved."
                    )
                }
            }

            ForEach(pendingEntities) { pending in
                Section {
                    ForEach(
                        pending.mutations.reversed()
                    ) { mutation in
                        DisclosureGroup {
                            VStack(
                                alignment: .leading,
                                spacing: 12
                            ) {
                                Text("Base")
                                    .font(.headline)

                                Text(
                                    mutation.base.map {
                                        String(describing: $0)
                                    } ?? "nil"
                                )
                                .font(.caption.monospaced())

                                Divider()

                                Text("Payload")
                                    .font(.headline)

                                Text(
                                    String(
                                        describing: mutation.payload
                                    )
                                )
                                .font(.caption.monospaced())

                                Divider()

                                Text(
                                    """
                                    expectedRevision: \(String(describing: mutation.expectedRevision))
                                    expectedMutationId: \(String(describing: mutation.expectedMutationId))
                                    """
                                )
                                .font(.caption.monospaced())
                            }
                            .padding(.vertical, 8)

                        } label: {
                            HStack {
                                Text(
                                    mutation.kind.displayName
                                )

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
        .navigationTitle("Sync")
    }
}
