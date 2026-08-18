import SwiftData
import SwiftUI

struct RootView: View {
    let syncEngine: SyncEngine
    let conflictResolutionService: ConflictResolutionService

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    HomeView()
                }
            }

            Tab("Transactions", systemImage: "list.bullet") {
                NavigationStack {
                    TransactionListView()
                }
            }

            Tab("Categories", systemImage: "square.grid.2x2") {
                NavigationStack {
                    CategoryListView()
                }
            }

            Tab("Sync", systemImage: "arrow.triangle.2.circlepath") {
                NavigationStack {
                    SyncView(
                        syncEngine: syncEngine,
                        conflictResolutionService:
                            conflictResolutionService
                    )
                }
            }
        }
        .background {
            UndoResponderView()
                .frame(width: 0, height: 0)
        }
    }
}
