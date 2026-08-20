//
//  GooglePickedFile.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 20/08/2026.
//


import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

nonisolated struct GooglePickedFile {
    let id: String
    let name: String
}

nonisolated enum GooglePickerError: LocalizedError {
    case cancelled
    case invalidURL
    case invalidCallback
    case invalidState
    case noFileSelected
    case missingPresentationContext
    case couldNotStart
    case tokenExchangeFailed
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Selection cancelled."
        case .invalidURL:
            "Lootrack couldn't create the Google Picker URL."
        case .invalidCallback:
            "Google returned an invalid Picker response."
        case .invalidState:
            "Google returned an invalid authentication state."
        case .noFileSelected:
            "No spreadsheet was selected."
        case .missingPresentationContext:
            "Lootrack couldn't open the Google Picker."
        case .couldNotStart:
            "The Google Picker couldn't be started."
        case .tokenExchangeFailed:
            "Google couldn't complete the Picker authorization."
        case .invalidFile:
            "The selected file isn't a Google Sheet."
        }
    }
}

@MainActor
final class GooglePickerService {
    private static let pickerScope = "https://www.googleapis.com/auth/drive.file"
    private static let spreadsheetMimeType = "application/vnd.google-apps.spreadsheet"

    private let configuration: GoogleSheetsConfiguration

    private var session: ASWebAuthenticationSession?
    private var presentationContextProvider: GooglePickerPresentationContextProvider?

    init(configuration: GoogleSheetsConfiguration) {
        self.configuration = configuration
    }

    func pickSpreadsheet(loginHint: String? = nil) async throws -> GooglePickedFile {
        let state = UUID().uuidString
        let codeVerifier = try makeCodeVerifier()
        let codeChallenge = makeCodeChallenge(for: codeVerifier)
        let url = try authorizationURL(state: state, codeChallenge: codeChallenge, loginHint: loginHint)

        let callback = try await startSession(url: url, expectedState: state)
        let accessToken = try await exchangeAuthorizationCode(callback.code, codeVerifier: codeVerifier)

        return try await readFile(fileId: callback.fileId, accessToken: accessToken)
    }

    private func authorizationURL(state: String, codeChallenge: String, loginHint: String?) throws -> URL {
        guard var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth") else {
            throw GooglePickerError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.pickerRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.pickerScope),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "trigger_onepick", value: "true"),
            URLQueryItem(name: "allow_multiple", value: "false"),
            URLQueryItem(name: "mimetypes", value: Self.spreadsheetMimeType),
            URLQueryItem(name: "include_granted_scopes", value: "false"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]

        if let loginHint, !loginHint.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "login_hint", value: loginHint))
        }

        guard let url = components.url else {
            throw GooglePickerError.invalidURL
        }

        return url
    }

    private func startSession(url: URL, expectedState: String) async throws -> PickerCallback {
        guard let window = activeWindow() else {
            throw GooglePickerError.missingPresentationContext
        }

        return try await withCheckedThrowingContinuation { continuation in
            let presentationContextProvider = GooglePickerPresentationContextProvider(window: window)

            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: configuration.callbackScheme) { [weak self] callbackURL, error in
                let result = Self.parseCallback(callbackURL, error: error, expectedState: expectedState)
                continuation.resume(with: result)

                Task { @MainActor [weak self] in
                    self?.session = nil
                    self?.presentationContextProvider = nil
                }
            }

            session.presentationContextProvider = presentationContextProvider
            session.prefersEphemeralWebBrowserSession = false

            self.presentationContextProvider = presentationContextProvider
            self.session = session

            guard session.start() else {
                self.session = nil
                self.presentationContextProvider = nil
                continuation.resume(throwing: GooglePickerError.couldNotStart)
                return
            }
        }
    }

    private func exchangeAuthorizationCode(_ code: String, codeVerifier: String) async throws -> String {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw GooglePickerError.invalidURL
        }

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: configuration.pickerRedirectURI)
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse, (200 ..< 300).contains(response.statusCode) else {
            throw GooglePickerError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data).accessToken
    }

    private func readFile(fileId: String, accessToken: String) async throws -> GooglePickedFile {
        guard var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files/\(fileId)") else {
            throw GooglePickerError.invalidURL
        }

        components.queryItems = [URLQueryItem(name: "fields", value: "id,name,mimeType")]

        guard let url = components.url else {
            throw GooglePickerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse, (200 ..< 300).contains(response.statusCode) else {
            throw GooglePickerError.invalidFile
        }

        let file = try JSONDecoder().decode(DriveFile.self, from: data)

        guard file.mimeType == Self.spreadsheetMimeType else {
            throw GooglePickerError.invalidFile
        }

        return GooglePickedFile(id: file.id, name: file.name)
    }

    private func makeCodeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 64)

        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw GooglePickerError.tokenExchangeFailed
        }

        return base64URL(Data(bytes))
    }

    private func makeCodeChallenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func activeWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }
    }

    nonisolated private static func parseCallback(_ url: URL?, error: Error?, expectedState: String) -> Result<PickerCallback, Error> {
        if let authenticationError = error as? ASWebAuthenticationSessionError,
           authenticationError.code == .canceledLogin
        {
            return .failure(GooglePickerError.cancelled)
        }

        if let error {
            return .failure(error)
        }

        guard let url else {
            return .failure(GooglePickerError.invalidCallback)
        }

        guard value("state", in: url) == expectedState else {
            return .failure(GooglePickerError.invalidState)
        }

        if value("error", in: url) != nil {
            return .failure(GooglePickerError.cancelled)
        }

        guard let code = value("code", in: url), !code.isEmpty else {
            return .failure(GooglePickerError.invalidCallback)
        }

        guard let fileIds = value("picked_file_ids", in: url),
              let fileId = fileIds.split(separator: ",").first.map(String.init),
              !fileId.isEmpty
        else {
            return .failure(GooglePickerError.noFileSelected)
        }

        return .success(PickerCallback(fileId: fileId, code: code))
    }

    nonisolated private static func value(_ name: String, in url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if let value = components?.queryItems?.first(where: { $0.name == name })?.value {
            return value
        }

        guard let fragment = components?.fragment,
              let fragmentComponents = URLComponents(string: "?\(fragment)")
        else {
            return nil
        }

        return fragmentComponents.queryItems?.first(where: { $0.name == name })?.value
    }

    private struct TokenResponse: Decodable {
        let accessToken: String

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }

    private struct DriveFile: Decodable {
        let id: String
        let name: String
        let mimeType: String
    }

    nonisolated private struct PickerCallback {
        let fileId: String
        let code: String
    }
}

@MainActor
private final class GooglePickerPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let window: UIWindow

    init(window: UIWindow) {
        self.window = window
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window
    }
}