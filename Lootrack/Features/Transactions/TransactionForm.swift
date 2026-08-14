import SwiftUI
import SwiftData

struct TransactionForm: View {
    @Binding var draft: TransactionDraft
    
    @Query(
        filter: #Predicate<Category> { category in
            category.deletedAt == nil
        },
        sort: \Category.name
    )
    private var categories: [Category]

    private var matchingCategories: [Category] {
        categories.filter { category in
            category.type == draft.type
        }
    }
    
    var body: some View {
        Form {
            Section("Transaction") {
                TextField("Description", text: $draft.note)

                TextField("Amount", text: $draft.amount)
                    .keyboardType(.decimalPad)

                Picker("Type", selection: $draft.type) {
                    Text("Expense")
                        .tag(TransactionType.expense)

                    Text("Income")
                        .tag(TransactionType.income)
                }
                Picker("Category", selection: $draft.categoryId) {
                    Text("Uncategorized")
                        .tag(UUID?.none)

                    ForEach(matchingCategories) { category in
                        Text(category.name)
                            .tag(Optional(category.id))
                    }
                }
                .onChange(of: draft.type) {
                    draft.categoryId = nil
                }
                DatePicker("Occurred on", selection: $draft.occurredOn)
            }
        }
    }
}
