struct CategoryDraft {
    var name = ""
    var note = ""
    var type: TransactionType = .expense

    init() {}

    init(category: Category) {
        name = category.name
        note = category.note
        type = category.type
    }
}
