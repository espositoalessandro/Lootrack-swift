import SwiftUI

struct CurrencySettingsView: View {
    @Environment(AppSettings.self)
    private var settings

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var searchText = ""

    var body: some View {
        List {
            Section {
                Button {
                    settings.currencyCode = nil
                    dismiss()
                } label: {
                    SelectionRow(
                        title: systemTitle,
                        selected: settings.currencyCode == nil
                    )
                }
            }

            Section {
                ForEach(filteredCurrencies) { currency in
                    Button {
                        settings.currencyCode = currency.code
                        dismiss()
                    } label: {
                        HStack {
                            VStack(
                                alignment: .leading,
                                spacing: 2
                            ) {
                                Text(currency.name)
                                    .foregroundStyle(.primary)

                                Text(currency.code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if settings.currencyCode == currency.code {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            prompt: "Search currencies"
        )
    }

    private var systemTitle: String {
        "\(String(localized: "System")) (\(settings.resolvedCurrencyCode))"
    }

    private var currencies: [CurrencyOption] {
        let locale = settings.resolvedLocale

        return Locale.Currency
            .isoCurrencies
            .map(\.identifier)
            .uniqued()
            .map { code in
                CurrencyOption(
                    code: code,
                    name: locale.localizedString(forCurrencyCode: code) ?? code
                )
            }
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private var filteredCurrencies: [CurrencyOption] {
        guard !searchText.isEmpty else {
            return currencies
        }

        return currencies.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct CurrencyOption:
    Identifiable
{
    let code: String
    let name: String

    var id: String {
        code
    }
}

extension Sequence
where Element: Hashable {
    fileprivate func uniqued() -> [Element] {
        var seen = Set<Element>()

        return filter {
            seen.insert($0).inserted
        }
    }
}
