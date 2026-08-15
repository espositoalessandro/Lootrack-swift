import Foundation

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
