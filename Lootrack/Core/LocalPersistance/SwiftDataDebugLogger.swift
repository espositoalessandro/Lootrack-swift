#if DEBUG

    import Foundation
    import SwiftData

    @MainActor
    final class SwiftDataDebugLogger:
        NSObject
    {
        static let shared =
            SwiftDataDebugLogger()

        private var installed =
            false

        private override init() {
            super.init()
        }

        func install(
            context: ModelContext
        ) {
            guard !installed else {
                return
            }

            installed = true

            NotificationCenter.default
                .addObserver(
                    self,
                    selector:
                        #selector(
                            willSave(_:)
                        ),
                    name:
                        ModelContext
                        .willSave,
                    object: context
                )

            NotificationCenter.default
                .addObserver(
                    self,
                    selector:
                        #selector(
                            didSave(_:)
                        ),
                    name:
                        ModelContext
                        .didSave,
                    object: context
                )

            print(
                "🗄️ SwiftData debugger installed"
            )
        }

        @objc
        private func willSave(
            _ notification:
                Notification
        ) {
            guard
                let context =
                    notification.object
                    as? ModelContext
            else {
                return
            }

            print("")
            print(
                "🟡 ───── SwiftData WILL SAVE ─────"
            )

            log(
                context
                    .insertedModelsArray,
                prefix: "➕ INSERT"
            )

            log(
                context
                    .changedModelsArray,
                prefix: "✏️ UPDATE"
            )

            log(
                context
                    .deletedModelsArray,
                prefix: "🗑️ DELETE"
            )

            print(
                "─────────────────────────────────"
            )
        }

        @objc
        private func didSave(
            _ notification:
                Notification
        ) {
            print(
                "🟢 SwiftData DID SAVE"
            )
            print("")
        }

        private func log(
            _ models:
                [any PersistentModel],
            prefix: String
        ) {
            guard !models.isEmpty else {
                return
            }

            print(
                "\(prefix) [\(models.count)]"
            )

            for model in models {
                print(
                    "   \(describe(model))"
                )
            }
        }

        private func describe(
            _ model:
                any PersistentModel
        ) -> String {
            switch model {
            case let transaction
                as Transaction:
                return """
                    Transaction(
                        id: \(transaction.id),
                        type: \(transaction.type),
                        amountInCents: \(transaction.amountInCents),
                        note: "\(transaction.note)",
                        occurredOn: \(transaction.occurredOn),
                        categoryId: \(String(describing: transaction.categoryId)),
                        subcategoryId: \(String(describing: transaction.subcategoryId)),
                        deletedAt: \(String(describing: transaction.deletedAt))
                    )
                    """

            case let category
                as Category:
                return """
                    Category(
                        id: \(category.id),
                        type: \(category.type),
                        name: "\(category.name)",
                        deletedAt: \(String(describing: category.deletedAt))
                    )
                    """

            case let subcategory
                as Subcategory:
                return """
                    Subcategory(
                        id: \(subcategory.id),
                        categoryId: \(subcategory.categoryId),
                        name: "\(subcategory.name)",
                        deletedAt: \(String(describing: subcategory.deletedAt))
                    )
                    """

            case let mutation
                as Mutation:
                return """
                    Mutation(
                        id: \(mutation.id),
                        operation: \(mutation.operation),
                        expectedRevision: \(String(describing: mutation.expectedRevision)),
                        expectedMutationId: \(String(describing: mutation.expectedMutationId))
                    )
                    """

            case let state
                as EntitySyncState:
                return """
                    EntitySyncState(
                        entityId: \(state.entityId),
                        entityType: \(state.entityType),
                        revision: \(state.revision),
                        lastMutationId: \(String(describing: state.lastMutationId))
                    )
                    """

            default:
                return """
                    \(String(describing: type(of: model)))(
                        persistentModelID: \(model.persistentModelID)
                    )
                    """
            }
        }
    }

#endif
