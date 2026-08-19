import Foundation

struct SubcategoryDraft: Identifiable, Equatable {
    let id: UUID
    var name: String

    init(
        id: UUID = UUID(),
        name: String
    ) {
        self.id = id
        self.name = name
    }

    init(
        subcategory: Subcategory
    ) {
        self.id = subcategory.id
        self.name = subcategory.name
    }
}
