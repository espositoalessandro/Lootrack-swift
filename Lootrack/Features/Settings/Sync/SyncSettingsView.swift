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
                    Label {
                        Text("Google Sheet")
                    } icon: {
                        Image("GoogleSheetLogo")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
    }
}
