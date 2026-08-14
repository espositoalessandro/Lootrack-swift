import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(
        filter: #Predicate<Transaction> { transaction in
            transaction.deletedAt == nil
        }
    )
    private var transactions: [Transaction]
    private var currentMonthTransactions: [Transaction] {
        guard let interval = Calendar.current.dateInterval(
            of: .month,
            for: .now
        ) else {
            return []
        }

        return transactions.filter { transaction in
            interval.contains(transaction.occurredOn)
        }
    }
    private var totalIncome: Int {
        currentMonthTransactions
            .filter { $0.type == .income }
            .reduce(0) { total, transaction in
                total + transaction.amountInCents
            }
    }

    private var totalExpenses: Int {
        currentMonthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { total, transaction in
                total + transaction.amountInCents
            }
    }

    private var netTotal: Int {
        totalIncome - totalExpenses
    }
    
    private func formattedAmount(_ cents: Int) -> String {
        (Double(cents) / 100)
            .formatted(.currency(code: "EUR"))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(Date.now.formatted(.dateTime.month(.wide).year()))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    Text("Net this month")
                        .foregroundStyle(.secondary)

                    Text(formattedAmount(netTotal))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)

                Divider()

                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Label("Income", systemImage: "arrow.down")
                            .foregroundStyle(.green)

                        Text(formattedAmount(totalIncome))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 6) {
                        Label("Expenses", systemImage: "arrow.up")
                            .foregroundStyle(.red)

                        Text(formattedAmount(totalExpenses))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("Lootrack")
    }
}
