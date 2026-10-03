import SwiftData
import SwiftUI

struct SyncSettingsView: View {
    @Environment(AppSettings.self)
    private var settings

    @Environment(SyncCoordinator.self)
    private var syncCoordinator

    @Environment(NetworkMonitor.self)
    private var networkMonitor

    @Query(MutationQueries.pendingByOldest)
    private var mutations: [Mutation]

    @State
    private var showingResetConfirmation =
        false

    @State
    private var resetMessage: String?

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

            Section {
                Button("Reset Remote from This Device",
                       systemImage:
                       "arrow.trianglehead.2.clockwise.rotate.90",
                       role: .destructive)
                {
                    showingResetConfirmation =
                        true
                }
                .disabled(!canResetRemote)
            } footer: {
                if !mutations.isEmpty {
                    Text("Sync pending changes before replacing remote data.")
                } else {
                    Text("Replaces synchronized data in the selected Google Sheet with the data currently stored on this device.")
                }
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Replace Remote Data?",
                            isPresented:
                            $showingResetConfirmation,
                            titleVisibility:
                            .visible)
        {
            Button("Replace Remote",
                   role: .destructive)
            {
                Task {
                    await resetRemote()
                }
            }

            Button("Cancel",
                   role: .cancel)
            {}
        } message: {
            Text("Remote data that does not exist on this device will be removed. Variables, Summary, and other non-Lootrack sheets will not be changed.")
        }
        .alert("Remote Reset",
               isPresented:
               Binding(get: {
                   resetMessage != nil
               },
               set: { isPresented in
                   if !isPresented {
                       resetMessage =
                           nil
                   }
               }))
        {
            Button("OK") {
                resetMessage =
                    nil
            }
        } message: {
            Text(resetMessage ?? "")
        }
    }

    private var canResetRemote: Bool {
        mutations.isEmpty
            && !syncCoordinator.isSyncing
            && syncCoordinator.isConfigured
            && syncCoordinator.conflicts.isEmpty
            && networkMonitor.status == .online
    }

    private func resetRemote() async {
        await syncCoordinator
            .resetRemoteFromLocal()

        switch syncCoordinator.status {
        case .succeeded:
            resetMessage =
                String(localized:
                    "Remote data was replaced with the data on this device.")

        case let .failed(error):
            let description =
                error.errorDescription
                    ?? String(localized:
                        "Remote reset failed.")

            if let recovery =
                error.recoverySuggestion
            {
                resetMessage =
                    "\(description) \(recovery)"
            } else {
                resetMessage =
                    description
            }

        default:
            break
        }
    }
}
