import SwiftUI

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CategoryService.self) private var categoryService

    @State private var draft = CategoryDraft()
    @State private var error: CategoryServiceError?

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
        .alert(error: $error) { _ in
            Button("OK") {}
        } message: { error in
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
            }
        }
    }

    private func save() {
        do {
            try categoryService.create(name: draft.name, type: draft.type, note: draft.note)
            dismiss()
        } catch {
            self.error = error as? CategoryServiceError ?? .couldNotCreate
        }
    }
}
