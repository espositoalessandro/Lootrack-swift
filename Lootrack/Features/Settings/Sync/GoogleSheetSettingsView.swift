import GoogleSignIn
import SwiftUI

struct GoogleSheetSettingsView: View {
    @Environment(GoogleSheetSettings.self)
    private var sheetSettings
    
    @Environment(GoogleSheetSelectionService.self)
    private var selectionService
    
    @State
    private var user: GIDGoogleUser?
    
    @State
    private var selectionErrorMessage = ""
    
    @State
    private var showingSelectionError = false
    
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
            
            if sheetSettings.spreadsheetId != nil {
                Section {
                    LabeledContent("Selected Sheet", value: sheetSettings.spreadsheetName ?? "Current Google Sheet")
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
                    // TODO: Log out
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Google Sheet")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUser()
        }
        .alert("Unable to Select Sheet", isPresented: $showingSelectionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(selectionErrorMessage)
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
    
    private func selectSheet() async {
        do {
            try await selectionService.selectSheet(loginHint: email.isEmpty ? nil : email)
        } catch GooglePickerError.cancelled {
            return
        } catch {
            selectionErrorMessage = error.localizedDescription
            showingSelectionError = true
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
