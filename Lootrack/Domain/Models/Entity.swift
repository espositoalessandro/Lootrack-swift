import Foundation

protocol Entity: Identifiable {
    var id: UUID { get }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}
