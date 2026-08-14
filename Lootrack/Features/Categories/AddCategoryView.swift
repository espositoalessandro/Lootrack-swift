//
//  AddCategoryView.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 14/08/2026.
//


import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
        let category = Category(
            type: draft.type,
            name: draft.name
        )

        modelContext.insert(category)
        dismiss()
    }
}