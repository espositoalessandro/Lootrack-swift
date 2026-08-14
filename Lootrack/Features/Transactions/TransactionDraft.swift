import Foundation

struct TransactionDraft {
    var note: String = ""
    var amount: String = ""
    var type: TransactionType = .expense

    var amountInCents: Int? {
        let normalized = amount.replacingOccurrences(of: ",", with: ".")

        guard let decimal = Decimal(string: normalized) else {
            return nil
        }

        return NSDecimalNumber(decimal: decimal * 100).intValue
    }
    
    init() {}
    
    init(transaction: Transaction) {
        note = transaction.note

        amount = NSDecimalNumber(
            value: transaction.amountInCents
        )
        .dividing(by: 100)
        .stringValue

        type = transaction.type
    }
}
