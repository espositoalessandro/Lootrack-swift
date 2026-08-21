import Foundation

nonisolated enum SyncError: LocalizedError {
    case connectionUnavailable
    case authenticationRequired
    case permissionDenied
    case configurationRequired
    case remoteUnavailable
    case rateLimited
    case serviceUnavailable
    case invalidRemoteData
    case remoteChanged
    case conflictResolutionFailed
    case unexpected

    var errorDescription: String? {
        switch self {
        case .connectionUnavailable:
            String(localized: "Synchronization was interrupted.")
        case .authenticationRequired:
            String(localized: "Synchronization authorization is required.")
        case .permissionDenied:
            String(localized: "Synchronization access was denied.")
        case .configurationRequired:
            String(localized: "Synchronization isn't configured.")
        case .remoteUnavailable:
            String(localized: "The synchronization destination is unavailable.")
        case .rateLimited:
            String(localized: "The synchronization service is temporarily busy.")
        case .serviceUnavailable:
            String(localized: "The synchronization service is currently unavailable.")
        case .invalidRemoteData:
            String(localized: "The synchronization data isn't compatible with Lootrack.")
        case .remoteChanged:
            String(localized: "Remote data changed during synchronization.")
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
            String(localized: "Reconnect your sync provider in Sync settings.")
        case .permissionDenied:
            String(localized: "Check the permissions of your sync provider.")
        case .configurationRequired:
            String(localized: "Configure a sync provider in Sync settings.")
        case .remoteUnavailable:
            String(localized: "Check that the synchronization destination still exists and is accessible.")
        case .rateLimited:
            String(localized: "Wait a little and try again.")
        case .serviceUnavailable:
            String(localized: "Try again later. Your local changes are safe.")
        case .invalidRemoteData:
            String(localized: "Check your synchronization destination or configure it again.")
        case .remoteChanged:
            String(localized: "Try syncing again so Lootrack can reconcile the latest version.")
        case .conflictResolutionFailed:
            String(localized: "Reload Sync Status and try again.")
        case .unexpected:
            String(localized: "Try again. Your local changes are safe.")
        }
    }
}

nonisolated enum SyncTrigger: String {
    case manual
    case connectivityRestored
    case foreground
    case automatic
    case background
}

nonisolated enum SyncStatus {
    case idle
    case syncing
    case succeeded(Date)
    case waitingForConflictResolution
    case failed(SyncError)
}
