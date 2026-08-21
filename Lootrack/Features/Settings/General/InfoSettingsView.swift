import SwiftUI

struct InfoSettingsView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: BuildInfo.version)
                LabeledContent("Build", value: BuildInfo.buildNumber)
                LabeledContent("Commit", value: BuildInfo.commitSHA)
            }
        }
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}
