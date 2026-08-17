import SwiftData
import Foundation

enum CategoryQueries {
    static var activeByName: FetchDescriptor<Category> {
        FetchDescriptor(
            predicate: #Predicate<Category> { category in
                category.deletedAt == nil
            },
            sortBy: [
                SortDescriptor(\Category.name)
            ]
        )
    }
}
