import Foundation

nonisolated protocol Entity: Identifiable {
    var id: UUID { get }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}

nonisolated protocol ImmutableEntity: Identifiable {
    var id: UUID { get }
    var createdAt: Date { get }
}
