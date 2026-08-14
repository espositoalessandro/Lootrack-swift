import SwiftUI
import SwiftData

@main
struct LootrackApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Transaction.self,
            Category.self
        ])
    }
}
