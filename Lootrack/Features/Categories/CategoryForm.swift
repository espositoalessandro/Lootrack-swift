import SwiftUI

struct CategoryForm: View {
    @Binding var draft: CategoryDraft

    var typeDisabled = false

    var body: some View {
        Form {
            Section("Category") {
                TextField("Name", text: $draft.name)

                Picker("Type", selection: $draft.type) {
                    Text("Expense")
                        .tag(TransactionType.expense)

                    Text("Income")
                        .tag(TransactionType.income)
                }
                .disabled(typeDisabled)
            }
        }
    }
}
