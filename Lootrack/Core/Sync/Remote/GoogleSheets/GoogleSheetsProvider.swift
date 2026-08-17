//
//  GoogleSheetsConfiguration.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 17/08/2026.
//


import Foundation
import GoogleSignIn
import UIKit

nonisolated struct GoogleSheetsConfiguration {
    let clientId: String
    let spreadsheetId: String

    static let development = GoogleSheetsConfiguration(
        clientId: "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com",
        spreadsheetId: "14JFbnyDEHtHEzQ-fj4Eqj4cAGFlVh4vmv_uZjJKKaUU"
    )
}

@MainActor
final class GoogleAuthorizationService {
    private static let driveFileScope =
        "https://www.googleapis.com/auth/drive.file"

    private let configuration: GoogleSheetsConfiguration

    init(configuration: GoogleSheetsConfiguration) {
        self.configuration = configuration

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: configuration.clientId
        )
    }

    func restorePreviousSignIn() async throws {
        _ = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    func signIn(
        presenting viewController: UIViewController
    ) async throws {
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            additionalScopes: [
                Self.driveFileScope
            ]
        )

        guard result.user.grantedScopes?.contains(
            Self.driveFileScope
        ) == true else {
            throw GoogleSheetsError.missingDrivePermission
        }
    }

    func accessToken() async throws -> String {
        guard let currentUser =
            GIDSignIn.sharedInstance.currentUser
        else {
            throw GoogleSheetsError.notSignedIn
        }

        let user = try await currentUser.refreshTokensIfNeeded()

        guard user.grantedScopes?.contains(
            Self.driveFileScope
        ) == true else {
            throw GoogleSheetsError.missingDrivePermission
        }

        return user.accessToken.tokenString
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}

nonisolated enum GoogleSheetsError: Error {
    case notSignedIn
    case missingDrivePermission
}

@MainActor
final class GoogleSheetsProvider: SyncProvider {
    private let configuration: GoogleSheetsConfiguration
    private let authorization: GoogleAuthorizationService
    private let client: GoogleSheetsClient

    init(
        configuration: GoogleSheetsConfiguration,
        authorization: GoogleAuthorizationService,
        client: GoogleSheetsClient
    ) {
        self.configuration = configuration
        self.authorization = authorization
        self.client = client
    }

    func pull() async throws -> RemoteSyncSnapshot {
        let accessToken = try await authorization.accessToken()

        return try await client.readSnapshot(
            accessToken: accessToken,
            spreadsheetId: configuration.spreadsheetId
        )
    }

    func push(
        _ request: SyncPushRequest
    ) async throws -> SyncPushResult {
        let accessToken = try await authorization.accessToken()

        return try await client.push(
            request,
            accessToken: accessToken,
            spreadsheetId: configuration.spreadsheetId
        )
    }
}