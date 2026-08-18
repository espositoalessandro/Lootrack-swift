import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct LootrackApp: App {
    private let modelContainer: ModelContainer

    private let mutationService: MutationService
    private let transactionService: TransactionService
    private let categoryService: CategoryService
    private let syncEngine: SyncEngine

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
            let localSyncStore = LocalSyncStore(
                modelContext: modelContainer.mainContext
            )

            let syncEngine = SyncEngine(
                localStore: localSyncStore,
                provider: googleSheetsProvider
            )

            self.syncEngine = syncEngine
        } catch {
            fatalError(
                "Failed to create SwiftData container: \(error)"
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                syncEngine: syncEngine
            ).onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .modelContainer(modelContainer)
        .environment(transactionService)
        .environment(categoryService)
    }
}
