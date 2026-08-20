import Foundation
import SwiftData

enum TransactionQueries {
    static var active: FetchDescriptor<Transaction> {
        FetchDescriptor(predicate: #Predicate<Transaction> { transaction in
            transaction.deletedAt == nil
        })
    }

    static var activeByMostRecent: FetchDescriptor<Transaction> {
        FetchDescriptor(predicate: #Predicate<Transaction> { transaction in
            transaction.deletedAt == nil
        },
        sortBy: [SortDescriptor(\Transaction.occurredOn,
                                order: .reverse)])
    }
}
