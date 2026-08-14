import SwiftUI
import SwiftData

@main
struct LootrackApp: App {
    private let modelContainer: ModelContainer
    private let transactionService: TransactionService
    private let categoryService: CategoryService
    
    init() {
        do {
            let modelContainer = try ModelContainer(
                for: Transaction.self,
                Category.self
            )

            self.modelContainer = modelContainer

            self.transactionService = TransactionService(
                modelContext: modelContainer.mainContext
            )
            self.categoryService = CategoryService(
                modelContext: modelContainer.mainContext
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
    }
}
