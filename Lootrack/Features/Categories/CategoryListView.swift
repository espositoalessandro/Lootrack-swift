import SwiftUI
import SwiftData

struct CategoryListView: View {
    @Environment(CategoryService.self) private var categoryService

    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    
    @Query(CategoryQueries.activeByName)
    private var categories: [Category]

    var body: some View {
        List {
            ForEach(categories) { category in
                HStack {
                    Text(category.name)

                    Spacer()

                    Text(category.type == .expense ? "Expense" : "Income")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())

                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(
                        "Delete",
                        systemImage: "trash",
                    ) {
                        do {
                            try categoryService.delete(category)
                        } catch {
                            print("FAILED TO DELETE CATEGORY:", error)
                        }
                    }.tint(.red)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button("Edit", systemImage: "pencil") {
                        editingCategory = category
                    }.tint(.blue)
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
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
    }
}
