import Foundation
import GoogleSignIn
import Observation
import UIKit

nonisolated enum GoogleSheetsError: Error {
    case authenticationRequired
    case missingDrivePermission
    case missingPresentationContext
    case noSpreadsheetSelected
}

private enum GoogleSignInErrorCode {
    static let noAuthInKeychain = -4
    static let refreshTokenExpired = -11
}

nonisolated struct GoogleSheetsConfiguration {
    let clientId: String

    var callbackScheme: String {
        let id = clientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(id)"
    }

    var pickerRedirectURI: String {
        "\(callbackScheme):/oauth2redirect"
    }

    static let development = GoogleSheetsConfiguration(clientId: "301925252646-k9ev1fi2eqcb0abkoc8glqjkupajrb5e.apps.googleusercontent.com")
}

@MainActor
@Observable
final class GoogleAuthorizationService {
    private static let driveFileScope = "https://www.googleapis.com/auth/spreadsheets"
    private let configuration: GoogleSheetsConfiguration
    private(set) var user: GIDGoogleUser?

    init(configuration: GoogleSheetsConfiguration) {
        self.configuration = configuration
        user = GIDSignIn.sharedInstance.currentUser

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: configuration.clientId)
    }

    func restoreSession() async {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            user = currentUser
            return
        }

        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            user = nil
            return
        }

        user = try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    @discardableResult
    func signIn() async throws -> GIDGoogleUser {
        let user = try await getUser()
        let authorizedUser = try await ensureDrivePermission(for: user)

        self.user = authorizedUser
        return authorizedUser
    }

    private func userForSynchronization() async throws -> GIDGoogleUser {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            return currentUser
        }
        
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            throw GoogleSheetsError.authenticationRequired
        }
        
        do {
            let restoredUser = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            self.user = restoredUser
            return restoredUser
        } catch {
            if isMissingAuthentication(error) {
                self.user = nil
                throw GoogleSheetsError.authenticationRequired
            }
            
            throw error
        }
    }
    
    private func isMissingAuthentication(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        guard nsError.domain == kGIDSignInErrorDomain else {
            return false
        }
        
        return nsError.code == GoogleSignInErrorCode.noAuthInKeychain
        || nsError.code == GoogleSignInErrorCode.refreshTokenExpired
    }
    

    func accessToken() async throws -> String {
        let user = try await userForSynchronization()
        
        guard user.grantedScopes?.contains(Self.driveFileScope) == true else {
            throw GoogleSheetsError.authenticationRequired
        }
        
        let refreshedUser = try await user.refreshTokensIfNeeded()
        
        self.user = refreshedUser
        return refreshedUser.accessToken.tokenString
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        user = nil
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

        return try await performSignIn()
    }

    private func performSignIn() async throws -> GIDGoogleUser {
        let viewController = try presentingViewController()

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController,
                                                               hint: nil,
                                                               additionalScopes: [Self.driveFileScope])

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
        do {
            let spreadsheetId = try selectedSpreadsheetId()
            let accessToken = try await authorization.accessToken()
            
            return try await client.readSnapshot(accessToken: accessToken, spreadsheetId: spreadsheetId)
        } catch {
            throw mapError(error)
        }
    }
    
    func push(_ request: SyncPushRequest) async throws -> SyncPushResult {
        do {
            let spreadsheetId = try selectedSpreadsheetId()
            let accessToken = try await authorization.accessToken()
            
            return try await client.push(request, accessToken: accessToken, spreadsheetId: spreadsheetId)
        } catch {
            throw mapError(error)
        }
    }

    private func selectedSpreadsheetId() throws -> String {
        guard let spreadsheetId = settings.spreadsheetId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !spreadsheetId.isEmpty
        else {
            throw GoogleSheetsError.noSpreadsheetSelected
        }

        return spreadsheetId
    }
    
    private func mapError(_ error: Error) -> Error {
        if let error = error as? GoogleSheetsError {
            switch error {
            case .authenticationRequired:
                return SyncProviderError.authenticationRequired
            case .missingDrivePermission:
                return SyncProviderError.permissionDenied
            case .missingPresentationContext:
                return SyncProviderError.authenticationRequired
            case .noSpreadsheetSelected:
                return SyncProviderError.configurationRequired
            }
        }
        
        if let error = error as? GoogleSheetsClientError {
            switch error {
            case .invalidURL,
                    .invalidResponse:
                return error
                
            case let .apiError(status, _):
                switch status {
                case 401:
                    return SyncProviderError.authenticationRequired
                case 403:
                    return SyncProviderError.permissionDenied
                case 404:
                    return SyncProviderError.remoteUnavailable
                case 408:
                    return SyncProviderError.connectionUnavailable
                case 429:
                    return SyncProviderError.rateLimited
                case 500 ..< 600:
                    return SyncProviderError.serviceUnavailable
                default:
                    return error
                }
                
            case .invalidData:
                return SyncProviderError.invalidRemoteData
                
            case .writeConflict:
                return SyncProviderError.remoteChanged
            }
        }
        
        return error
    }
}
