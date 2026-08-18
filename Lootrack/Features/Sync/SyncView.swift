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

struct SyncView: View {
    let syncEngine: SyncEngine
    
    @State private var isSyncing = false
    @State private var syncResult: String?

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
        
        defer {
            isSyncing = false
        }
        
        do {
            try await syncEngine.synchronize()
            
            syncResult = "Synchronization completed"
        } catch let error as SyncRunConflictError {
            syncResult =
            """
            Conflicts: \(error.conflicts.count)
            
            \(error.conflicts.map {
                "\($0.key.type.rawValue) \($0.key.id): \($0.reason.rawValue)"
            }.joined(separator: "\n"))
            """
        } catch {
            syncResult =
            "ERROR: \(String(describing: error))"
            
            print(
                "Synchronization failed:",
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
                        .font(.caption.monospaced())
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
        .navigationTitle("Mutation list")
    }
    
    
}
