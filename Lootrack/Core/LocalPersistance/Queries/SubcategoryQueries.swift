import Foundation
import SwiftData

enum SubcategoryQueries {
    static var activeByName: FetchDescriptor<Subcategory> {
        FetchDescriptor(
            predicate: #Predicate<Subcategory> { subcategory in
                subcategory.deletedAt == nil
            },
            sortBy: [
                SortDescriptor(\Subcategory.name)
            ]
        )
    }
}
