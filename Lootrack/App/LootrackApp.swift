import SwiftData
import SwiftUI

@main
struct LootrackApp: App {
    private let modelContainer: ModelContainer
    private let transactionService: TransactionService
    private let categoryService: CategoryService
    private let sync: Sync

    init() {
        do {
            let modelContainer = try ModelContainer(
                for: Transaction.self,
                Category.self,
                Mutation.self,
                EntitySyncState.self
            )

            self.modelContainer = modelContainer
            self.sync = Sync(
                modelContext: modelContainer.mainContext
            )
            self.transactionService = TransactionService(
                modelContext: modelContainer.mainContext,
                sync: sync
            )
            self.categoryService = CategoryService(
                modelContext: modelContainer.mainContext,
                sync: sync
            )


        } catch {
            fatalError(
                "Failed to create SwiftData container: \(error)"
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
        .environment(transactionService)
        .environment(categoryService)
    }
}
