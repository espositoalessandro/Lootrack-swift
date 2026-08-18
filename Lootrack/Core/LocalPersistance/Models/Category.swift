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
    var note: String = ""

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        type: TransactionType,
        name: String,
        note: String = ""
    ) {
        self.id = id

        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt

        self.type = type
        self.name = name
        self.note = note
    }
}

extension Category {
    convenience init(_ snapshot: CategoryDTO) {
        self.init(
            id: snapshot.id,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt,
            deletedAt: snapshot.deletedAt,
            type: snapshot.type,
            name: snapshot.name,
            note: snapshot.note
        )
    }
    
    func apply(_ snapshot: CategoryDTO) {
        createdAt = snapshot.createdAt
        updatedAt = snapshot.updatedAt
        deletedAt = snapshot.deletedAt
        
        type = snapshot.type
        name = snapshot.name
        note = snapshot.note
    }
}

nonisolated struct CategoryDTO: Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let type: TransactionType
    let name: String
    let note: String
}

nonisolated extension CategoryDTO {
    @MainActor
    init(_ category: Category) {
        self.id = category.id
        self.createdAt = category.createdAt
        self.updatedAt = category.updatedAt
        self.deletedAt = category.deletedAt

        self.type = category.type
        self.name = category.name
        self.note = category.note
    }
}

// MARK: - Backward-compatible decoding

nonisolated extension CategoryDTO {
    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case updatedAt
        case deletedAt
        case type
        case name
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        id = try container.decode(
            UUID.self,
            forKey: .id
        )

        createdAt = try container.decode(
            Date.self,
            forKey: .createdAt
        )

        updatedAt = try container.decode(
            Date.self,
            forKey: .updatedAt
        )

        deletedAt = try container.decodeIfPresent(
            Date.self,
            forKey: .deletedAt
        )

        type = try container.decode(
            TransactionType.self,
            forKey: .type
        )

        name = try container.decode(
            String.self,
            forKey: .name
        )

        note =
            try container.decodeIfPresent(
                String.self,
                forKey: .note
            ) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            id,
            forKey: .id
        )

        try container.encode(
            createdAt,
            forKey: .createdAt
        )

        try container.encode(
            updatedAt,
            forKey: .updatedAt
        )

        try container.encodeIfPresent(
            deletedAt,
            forKey: .deletedAt
        )

        try container.encode(
            type,
            forKey: .type
        )

        try container.encode(
            name,
            forKey: .name
        )

        try container.encode(
            note,
            forKey: .note
        )
    }
}
