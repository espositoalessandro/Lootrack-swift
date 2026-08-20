import SwiftData
import SwiftUI

private enum CategoryListFilter: CaseIterable {
    case all
    case expense
    case income

    var label: String {
        switch self {
        case .all:
            String(localized: "All")

        case .expense:
            String(localized: "Expenses")

        case .income:
            String(localized: "Income")
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

    @State
    private var error: CategoryServiceError?

    @Query(CategoryQueries.activeByName)
    private var categories: [Category]

    @Query(SubcategoryQueries.activeByName)
    private var subcategories: [Subcategory]

    private var filteredCategories: [Category] {
        categories.filter { category in
            matchesFilter(category)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading,
                       spacing: 0)
            {
                filterPicker

                ForEach(filteredCategories) { category in
                    categoryRow(category)
                        .padding(.bottom,
                                 8)
                }
            }
            .padding(.bottom,
                     16)
        }
        .refreshable {
            await syncCoordinator
                .synchronize()
        }
        .swipeActionsContainer()
        .background(Color(uiColor:
            .systemGroupedBackground))
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add",
                       systemImage: "plus")
                {
                    showingAddCategory = true
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
        .sheet(item: $editingCategory) { category in
            EditCategoryView(category: category)
        }
        .alert(error: $error) { _ in Button("OK") {}
        } message: { error in
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
            }
        }
    }

    // MARK: - Filter

    private var filterPicker: some View {
        Picker("Category type",
               selection:
               $selectedFilter)
        {
            ForEach(CategoryListFilter
                .allCases,
                id: \.self)
            { filter in
                Text(filter.label)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal,
                 16)
        .padding(.top,
                 8)
        .padding(.bottom,
                 18)
    }

    private func matchesFilter(_ category: Category) -> Bool {
        switch selectedFilter {
        case .all:
            true

        case .expense:
            category.type
                == .expense

        case .income:
            category.type
                == .income
        }
    }

    // MARK: - Rows

    private func categoryRow(_ category: Category) -> some View {
        let categorySubcategories =
            subcategories.filter {
                $0.categoryId
                    == category.id
            }

        return CategoryRow(category: category,
                           subcategories:
                           categorySubcategories,
                           onEdit: {
                               editingCategory =
                                   category
                           },
                           onDelete: {
                               delete(category)
                           })
    }

    // MARK: - Delete

    private func delete(_ category: Category) {
        do {
            try categoryService.delete(category)
            registerUndo(for: category)
        } catch {
            self.error = error as? CategoryServiceError ?? .couldNotDelete
        }
    }
    
    private func registerUndo(for category: Category) {
        guard let undoManager else {
            return
        }
        
        undoManager.removeAllActions(withTarget: categoryService)
        
        undoManager.registerUndo(withTarget: categoryService) { service in
            do {
                try service.restore(category)
            } catch {
                self.error = error as? CategoryServiceError ?? .couldNotRestore
            }
        }
        
        undoManager.setActionName(String(localized: "Delete Category"))
    }
}
