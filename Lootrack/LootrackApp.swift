import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct LootrackApp: App {
    private let modelContainer: ModelContainer

    private let mutationService: MutationService
    private let tagService: TagService
    private let transactionService: TransactionService
    private let categoryService: CategoryService
    private let subcategoryService: SubcategoryService
    private let syncCoordinator: SyncCoordinator
    private let appSettings: AppSettings

    init() {
        appSettings = AppSettings()

        do {
            let modelContainer = try ModelContainer(for:
                Transaction.self,
                Category.self,
                Subcategory.self,
                Tag.self,
                Mutation.self,
                EntitySyncState.self)

            #if DEBUG
                SwiftDataDebugLogger.shared
                    .install(context: modelContainer.mainContext)
            #endif

            let mutationService = MutationService(modelContext: modelContainer.mainContext)

            let tagService = TagService(modelContext: modelContainer.mainContext)

            let transactionService = TransactionService(modelContext: modelContainer.mainContext,
                                                        mutationService: mutationService,
                                                        tagService: tagService)

            let categoryService = CategoryService(modelContext: modelContainer.mainContext,
                                                  mutationService: mutationService)

            let subcategoryService = SubcategoryService(modelContext: modelContainer.mainContext,
                                                        mutationService: mutationService)

            let conflictResolutionService = ConflictResolutionService(modelContext: modelContainer.mainContext,
                                                                      mutationService: mutationService,
                                                                      tagService: tagService)

            self.modelContainer = modelContainer
            self.mutationService = mutationService
            self.tagService = tagService
            self.transactionService = transactionService
            self.categoryService = categoryService
            self.subcategoryService = subcategoryService

            let googleSheetsConfiguration = GoogleSheetsConfiguration
                .development

            let googleAuthorizationService = GoogleAuthorizationService(configuration: googleSheetsConfiguration)

            let googleSheetsClient = GoogleSheetsClient()

            let googleSheetsProvider = GoogleSheetsProvider(configuration: googleSheetsConfiguration,
                                                            authorization: googleAuthorizationService,
                                                            client: googleSheetsClient)

            let localSyncStore = LocalSyncStore(modelContext: modelContainer.mainContext,
                                                tagService: tagService)

            let syncEngine = SyncEngine(localStore: localSyncStore,
                                        provider: googleSheetsProvider)

            syncCoordinator = SyncCoordinator(syncEngine: syncEngine,
                                              conflictResolutionService: conflictResolutionService)

            /*
             * The Tag table is a derived local cache.
             * Rebuilding once at launch makes it self-healing.
             */
            tagService.rebuild()
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            SettingsAwareRootView()
                .environment(syncCoordinator)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance
                        .handle(url)
                }
        }
        .modelContainer(modelContainer)
        .environment(transactionService)
        .environment(categoryService)
        .environment(subcategoryService)
        .environment(tagService)
        .environment(appSettings)
    }
}

private struct SettingsAwareRootView: View {
    @Environment(AppSettings.self)
    private var settings

    var body: some View {
        RootView()
            .environment(\.locale, settings.resolvedLocale)
    }
}
