import Foundation
import GoogleSignIn
import UIKit

nonisolated struct GoogleSheetsConfiguration {
    let clientId: String
    
    static let development = GoogleSheetsConfiguration(
        clientId: "301925252646-k9ev1fi2eqcb0abkoc8glqjkupajrb5e.apps.googleusercontent.com"
    )
}

@MainActor
final class GoogleAuthorizationService {
    private static let driveFileScope = "https://www.googleapis.com/auth/spreadsheets"
    
    private let configuration: GoogleSheetsConfiguration
    
    init(configuration: GoogleSheetsConfiguration) {
        self.configuration = configuration
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: configuration.clientId)
    }
    
    func accessToken() async throws -> String {
        let user = try await getUser()
        let authorizedUser = try await ensureDrivePermission(for: user)
        let refreshedUser = try await authorizedUser.refreshTokensIfNeeded()
        
        return refreshedUser.accessToken.tokenString
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
    
    private func getUser() async throws -> GIDGoogleUser {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            return currentUser
        }
        
        if GIDSignIn.sharedInstance.hasPreviousSignIn(),
           let restoredUser = try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
            {
            return restoredUser
        }
        
        return try await signIn()
    }
    
    private func signIn() async throws -> GIDGoogleUser {
        let viewController = try presentingViewController()
        
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: [Self.driveFileScope]
        )
        
        guard result.user.grantedScopes?.contains(Self.driveFileScope) == true else {
            throw GoogleSheetsError.missingDrivePermission
        }
        
        return result.user
    }
    
    private func ensureDrivePermission(for user: GIDGoogleUser) async throws -> GIDGoogleUser {
        if user.grantedScopes?.contains(Self.driveFileScope) == true {
            return user
        }
        
        let result = try await user.addScopes([Self.driveFileScope], presenting: presentingViewController())
        
        guard result.user.grantedScopes?.contains(Self.driveFileScope) == true else {
            throw GoogleSheetsError.missingDrivePermission
        }
        
        return result.user
    }
    
    private func presentingViewController() throws -> UIViewController {
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        
        guard let rootViewController = activeScene?.keyWindow?.rootViewController else {
            throw GoogleSheetsError.missingPresentationContext
        }
        
        return topViewController(from: rootViewController)
    }
    
    private func topViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return topViewController(from: presented)
        }
        
        if let navigationController = viewController as? UINavigationController,
           let visible = navigationController.visibleViewController
            {
            return topViewController(from: visible)
        }
        
        if let tabBarController = viewController as? UITabBarController,
           let selected = tabBarController.selectedViewController
            {
            return topViewController(from: selected)
        }
        
        return viewController
    }
}

nonisolated enum GoogleSheetsError: Error {
    case missingDrivePermission
    case missingPresentationContext
    case noSpreadsheetSelected
}

@MainActor
final class GoogleSheetsProvider: SyncProvider {
    private let settings: GoogleSheetSettings
    private let authorization: GoogleAuthorizationService
    private let client: GoogleSheetsClient
    
    init(settings: GoogleSheetSettings, authorization: GoogleAuthorizationService, client: GoogleSheetsClient) {
        self.settings = settings
        self.authorization = authorization
        self.client = client
    }
    
    func pull() async throws -> RemoteSyncSnapshot {
        let spreadsheetId = try selectedSpreadsheetId()
        let accessToken = try await authorization.accessToken()
        
        return try await client.readSnapshot(accessToken: accessToken, spreadsheetId: spreadsheetId)
    }
    
    func push(_ request: SyncPushRequest) async throws -> SyncPushResult {
        let spreadsheetId = try selectedSpreadsheetId()
        let accessToken = try await authorization.accessToken()
        
        return try await client.push(request, accessToken: accessToken, spreadsheetId: spreadsheetId)
    }
    
    private func selectedSpreadsheetId() throws -> String {
        guard let spreadsheetId = settings.spreadsheetId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !spreadsheetId.isEmpty
                else {
            throw GoogleSheetsError.noSpreadsheetSelected
        }
        
        return spreadsheetId
    }
}
