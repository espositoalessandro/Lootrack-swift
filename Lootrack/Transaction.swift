import Foundation
import SwiftData

enum TransactionType: String, Codable {
    case expense
    case income
}

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID

    var type: TransactionType
    var amountInCents: Int
    var note: String
    var occurredOn: Date

    init(
        id: UUID = UUID(),
        type: TransactionType,
        amountInCents: Int,
        note: String,
        occurredOn: Date
    ) {
        self.id = id
        self.type = type
        self.amountInCents = amountInCents
        self.note = note
        self.occurredOn = occurredOn
    }
}
