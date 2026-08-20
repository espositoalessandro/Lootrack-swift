import GoogleSignIn
import SwiftUI

struct GoogleSheetSettingsView: View {
    @Environment(GoogleSheetSettings.self)
    private var sheetSettings
    
    @Environment(GoogleSheetSelectionService.self)
    private var selectionService
    
    @Environment(GoogleAuthorizationService.self)
    private var authorization
    
    @State
    private var isSigningIn = false
    
    @State
    private var errorTitle = ""
    
    @State
    private var errorMessage = ""
    
    @State
    private var showingError = false
    
    private var profileImageURL: URL? {
        authorization.user?.profile?.imageURL(withDimension: 256)
    }
    
    private var displayName: String {
        authorization.user?.profile?.name ?? String(localized: "Google Account")
    }
    
    private var email: String {
        authorization.user?.profile?.email ?? ""
    }
    
    var body: some View {
        Group {
            if authorization.user == nil {
                noAccountView
            } else {
                accountView
            }
        }
        .navigationTitle("Google Sheet")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await authorization.restoreSession()
        }
        .alert(errorTitle, isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var accountView: some View {
        List {
            accountHeader
            
            if sheetSettings.spreadsheetId != nil {
                Section {
                    LabeledContent("Selected Sheet", value: sheetSettings.spreadsheetName ?? "Name unavailable")
                }
            }
            
            Section {
                Button {
                    Task {
                        await selectSheet()
                    }
                } label: {
                    if selectionService.isSelecting {
                        HStack {
                            ProgressView()
                            Text("Selecting Sheet...")
                        }
                    } else {
                        Label("Select Sheet", systemImage: "tablecells")
                    }
                }
                .disabled(selectionService.isSelecting)
                
                Button {
                    // TODO: Create Google Sheet
                } label: {
                    Label("Create New Sheet", systemImage: "doc.badge.plus")
                }
            }
            
            Section {
                Button(role: .destructive) {
                    authorization.signOut()
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }
    
    private var noAccountView: some View {
        ContentUnavailableView {
            Label("No Account Linked", systemImage: "person.crop.circle.badge.xmark")
        } description: {
            Text("Link a Google account to synchronize Lootrack with Google Sheets.")
        } actions: {
            if isSigningIn {
                ProgressView()
            } else {
                GoogleLoginButton {
                    Task {
                        await signIn()
                    }
                }
                .frame(width: 300)
            }
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
    
    private func signIn() async {
        isSigningIn = true
        defer { isSigningIn = false }
        
        do {
            try await authorization.signIn()
        } catch {
            showError(title: "Unable to Log In", error: error)
        }
    }
    
    private func selectSheet() async {
        do {
            try await selectionService.selectSheet(loginHint: email.isEmpty ? nil : email)
        } catch GooglePickerError.cancelled {
            return
        } catch {
            showError(title: "Unable to Select Sheet", error: error)
        }
    }
    
    private func showError(title: String, error: Error) {
        errorTitle = title
        errorMessage = error.localizedDescription
        showingError = true
    }
}
