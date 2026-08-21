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

extension SyncConflictCandidate {
    fileprivate var title: String {
        switch local {
        case .transaction(let transaction):
            let note =
                transaction.note
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            return note.isEmpty
                ? String(
                    localized:
                        "Transaction"
                )
                : note

        case .category(let category):
            return category.name

        case .subcategory(let subcategory):
            return subcategory.name
        }
    }

    fileprivate var entityName: String {
        switch key.type {
        case .transaction:
            String(
                localized:
                    "Transaction"
            )

        case .category:
            String(
                localized:
                    "Category"
            )

        case .subcategory:
            String(
                localized:
                    "Subcategory"
            )
        }
    }

    fileprivate var message: String {
        switch reason {
        case .diverged:
            String(
                localized:
                    "This item changed both on this device and in Google Sheets."
            )

        case .remoteMissing:
            String(
                localized:
                    "This item exists on this device but is missing from Google Sheets."
            )

        case .invalidLocalChain:
            String(
                localized:
                    "Lootrack could not safely replay your local changes on top of the Google Sheets version."
            )
        }
    }
}

struct SyncView: View {
    @Environment(SyncCoordinator.self)
    private var syncCoordinator

    @Environment(NetworkMonitor.self)
    private var networkMonitor

    @Query(MutationQueries.pendingByOldest)
    private var mutations: [Mutation]

    private var pendingEntities: [PendingEntityChanges] {
        Dictionary(
            grouping: mutations,
            by: {
                $0.payload.key
            }
        )
        .values
        .map { mutations in
            PendingEntityChanges(mutations: mutations)
        }
        .sorted {
            $0.latestMutation.createdAt > $1.latestMutation.createdAt
        }
    }

    var body: some View {
        List {
            statusSection
            syncActionSection
            errorSection
            conflictsSection
            pendingChangesSection
        }
        .navigationTitle("Sync Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Text("Synchronization")
                
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: syncStatusIcon)
                    Text(syncStatusName)
                }
                .foregroundStyle(syncStatusColor)
            }
            
            LabeledContent("Last Sync") {
                if let lastSuccessfulSync = syncCoordinator.lastSuccessfulSync {
                    Text(lastSuccessfulSync.formatted(date: .abbreviated, time: .shortened))
                } else {
                    Text("Never")
                        .foregroundStyle(.secondary)
                }
            }
            
            LabeledContent("Pending Changes", value: "\(mutations.count)")
            LabeledContent("Conflicts", value: "\(syncCoordinator.conflicts.count)")
        }
    }

    private var syncActionSection: some View {
        Section {
            Button {
                Task {
                    await syncCoordinator.synchronize()
                }
            } label: {
                HStack {
                    Spacer()

                    if syncCoordinator.isSyncing {
                        ProgressView()
                            .padding(.trailing, 4)

                        Text("Synchronizing…")
                    } else {
                        Label(
                            "Sync Now",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }

                    Spacer()
                }
            }
            .disabled(
                syncCoordinator.isSyncing
                    || networkMonitor.status != .online
                    || !syncCoordinator.conflicts.isEmpty
            )
        } footer: {
            if networkMonitor.status == .offline {
                Text(
                    "Synchronization is unavailable while offline. Your changes are saved locally."
                )
            } else if networkMonitor.status == .unknown {
                Text("Waiting for network status.")
            } else if !syncCoordinator.conflicts.isEmpty {
                Text("Resolve all conflicts before synchronizing again.")
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if case .failed(let error) = syncCoordinator.status {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            error.errorDescription
                                ?? String(localized: "Synchronization failed.")
                        )
                        .fontWeight(.medium)

                        if let recoverySuggestion = error.recoverySuggestion {
                            Text(recoverySuggestion)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var conflictsSection: some View {
        if !syncCoordinator.conflicts.isEmpty {
            Section {
                ForEach(syncCoordinator.conflicts) { conflict in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 2) {
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
                                syncCoordinator.resolveConflict(
                                    conflict,
                                    using: .keepRemote
                                )
                            } label: {
                                Text(
                                    conflict.remote == nil
                                        ? "Discard local" : "Use remote"
                                )
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Button {
                                syncCoordinator.resolveConflict(
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
                    syncCoordinator.conflicts.count == 1
                        ? "1 conflict needs attention"
                        : "\(syncCoordinator.conflicts.count) conflicts need attention",
                    systemImage: "exclamationmark.triangle"
                )
            } footer: {
                Text(
                    "Synchronization is paused until these conflicts are resolved."
                )
            }
        }
    }

    @ViewBuilder
    private var pendingChangesSection: some View {
        if !pendingEntities.isEmpty {
            Section("Pending Changes") {
                ForEach(pendingEntities) { pending in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title(for: pending))
                                .fontWeight(.medium)

                            Text(
                                pending.mutations.count == 1
                                    ? "1 pending change"
                                    : "\(pending.mutations.count) pending changes"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(pending.latestMutation.kind.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var syncStatusName: String {
        switch syncCoordinator.status {
        case .idle:
            String(localized: "Ready")
        case .syncing:
            String(localized: "Synchronizing…")
        case .succeeded:
            String(localized: "Up to date")
        case .waitingForConflictResolution:
            String(localized: "Needs attention")
        case .failed:
            String(localized: "Failed")
        }
    }

    private var syncStatusIcon: String {
        switch syncCoordinator.status {
        case .idle:
            "circle"
        case .syncing:
            "arrow.triangle.2.circlepath"
        case .succeeded:
            "checkmark.circle.fill"
        case .waitingForConflictResolution:
            "exclamationmark.triangle.fill"
        case .failed:
            "xmark.circle.fill"
        }
    }

    private var syncStatusColor: Color {
        switch syncCoordinator.status {
        case .idle:
            .secondary
        case .syncing:
            .accentColor
        case .succeeded:
            .green
        case .waitingForConflictResolution:
            .orange
        case .failed:
            .red
        }
    }

    private func title(for pending: PendingEntityChanges) -> String {
        switch pending.entity {
        case .transaction(let transaction):
            let note = transaction.note.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return note.isEmpty ? String(localized: "Transaction") : note

        case .category(let category):
            return category.name

        case .subcategory(let subcategory):
            return subcategory.name
        }
    }
}
