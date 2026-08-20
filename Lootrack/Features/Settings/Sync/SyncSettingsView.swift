//
//  SyncSettingsView.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 20/08/2026.
//

import SwiftUI

struct SyncSettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    GoogleSheetSettingsView()
                } label: {
                    Label("Google Sheet", systemImage: "tablecells")
                }
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
    }
}
