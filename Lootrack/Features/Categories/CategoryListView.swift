import SwiftData
import SwiftUI

struct CategoryListView: View {
    @Environment(CategoryService.self)
    private var categoryService

    @Environment(\.undoManager)
    private var undoManager

    @State
    private var showingAddCategory = false

    @State
    private var editingCategory: Category?

    @State
    private var snackbarNotification: SnackbarNotification?

    @Query(CategoryQueries.activeByName)
    private var categories: [Category]

    var body: some View {
        List {
            ForEach(categories) { category in
                HStack {
                    Text(category.name)

                    Spacer()

                    Text(
                        category.type == .expense
                            ? "Expense"
                            : "Income"
                    )
                    .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .swipeActions(
                    edge: .trailing,
                    allowsFullSwipe: false
                ) {
                    Button(
                        "Delete",
                        systemImage: "trash"
                    ) {
                        delete(category)
                    }
                    .tint(.red)
                }
                .swipeActions(
                    edge: .leading,
                    allowsFullSwipe: true
                ) {
                    Button(
                        "Edit",
                        systemImage: "pencil"
                    ) {
                        editingCategory = category
                    }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(
                placement: .primaryAction
            ) {
                Button(
                    "Add",
                    systemImage: "plus"
                ) {
                    showingAddCategory = true
                }
            }
        }
        .snackbar(
            notification:
                $snackbarNotification,
            position: .bottom,
            edgePadding: 12,
            duration: .seconds(5)
        )
        .sheet(
            isPresented: $showingAddCategory
        ) {
            AddCategoryView()
        }
        .sheet(
            item: $editingCategory
        ) { category in
            EditCategoryView(
                category: category
            )
        }
    }

    private func delete(
        _ category: Category
    ) {
        do {
            try categoryService.delete(category)

            registerUndo(for: category)

            snackbarNotification =
                SnackbarNotification(
                    message: String(
                        localized:
                            "Category deleted"
                    ),
                    style: .danger,
                    icon: "trash.fill",
                    actionTitle: String(
                        localized: "Undo"
                    ),
                    action: {
                        restore(category)
                    }
                )
        } catch {
            print(
                "FAILED TO DELETE CATEGORY:",
                error
            )
        }
    }

    private func registerUndo(
        for category: Category
    ) {
        guard let undoManager else {
            return
        }

        /*
         * We only keep one accidental-delete
         * undo for this service.
         */
        undoManager.removeAllActions(
            withTarget: categoryService
        )

        undoManager.registerUndo(
            withTarget: categoryService
        ) { service in
            do {
                try service.restore(category)
            } catch {
                print(
                    "FAILED TO UNDO CATEGORY DELETE:",
                    error
                )
            }
        }

        undoManager.setActionName(
            String(localized: "Delete Category")
        )
    }

    private func restore(
        _ category: Category
    ) {
        do {
            try categoryService.restore(
                category
            )

            undoManager?
                .removeAllActions(
                    withTarget:
                        categoryService
                )
        } catch {
            print(
                "FAILED TO RESTORE CATEGORY:",
                error
            )
        }
    }
}
