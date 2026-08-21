import SwiftUI

struct SyncSettingsView: View {
    @Environment(AppSettings.self)
    private var settings
    
    var body: some View {
        @Bindable var settings = settings
        
        List {
            Section {
                Toggle("Automatic Sync", isOn: $settings.automaticSyncEnabled)
                
                Picker("Sync Interval", selection: $settings.syncInterval) {
                    ForEach(SyncInterval.allCases) { interval in
                        Text(interval.displayName)
                            .tag(interval)
                    }
                }
                .pickerStyle(.navigationLink)
                .disabled(!settings.automaticSyncEnabled)
            } footer: {
                Text("Automatically synchronizes while Lootrack is active and when you return to the app.")
            }
            
            Section {
                NavigationLink {
                    SyncView()
                } label: {
                    Label("Sync Status", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            
            Section("Provider") {
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
