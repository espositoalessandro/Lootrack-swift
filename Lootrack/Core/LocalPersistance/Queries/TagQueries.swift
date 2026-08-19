import SwiftData
import Foundation

enum TagQueries {
    static var byName: FetchDescriptor<Tag> {
        FetchDescriptor(
            sortBy: [
                SortDescriptor(\Tag.name)
            ]
        )
    }
}
