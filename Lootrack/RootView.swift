import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(SyncCoordinator.self)
    private var syncCoordinator
    
    @Query(MutationQueries.pendingByOldest)
    private var mutations: [Mutation]
    
    @State private var isSyncPresented = false
    
    private var hasConflicts: Bool {
        !syncCoordinator.conflicts.isEmpty
    }
    
    private var syncBadgeCount: Int {
        if hasConflicts {
            return syncCoordinator.conflicts.count
        }
        
        return mutations.count
    }
    
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    HomeView()
                        .toolbar {
                            appToolbar
                        }
                }
            }
            
            Tab("Transactions", systemImage: "list.bullet") {
                NavigationStack {
                    TransactionListView()
                        .toolbar {
                            appToolbar
                        }
                }
            }
            
            Tab("Categories", systemImage: "square.grid.2x2") {
                NavigationStack {
                    CategoryListView()
                        .toolbar {
                            appToolbar
                        }
                }
            }
        }
        .sheet(
            isPresented: $isSyncPresented
        ) {
            NavigationStack {
                SyncView()
            }
        }
        .background {
            UndoResponderView()
                .frame(width: 0, height: 0)
        }
    }
    
    @ToolbarContentBuilder
    private var appToolbar: some ToolbarContent {
        ToolbarItem(
            placement: .topBarTrailing
        ) {
            syncStatusButton
        }
    }
    
    private var syncStatusButton: some View {
        Button {
            isSyncPresented = true
        } label: {
            Image(
                systemName:
                    hasConflicts
                ? "exclamationmark.triangle.fill"
                : "arrow.triangle.2.circlepath"
            )
            .overlay(
                alignment: .topTrailing
            ) {
                if syncBadgeCount > 0 {
                    Text(
                        syncBadgeCount > 99
                        ? "99+"
                        : "\(syncBadgeCount)"
                    )
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(
                        minWidth: 16,
                        minHeight: 16
                    )
                    .background(
                        hasConflicts
                        ? Color.red
                        : Color.accentColor,
                        in: Capsule()
                    )
                    .offset(
                        x: 9,
                        y: -8
                    )
                }
            }
        }
        .accessibilityLabel(
            hasConflicts
            ? "Synchronization conflicts"
            : "Synchronization"
        )
    }
}
