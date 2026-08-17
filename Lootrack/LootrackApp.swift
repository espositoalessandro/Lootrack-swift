import SwiftData
import SwiftUI
import GoogleSignIn

@main
struct LootrackApp: App {
    private let modelContainer: ModelContainer

    private let mutationService: MutationService
    private let transactionService: TransactionService
    private let categoryService: CategoryService
    private let googleSheetsProvider: GoogleSheetsProvider
    
    init() {
        do {
            let modelContainer = try ModelContainer(
                for: Transaction.self,
                Category.self,
                Mutation.self,
                EntitySyncState.self
            )

            #if DEBUG
                SwiftDataDebugLogger.shared.install(
                    context: modelContainer.mainContext
                )
            #endif

            let mutationService = MutationService(
                modelContext: modelContainer.mainContext
            )

            let transactionService = TransactionService(
                modelContext: modelContainer.mainContext,
                mutationService: mutationService
            )

            let categoryService = CategoryService(
                modelContext: modelContainer.mainContext,
                mutationService: mutationService
            )

            self.modelContainer = modelContainer

            self.mutationService = mutationService
            self.transactionService = transactionService
            self.categoryService = categoryService
            
            let googleSheetsConfiguration =
            GoogleSheetsConfiguration.development
            
            let googleAuthorizationService =
            GoogleAuthorizationService(
                configuration: googleSheetsConfiguration
            )
            
            let googleSheetsClient =
            GoogleSheetsClient()
            
            let googleSheetsProvider =
            GoogleSheetsProvider(
                configuration: googleSheetsConfiguration,
                authorization: googleAuthorizationService,
                client: googleSheetsClient
            )
            self.googleSheetsProvider = googleSheetsProvider

        } catch {
            fatalError(
                "Failed to create SwiftData container: \(error)"
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(googleSheetsProvider: googleSheetsProvider)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(modelContainer)
        .environment(transactionService)
        .environment(categoryService)
    }
}
