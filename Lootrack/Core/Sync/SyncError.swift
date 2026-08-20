import Foundation

nonisolated
enum SyncError: LocalizedError {
    case connectionUnavailable
    case authenticationRequired
    case permissionDenied
    case noSpreadsheetSelected
    case spreadsheetUnavailable
    case rateLimited
    case serviceUnavailable
    case invalidSpreadsheet
    case remoteChanged
    case conflictResolutionFailed
    case unexpected

    var errorDescription: String? {
        switch self {
        case .connectionUnavailable:
            String(localized: "Synchronization was interrupted.")
        case .authenticationRequired:
            String(localized: "Google authorization is required.")
        case .permissionDenied:
            String(localized: "Google Sheets access was denied.")
        case .noSpreadsheetSelected:
            String(localized: "No spreadsheet is selected.")
        case .spreadsheetUnavailable:
            String(localized: "The selected spreadsheet is unavailable.")
        case .rateLimited:
            String(localized: "Google Sheets is temporarily busy.")
        case .serviceUnavailable:
            String(localized: "Google Sheets is currently unavailable.")
        case .invalidSpreadsheet:
            String(localized: "The spreadsheet format isn't compatible with Lootrack.")
        case .remoteChanged:
            String(localized: "The spreadsheet changed during synchronization.")
        case .conflictResolutionFailed:
            String(localized: "The conflict couldn't be resolved.")
        case .unexpected:
            String(localized: "Synchronization failed.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .connectionUnavailable:
            String(localized: "Check your connection and try again. Your local changes are safe.")
        case .authenticationRequired:
            String(localized: "Try syncing again and complete Google sign-in if prompted.")
        case .permissionDenied:
            String(localized: "Make sure Lootrack has permission to access the selected spreadsheet.")
        case .noSpreadsheetSelected:
            String(localized: "Choose a spreadsheet in Sync settings.")
        case .spreadsheetUnavailable:
            String(localized: "Check that the spreadsheet still exists and that you can access it.")
        case .rateLimited:
            String(localized: "Wait a little and try again.")
        case .serviceUnavailable:
            String(localized: "Try again later. Your local changes are safe.")
        case .invalidSpreadsheet:
            String(localized: "Select a valid Lootrack spreadsheet or restore its required sheets and columns.")
        case .remoteChanged:
            String(localized: "Try syncing again so Lootrack can reconcile the latest version.")
        case .conflictResolutionFailed:
            String(localized: "Reload Sync Status and try again.")
        case .unexpected:
            String(localized: "Try again. Your local changes are safe.")
        }
    }
}

nonisolated
enum SyncStatus {
    case idle
    case syncing
    case succeeded(Date)
    case waitingForConflictResolution
    case failed(SyncError)
}
