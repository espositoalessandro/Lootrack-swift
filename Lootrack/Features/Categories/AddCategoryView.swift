
import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Environment(CategoryService.self)
    private var categoryService
    
    @State private var draft = CategoryDraft()

    var body: some View {
        NavigationStack {
            CategoryForm(draft: $draft)
                .navigationTitle("New Category")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            save()
                        }
                        .disabled(draft.name.isEmpty)
                    }
                }
        }
    }

    private func save() {
        do {
            try categoryService.create(
                name: draft.name,
                type: draft.type
            )
            dismiss()
        } catch {
            print("FAILED TO CREATE CATEGORY:", error)
        }
    }
}
