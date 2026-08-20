import Foundation
import SwiftData

@Model
final class Subcategory: Entity {
    @Attribute(.unique)
    var id: UUID

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var categoryId: UUID
    var name: String

    init(id: UUID = UUID(),
         createdAt: Date = .now,
         updatedAt: Date = .now,
         deletedAt: Date? = nil,
         categoryId: UUID,
         name: String)
    {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.categoryId = categoryId
        self.name = name
    }
}

extension Subcategory {
    convenience init(_ snapshot: SubcategoryDTO) {
        self.init(id: snapshot.id,
                  createdAt: snapshot.createdAt,
                  updatedAt: snapshot.updatedAt,
                  deletedAt: snapshot.deletedAt,
                  categoryId: snapshot.categoryId,
                  name: snapshot.name)
    }

    func apply(_ snapshot: SubcategoryDTO) {
        createdAt = snapshot.createdAt
        updatedAt = snapshot.updatedAt
        deletedAt = snapshot.deletedAt

        categoryId = snapshot.categoryId
        name = snapshot.name
    }
}

nonisolated struct SubcategoryDTO: Codable, Equatable {
    let id: UUID

    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    let categoryId: UUID
    let name: String
}

nonisolated extension SubcategoryDTO {
    @MainActor
    init(_ subcategory: Subcategory) {
        id = subcategory.id
        createdAt = subcategory.createdAt
        updatedAt = subcategory.updatedAt
        deletedAt = subcategory.deletedAt

        categoryId = subcategory.categoryId
        name = subcategory.name
    }
}
