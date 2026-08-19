import SwiftData
import SwiftUI

private enum CategoryListFilter: CaseIterable {
    case all
    case expense
    case income

    var label: String {
        switch self {
        case .all:
            return String(localized: "All")

        case .expense:
            return String(localized: "Expenses")

        case .income:
            return String(localized: "Income")
        }
    }
}

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

    @State
    private var selectedFilter: CategoryListFilter = .all

    @Query(CategoryQueries.activeByName)
    private var categories: [Category]

    @Query(SubcategoryQueries.activeByName)
    private var subcategories: [Subcategory]

    private var filteredCategories: [Category] {
        categories.filter { category in
            switch selectedFilter {
            case .all:
                true

            case .expense:
                category.type == .expense

            case .income:
                category.type == .income
            }
        }
    }

    var body: some View {
        List {
            Picker(
                "Category type",
                selection: $selectedFilter
            ) {
                ForEach(
                    CategoryListFilter.allCases,
                    id: \.self
                ) { filter in
                    Text(filter.label)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(
                EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: 0,
                    trailing: 0
                )
            )
            .listRowBackground(
                Color(uiColor: .systemGroupedBackground)
            )
            .listRowSeparator(.hidden)
            
            Section {
                ForEach(filteredCategories) { category in
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
