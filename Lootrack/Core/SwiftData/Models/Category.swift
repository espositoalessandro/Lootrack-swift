import Foundation
import SwiftData

@Model
final class Category: Entity {
    @Attribute(.unique)
    var id: UUID

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var type: TransactionType
    var name: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        type: TransactionType,
        name: String
    ) {
        self.id = id

        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt

        self.type = type
        self.name = name
    }
}

nonisolated struct CategoryDTO: Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let type: TransactionType
    let name: String
}

extension CategoryDTO {
    @MainActor
    init(_ category: Category) {
        self.id = category.id
        self.createdAt = category.createdAt
        self.updatedAt = category.updatedAt
        self.deletedAt = category.deletedAt
        self.type = category.type
        self.name = category.name
    }
}
