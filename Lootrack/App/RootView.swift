import SwiftUI

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
        }
    }
}

#Preview {
    RootView()
}
