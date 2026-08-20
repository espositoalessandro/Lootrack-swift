import Foundation

struct SubcategoryDraft: Identifiable, Equatable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(),
         name: String)
    {
        self.id = id
        self.name = name
    }

    init(subcategory: Subcategory) {
        id = subcategory.id
        name = subcategory.name
    }
}
