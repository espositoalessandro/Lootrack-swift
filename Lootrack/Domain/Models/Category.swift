import Foundation
import SwiftData

@Model
final class Category: Entity {
    @Attribute(.unique)
    var id: UUID

    var revision: Int?
    var lastMutationId: UUID?

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var type: TransactionType
    var name: String

    init(
        id: UUID = UUID(),
        revision: Int? = nil,
        lastMutationId: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        type: TransactionType,
        name: String
    ) {
        self.id = id

        self.revision = revision
        self.lastMutationId = lastMutationId

        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt

        self.type = type
        self.name = name
    }
}

struct CategoryDTO: Codable {
    let id: UUID
    
    let revision: Int?
    let lastMutationId: UUID?
    
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    
    let type: TransactionType
    let name: String
}

extension CategoryDTO {
    init(category: Category) {
        self.id = category.id
        self.revision = category.revision
        self.lastMutationId = category.lastMutationId
        self.createdAt = category.createdAt
        self.updatedAt = category.updatedAt
        self.deletedAt = category.deletedAt
        self.type = category.type
        self.name = category.name
        
    }
}
