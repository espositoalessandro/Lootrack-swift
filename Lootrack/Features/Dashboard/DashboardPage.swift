import SwiftData
import SwiftUI

struct Dashboard: View {
    @Environment(SyncCoordinator.self)
    private var syncCoordinator

    @Environment(AppSettings.self)
    private var settings

    @Query(TransactionQueries.active)
    private var transactions: [Transaction]

    private var currentMonthTransactions: [Transaction] {
        guard let interval =
            Calendar.current.dateInterval(of: .month,
                                          for: .now)
        else {
            return []
        }

        return transactions.filter {
            transaction in
            interval.contains(transaction.occurredOn)
        }
    }

    private var totalIncome: Int {
        currentMonthTransactions
            .filter {
                $0.type == .income
            }
            .reduce(0) {
                total,
                transaction in
                total
                    + transaction
                    .amountInCents
            }
    }

    private var totalExpenses: Int {
        currentMonthTransactions
            .filter {
                $0.type == .expense
            }
            .reduce(0) {
                total,
                transaction in
                total
                    + transaction
                    .amountInCents
            }
    }

    private var netTotal: Int {
        totalIncome - totalExpenses
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(Date.now,
                     format:
                     .dateTime
                         .month(.wide)
                         .year())
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity,
                           alignment: .leading)

                VStack(spacing: 8) {
                    Text("Net this month")
                        .foregroundStyle(.secondary)

                    Text(settings.formattedAmount(netTotal))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)

                Divider()

                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Label("Income",
                              systemImage:
                              "arrow.down")
                            .foregroundStyle(.green)

                        Text(settings
                            .formattedAmount(totalIncome))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 6) {
                        Label("Expenses",
                              systemImage:
                              "arrow.up")
                            .foregroundStyle(.red)

                        Text(settings
                            .formattedAmount(totalExpenses))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .refreshable {
            await syncCoordinator
                .synchronize()
        }
        .navigationTitle("Lootrack")
    }
}
