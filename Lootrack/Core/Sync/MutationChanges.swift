import Foundation

nonisolated enum MutationValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case date(Date)
    case uuid(UUID)
    case transactionType(TransactionType)
    case null
}

nonisolated struct MutationChange: Codable {
    let field: String
    let before: MutationValue
    let after: MutationValue
}

extension MutationChange {
    static func ifChanged(
        field: String,
        from before: MutationValue,
        to after: MutationValue
    ) -> MutationChange? {
        guard before != after else {
            return nil
        }

        return MutationChange(
            field: field,
            before: before,
            after: after
        )
    }

    static func createChanges<T: Entity>(from old: T?, to new: T) {
        switch new {
        case let transaction as Transaction:
            break
        case let category as Category:
            break
        default:
            fatalError("Unsupported entity type: \(type(of: new))")
        }
    }
}

nonisolated protocol MutationSnapshot {
    func changes(to new: Self) -> [MutationChange]
    var creationChanges: [MutationChange] { get }
}

extension TransactionDTO: MutationSnapshot {
    func changes(to new: TransactionDTO) -> [MutationChange] {
        [
            MutationChange.ifChanged(
                field: "type",
                from: .transactionType(type),
                to: .transactionType(new.type)
            ),
            MutationChange.ifChanged(
                field: "amountInCents",
                from: .int(amountInCents),
                to: .int(new.amountInCents)
            ),
            // ...
        ]
        .compactMap { $0 }
    }

    var creationChanges: [MutationChange] {
        [
            .init(
                field: "createdAt",
                before: .null,
                after: .date(createdAt)
            )
            // ...
        ]
    }
}

extension CategoryDTO: MutationSnapshot {
    func changes(to new: CategoryDTO) -> [MutationChange] {
        [
            MutationChange.ifChanged(
                field: "type",
                from: .transactionType(type),
                to: .transactionType(new.type)
            )
            // ...
        ]
        .compactMap { $0 }
    }

    var creationChanges: [MutationChange] {
        [
            .init(
                field: "createdAt",
                before: .null,
                after: .date(createdAt)
            )
            // ...
        ]
    }
}
