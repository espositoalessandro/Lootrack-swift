import SwiftUI
import SwiftData

struct RootView: View {
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

            Tab("Sync", systemImage: "arrow.triangle.2.circlepath") {
                NavigationStack {
                    SyncView()
                }
            }
            
            Tab("Categories", systemImage: "square.grid.2x2") {
                NavigationStack {
                    CategoryListView()
                }
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(
            for: [
                Transaction.self,
                Category.self
            ],
            inMemory: true
        )
}
