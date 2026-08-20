import Foundation
import Observation
import SwiftData

nonisolated enum GoogleSheetSelectionError: LocalizedError {
    case pendingMutations
    case inaccessibleSpreadsheet
    case invalidSpreadsheet

    var errorDescription: String? {
        switch self {
        case .pendingMutations:
            "Sync your pending changes before switching Google Sheets."
        case .inaccessibleSpreadsheet:
            "Lootrack can't access this spreadsheet with the currently signed-in Google account."
        case .invalidSpreadsheet:
            "The selected spreadsheet isn't a valid Lootrack sheet."
        }
    }
}

@MainActor
@Observable
final class GoogleSheetSelectionService {
    private let settings: GoogleSheetSettings
    private let picker: GooglePickerService
    private let authorization: GoogleAuthorizationService
    private let client: GoogleSheetsClient
    private let modelContext: ModelContext

    private(set) var isSelecting = false

    init(settings: GoogleSheetSettings, picker: GooglePickerService, authorization: GoogleAuthorizationService,
         client: GoogleSheetsClient, modelContext: ModelContext)
    {
        self.settings = settings
        self.picker = picker
        self.authorization = authorization
        self.client = client
        self.modelContext = modelContext
    }

    func selectSheet(loginHint: String? = nil) async throws {
        guard !isSelecting else {
            return
        }

        isSelecting = true
        defer { isSelecting = false }

        let file = try await picker.pickSpreadsheet(loginHint: loginHint)

        if file.id != settings.spreadsheetId {
            let pendingMutationCount = try modelContext.fetchCount(FetchDescriptor<Mutation>())

            guard pendingMutationCount == 0 else {
                throw GoogleSheetSelectionError.pendingMutations
            }
        }

        let accessToken = try await authorization.accessToken()

        do {
            _ = try await client.readSnapshot(accessToken: accessToken, spreadsheetId: file.id)
        } catch let error as GoogleSheetsClientError {
            switch error {
            case .invalidData, .apiError(status: 400, message: _):
                throw GoogleSheetSelectionError.invalidSpreadsheet

            case .apiError(status: 401, message: _),
                 .apiError(status: 403, message: _),
                 .apiError(status: 404, message: _):
                throw GoogleSheetSelectionError.inaccessibleSpreadsheet

            default:
                throw error
            }
        }

        settings.select(spreadsheetId: file.id, name: file.name)
    }
}
