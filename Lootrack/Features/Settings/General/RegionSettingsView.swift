//
//  RegionSettingsView.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 20/08/2026.
//

import SwiftUI

struct RegionSettingsView: View {
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
                    settings.regionCode = nil
                    dismiss()
                } label: {
                    SelectionRow(title: String(localized: "System"),
                                 selected:
                                 settings.regionCode
                                     == nil)
                }
            }

            Section {
                ForEach(filteredRegions) {
                    region in
                    Button {
                        settings.regionCode =
                            region.code

                        dismiss()
                    } label: {
                        SelectionRow(title: region.name,
                                     selected:
                                     settings.regionCode
                                         == region.code)
                    }
                }
            }
        }
        .navigationTitle("Region")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText,
                    prompt: "Search regions")
    }

    private var regions: [RegionOption] {
        let locale =
            settings.resolvedLocale

        return Locale.Region.isoRegions
            .filter(\.subRegions.isEmpty)
            .compactMap { region in
                let code =
                    region.identifier

                guard
                    let name =
                    locale.localizedString(forRegionCode: code)
                else {
                    return nil
                }

                return RegionOption(code: code,
                                    name: name)
            }
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private var filteredRegions:
        [RegionOption]
    {
        guard !searchText.isEmpty else {
            return regions
        }

        return regions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct RegionOption:
    Identifiable
{
    let code: String
    let name: String

    var id: String {
        code
    }
}
