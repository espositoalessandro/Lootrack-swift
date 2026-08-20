import Foundation
import SwiftData

nonisolated enum TransactionType: String, Codable, Equatable {
    case expense
    case income
}

@Model
final class Transaction: Entity {
    @Attribute(.unique)
    var id: UUID

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var type: TransactionType
    var amountInCents: Int
    var note: String
    var occurredOn: Date
    var categoryId: UUID?
    var subcategoryId: UUID?
    var tags: [String] = []

    init(id: UUID = UUID(),
         createdAt: Date = .now,
         updatedAt: Date = .now,
         deletedAt: Date? = nil,
         type: TransactionType,
         amountInCents: Int,
         note: String,
         occurredOn: Date,
         categoryId: UUID? = nil,
         subcategoryId: UUID? = nil,
         tags: [String] = [])
    {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.type = type
        self.amountInCents = amountInCents
        self.note = note
        self.occurredOn = occurredOn
        self.categoryId = categoryId
        self.subcategoryId = subcategoryId
        self.tags = Tag.normalizedTags(tags)
    }
}

extension Transaction {
    convenience init(_ snapshot: TransactionDTO) {
        self.init(id: snapshot.id,
                  createdAt: snapshot.createdAt,
                  updatedAt: snapshot.updatedAt,
                  deletedAt: snapshot.deletedAt,
                  type: snapshot.type,
                  amountInCents: snapshot.amountInCents,
                  note: snapshot.note,
                  occurredOn: snapshot.occurredOn,
                  categoryId: snapshot.categoryId,
                  subcategoryId: snapshot.subcategoryId,
                  tags: snapshot.tags)
    }

    func apply(_ snapshot: TransactionDTO) {
        createdAt = snapshot.createdAt
        updatedAt = snapshot.updatedAt
        deletedAt = snapshot.deletedAt

        type = snapshot.type
        amountInCents = snapshot.amountInCents
        note = snapshot.note
        occurredOn = snapshot.occurredOn
        categoryId = snapshot.categoryId
        subcategoryId = snapshot.subcategoryId
        tags = Tag.normalizedTags(snapshot.tags)
    }
}

nonisolated struct TransactionDTO: Codable, Equatable {
    let id: UUID

    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    let type: TransactionType
    let amountInCents: Int
    let note: String
    let occurredOn: Date
    let categoryId: UUID?
    let subcategoryId: UUID?
    let tags: [String]
}

extension TransactionDTO {
    @MainActor
    init(_ transaction: Transaction) {
        id = transaction.id
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
        deletedAt = transaction.deletedAt

        type = transaction.type
        amountInCents = transaction.amountInCents
        note = transaction.note
        occurredOn = transaction.occurredOn
        categoryId = transaction.categoryId
        subcategoryId = transaction.subcategoryId
        tags = Tag.normalizedTags(transaction.tags)
    }
}

// MARK: - Backward-compatible decoding

nonisolated extension TransactionDTO {
    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case updatedAt
        case deletedAt
        case type
        case amountInCents
        case note
        case occurredOn
        case categoryId
        case subcategoryId
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self,
                                  forKey: .id)

        createdAt = try container.decode(Date.self,
                                         forKey: .createdAt)

        updatedAt = try container.decode(Date.self,
                                         forKey: .updatedAt)

        deletedAt = try container.decodeIfPresent(Date.self,
                                                  forKey: .deletedAt)

        type = try container.decode(TransactionType.self,
                                    forKey: .type)

        amountInCents = try container.decode(Int.self,
                                             forKey: .amountInCents)

        note = try container.decode(String.self,
                                    forKey: .note)

        occurredOn = try container.decode(Date.self,
                                          forKey: .occurredOn)

        categoryId = try container.decodeIfPresent(UUID.self,
                                                   forKey: .categoryId)

        subcategoryId = try container.decodeIfPresent(UUID.self,
                                                      forKey: .subcategoryId)

        tags = try Tag.normalizedTags(container.decodeIfPresent([String].self,
                                                                forKey: .tags) ?? [])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id,
                             forKey: .id)

        try container.encode(createdAt,
                             forKey: .createdAt)

        try container.encode(updatedAt,
                             forKey: .updatedAt)

        try container.encodeIfPresent(deletedAt,
                                      forKey: .deletedAt)

        try container.encode(type,
                             forKey: .type)

        try container.encode(amountInCents,
                             forKey: .amountInCents)

        try container.encode(note,
                             forKey: .note)

        try container.encode(occurredOn,
                             forKey: .occurredOn)

        try container.encodeIfPresent(categoryId,
                                      forKey: .categoryId)

        try container.encodeIfPresent(subcategoryId,
                                      forKey: .subcategoryId)

        try container.encode(Tag.normalizedTags(tags),
                             forKey: .tags)
    }
}
