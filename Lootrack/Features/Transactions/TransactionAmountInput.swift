import Foundation
import SwiftUI

struct TransactionAmountInput: View {
    @Binding var amount: String

    let focus: FocusState<TransactionFormField?>.Binding

    @State private var rawDigits = ""

    @Environment(AppSettings.self)
    private var settings

    private var amountInCents: Int {
        Int(rawDigits) ?? 0
    }

    private var integerPart: String {
        String(amountInCents / 100)
    }

    private var decimalPart: String {
        String(
            format: "%02d",
            amountInCents % 100
        )
    }

    private var decimalSeparator: String {
        settings.decimalSeparator
    }

    private var inputBinding: Binding<String> {
        Binding(
            get: {
                rawDigits
            },
            set: { newValue in
                let digits = newValue.filter(\.isNumber)

                // More than enough for a personal-finance transaction,
                // and prevents overflowing Int through pathological input.
                rawDigits = String(digits.suffix(11))

                updateAmount()
            }
        )
    }

    var body: some View {
        ZStack {
            // The actual text field exists only to receive keyboard input.
            //
            // The user never interacts with its textual representation:
            // the formatted amount below is the real UI.
            TextField(
                "",
                text: inputBinding
            )
            .keyboardType(.numberPad)
            .focused(
                focus,
                equals: .amount
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)

            HStack(
                alignment: .firstTextBaseline,
                spacing: 2
            ) {
                Text(integerPart)
                    .font(
                        .system(
                            size: 56,
                            weight: .semibold,
                            design: .rounded
                        )
                    )

                Text(decimalSeparator)
                    .font(
                        .system(
                            size: 40,
                            weight: .medium,
                            design: .rounded
                        )
                    )

                Text(decimalPart)
                    .font(
                        .system(
                            size: 40,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.secondary)

                Text(
                    settings.resolvedCurrencySymbol
                ).font(
                    .system(
                        size: 24,
                        weight: .medium,
                        design: .rounded
                    )
                )
                .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .contentShape(Rectangle())
            .onTapGesture {
                focus.wrappedValue = .amount
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 100
        )
        .onAppear {
            loadInitialAmount()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Amount")
        .accessibilityValue(
            settings.formattedAmount(
                amountInCents
            )
        )
    }

    private func updateAmount() {
        guard !rawDigits.isEmpty else {
            amount = ""
            return
        }

        let cents = amountInCents

        amount = String(
            format: "%d.%02d",
            cents / 100,
            cents % 100
        )
    }

    private func loadInitialAmount() {
        guard !amount.isEmpty else {
            rawDigits = ""
            return
        }

        let normalized = amount.replacingOccurrences(
            of: ",",
            with: "."
        )

        guard let decimal = Decimal(string: normalized) else {
            rawDigits = ""
            return
        }

        let cents = NSDecimalNumber(decimal: decimal * 100).intValue

        rawDigits =
            cents == 0
            ? ""
            : String(cents)
    }
}
