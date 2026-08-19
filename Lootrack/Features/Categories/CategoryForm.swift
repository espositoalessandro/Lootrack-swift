import SwiftUI

struct CategoryForm: View {
    @Binding var draft: CategoryDraft

    var typeDisabled = false

    private let subcategories: Binding<[SubcategoryDraft]>?

    @State
    private var newSubcategoryName = ""

    init(
        draft: Binding<CategoryDraft>,
        typeDisabled: Bool = false,
        subcategories:
            Binding<[SubcategoryDraft]>? = nil
    ) {
        self._draft = draft
        self.typeDisabled = typeDisabled
        self.subcategories = subcategories
    }

    var body: some View {
        Form {
            Section("Category") {
                TextField(
                    "Name",
                    text: $draft.name
                )

                Picker(
                    "Type",
                    selection: $draft.type
                ) {
                    Text("Expense")
                        .tag(TransactionType.expense)

                    Text("Income")
                        .tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                .disabled(typeDisabled)

                TextField(
                    "Note",
                    text: $draft.note,
                    axis: .vertical
                )
                .lineLimit(2...5)
            }

            if let subcategories {
                Section {
                    ForEach(
                        subcategories
                    ) { $subcategory in
                        TextField(
                            "Subcategory",
                            text: $subcategory.name
                        )
                    }
                    .onDelete { offsets in
                        subcategories
                            .wrappedValue
                            .remove(
                                atOffsets: offsets
                            )
                    }

                    HStack {
                        TextField(
                            "New subcategory",
                            text: $newSubcategoryName
                        )
                        .submitLabel(.done)
                        .onSubmit {
                            addSubcategory(
                                to: subcategories
                            )
                        }

                        Button {
                            addSubcategory(
                                to: subcategories
                            )
                        } label: {
                            Image(
                                systemName:
                                    "plus.circle.fill"
                            )
                        }
                        .buttonStyle(.borderless)
                        .disabled(
                            !canAddSubcategory(
                                to: subcategories
                            )
                        )
                    }
                } header: {
                    Text("Subcategories")
                } footer: {
                    Text(
                        "Names must be unique within this category."
                    )
                }
            }
        }
    }

    private func canAddSubcategory(
        to subcategories:
            Binding<[SubcategoryDraft]>
    ) -> Bool {
        let name =
            newSubcategoryName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !name.isEmpty else {
            return false
        }

        let key = normalizedName(name)

        return !subcategories
            .wrappedValue
            .contains { subcategory in
                normalizedName(
                    subcategory.name
                ) == key
            }
    }

    private func addSubcategory(
        to subcategories:
            Binding<[SubcategoryDraft]>
    ) {
        guard
            canAddSubcategory(
                to: subcategories
            )
        else {
            return
        }

        let name =
            newSubcategoryName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        subcategories
            .wrappedValue
            .append(
                SubcategoryDraft(
                    name: name
                )
            )

        newSubcategoryName = ""
    }

    private func normalizedName(
        _ name: String
    ) -> String {
        name
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
    }
}
