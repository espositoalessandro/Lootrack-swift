//
//  GeneralSettingsView.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 20/08/2026.
//

import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppSettings.self)
    private var settings

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LanguageSettingsView()
                } label: {
                    SettingsValueRow(title: "Language", value: languageValue)
                }

                NavigationLink {
                    RegionSettingsView()
                } label: {
                    SettingsValueRow(title: "Region", value: regionValue)
                }

                NavigationLink {
                    CurrencySettingsView()
                } label: {
                    SettingsValueRow(title: "Currency", value: currencyValue)
                }
            } footer: {
                Text("System uses the corresponding iPhone setting.")
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var languageValue: String {
        settings.language.displayName(locale: settings.resolvedLocale)
    }

    private var regionValue: String {
        guard let regionCode = settings.regionCode
        else {
            return String(localized: "System")
        }

        return settings.resolvedLocale.localizedString(
            forRegionCode: regionCode
        ) ?? regionCode
    }

    private var currencyValue: String {
        settings.currencyCode ?? String(localized: "System")
    }
}

private struct SettingsValueRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(title)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
