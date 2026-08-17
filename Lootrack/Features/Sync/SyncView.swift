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
    let googleSheetsProvider: GoogleSheetsProvider
    
    @State private var isTestingGoogle = false
    @State private var googleTestResult: String?

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

    private func testGooglePull() async {
        isTestingGoogle = true
        
        defer {
            isTestingGoogle = false
        }
        
        do {
            let snapshot =
            try await googleSheetsProvider.pull()
            
            let transactionCount =
            snapshot.records.filter {
                $0.entityType == .transaction
            }.count
            
            let categoryCount =
            snapshot.records.filter {
                $0.entityType == .category
            }.count
            
            googleTestResult =
            """
            Success
            Records: \(snapshot.records.count)
            Transactions: \(transactionCount)
            Categories: \(categoryCount)
            """
            
            print(
                "Google pull succeeded:",
                snapshot.records
            )
        } catch {
            googleTestResult =
            "ERROR: \(String(describing: error))"
            
            print(
                "Google pull failed:",
                error
            )
        }
    }
    
    var body: some View {
        List {
            Section("Google Sheets") {
                Button {
                    Task {
                        await testGooglePull()
                    }
                } label: {
                    if isTestingGoogle {
                        ProgressView()
                    } else {
                        Text("Test Google pull")
                    }
                }
                .disabled(isTestingGoogle)
                
                if let googleTestResult {
                    Text(googleTestResult)
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
