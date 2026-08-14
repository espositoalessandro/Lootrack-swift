import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique)
    var id: UUID

    var revision: Int?
    var lastMutationId: String?

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var type: TransactionType
    var name: String

    init(
        id: UUID = UUID(),
        revision: Int? = nil,
        lastMutationId: String? = nil,
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
