import Foundation

nonisolated protocol Entity: Identifiable, Syncable {
    var id: UUID { get }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}
