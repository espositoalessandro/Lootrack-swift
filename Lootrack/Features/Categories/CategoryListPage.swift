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

    @Query(SubcategoryQueries.activeByName)
    private var subcategories: [Subcategory]

    var body: some View {
        List {
            ForEach(categories) { category in
                let categorySubcategories =
                    subcategories.filter { subcategory in
                        subcategory.categoryId == category.id
                    }

                if categorySubcategories.isEmpty {
                    categoryRow(category)
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: false
                        ) {
                            deleteButton(category)
                        }
                        .swipeActions(
                            edge: .leading,
                            allowsFullSwipe: true
                        ) {
                            editButton(category)
                        }
                } else {
                    DisclosureGroup {
                        ForEach(categorySubcategories) { subcategory in
                            Text(subcategory.name)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    } label: {
                        categoryRow(category)
                    }
                    .swipeActions(
                        edge: .trailing,
                        allowsFullSwipe: false
                    ) {
                        deleteButton(category)
                    }
                    .swipeActions(
                        edge: .leading,
                        allowsFullSwipe: true
                    ) {
                        editButton(category)
                    }
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

    // MARK: - Rows

    private func categoryRow(
        _ category: Category
    ) -> some View {
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
    }

    // MARK: - Actions

    private func editButton(
        _ category: Category
    ) -> some View {
        Button(
            "Edit",
            systemImage: "pencil"
        ) {
            editingCategory = category
        }
        .tint(.blue)
    }

    private func deleteButton(
        _ category: Category
    ) -> some View {
        Button(
            "Delete",
            systemImage: "trash"
        ) {
            delete(category)
        }
        .tint(.red)
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
