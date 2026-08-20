//
//  LanguageSettingsView.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 20/08/2026.
//

import SwiftUI

struct LanguageSettingsView: View {
    @Environment(AppSettings.self)
    private var settings

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) {
                    language in
                    Button {
                        settings.language =
                            language

                        dismiss()
                    } label: {
                        SelectionRow(title:
                            language
                                .displayName,
                            selected:
                            settings.language
                                == language)
                    }
                }
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}
