import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    GeneralSettingsView()
                } label: {
                    Label("General", systemImage: "gearshape")
                }

                NavigationLink {
                    SyncSettingsView()
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }

                NavigationLink {
                    LocalIntelligenceSettingsView()
                } label: {
                    Label("Local Intelligence", systemImage: "sparkles")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Temporary placeholders

private struct LocalIntelligenceSettingsView: View {
    var body: some View {
        ContentUnavailableView("No settings yet",
                               systemImage: "sparkles",
                               description: Text("Local Intelligence settings will appear here."))
            .navigationTitle("Local Intelligence")
            .navigationBarTitleDisplayMode(.inline)
    }
}
