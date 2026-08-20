import GoogleSignIn
import SwiftUI

struct GoogleSheetSettingsView: View {
    @State
    private var user: GIDGoogleUser?

    private var profileImageURL: URL? {
        user?.profile?.imageURL(withDimension: 256)
    }

    private var displayName: String {
        user?.profile?.name ?? String(localized: "Google Account")
    }

    private var email: String {
        user?.profile?.email ?? ""
    }

    var body: some View {
        List {
            accountHeader

            Section {
                Button {
                    // TODO: Select Google Sheet
                } label: {
                    Label("Select Sheet", systemImage: "tablecells")
                }

                Button {
                    // TODO: Create Google Sheet
                } label: {
                    Label("Create New Sheet", systemImage: "doc.badge.plus")
                }
            }

            Section {
                Button(role: .destructive) {
                    // TODO: Log out
                } label: {
                    Label(
                        "Log Out",
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
            }
        }
        .navigationTitle("Google Sheet")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUser()
        }
    }

    private var accountHeader: some View {
        VStack(spacing: 8) {
            profileImage

            Text(displayName)
                .font(.title)
                .fontWeight(.semibold)

            if !email.isEmpty {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var profileImage: some View {
        if let profileImageURL {
            AsyncImage(url: profileImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 112, height: 112)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 112, height: 112)
        }
    }

    private func loadUser() async {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            user = currentUser
            return
        }

        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            return
        }

        user = try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }
}
