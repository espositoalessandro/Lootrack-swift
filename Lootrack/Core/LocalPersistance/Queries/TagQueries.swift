import Foundation
import SwiftData

enum TagQueries {
    static var byName: FetchDescriptor<Tag> {
        FetchDescriptor(sortBy: [SortDescriptor(\Tag.name)])
    }
}
