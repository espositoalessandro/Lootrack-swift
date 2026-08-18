import SwiftData
import SwiftUI

struct CategoryListView: View {
    @Environment(CategoryService.self)
    private var categoryService

    @Environment(\.undoManager)
    private var undoManager
    
    @Environment(SyncCoordinator.self)
    private var syncCoordinator
    
    @State
    private var showingAddCategory = false

    @State
    private var editingCategory: Category?

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
        .refreshable {
            await syncCoordinator.synchronize()
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
}
