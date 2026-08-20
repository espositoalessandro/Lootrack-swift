internal import os
import Foundation
import Observation

@MainActor
@Observable
final class SyncCoordinator {
    private let syncEngine: SyncEngine
    private let conflictResolutionService: ConflictResolutionService
    private let networkMonitor: NetworkMonitor
    
    private var syncTask: Task<Void, Never>?
    
    private(set) var status: SyncStatus = .idle
    private(set) var lastSuccessfulSync: Date?
    var conflicts: [SyncConflictCandidate] = []
    
    var isSyncing: Bool {
        if case .syncing = status {
            return true
        }
        
        return false
    }
    
    init(syncEngine: SyncEngine,
         conflictResolutionService: ConflictResolutionService,
         networkMonitor: NetworkMonitor)
    {
        self.syncEngine = syncEngine
        self.conflictResolutionService = conflictResolutionService
        self.networkMonitor = networkMonitor
    }
    
    func synchronize() async {
        guard networkMonitor.status == .online else {
            return
        }
        
        /*
         * If a synchronization is already running,
         * simply wait for that same run.
         */
        if let syncTask {
            await syncTask.value
            return
        }
        
        /*
         * Synchronization owns its own task.
         *
         * This prevents the network operation from
         * being cancelled just because the UI task
         * that triggered it disappears or is cancelled.
         */
        let task = Task { @MainActor in
            await performSynchronization()
        }
        
        syncTask = task
        await task.value
    }
    
    private func performSynchronization() async {
        status = .syncing
        conflicts = []
        
        defer {
            syncTask = nil
        }
        
        do {
            try await syncEngine.synchronize()
            
            let now = Date.now
            lastSuccessfulSync = now
            status = .succeeded(now)
        } catch let error as SyncRunConflictError {
            conflicts = error.conflicts
            status = .waitingForConflictResolution
        } catch {
            conflicts = []
            
            let syncError = mapError(error)
            status = .failed(syncError)
            
            let errorDescription = String(describing: error)
            AppLogger.sync.error("Synchronization failed: \(errorDescription, privacy: .public)")
        }
    }
    
    func resolveConflict(_ conflict: SyncConflictCandidate, using resolution: ConflictResolution) {
        do {
            try conflictResolutionService.resolve(conflict, using: resolution)
            
            conflicts.removeAll {
                $0.id == conflict.id
            }
            
            status = conflicts.isEmpty ? .idle : .waitingForConflictResolution
        } catch {
            status = .failed(.conflictResolutionFailed)
            
            let errorDescription = String(describing: error)
            AppLogger.sync.error("Conflict resolution failed: \(errorDescription, privacy: .public)")
        }
    }
    
    private func mapError(_ error: Error) -> SyncError {
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet,
                    .networkConnectionLost,
                    .cannotConnectToHost,
                    .cannotFindHost,
                    .dnsLookupFailed,
                    .timedOut:
                return .connectionUnavailable
                
            default:
                return .unexpected
            }
        }
        
        if let error = error as? GoogleSheetsError {
            switch error {
            case .missingDrivePermission:
                return .permissionDenied
            case .missingPresentationContext:
                return .authenticationRequired
            case .noSpreadsheetSelected:
                return .noSpreadsheetSelected
            }
        }
        
        if let error = error as? GoogleSheetsClientError {
            switch error {
            case .invalidURL,
                    .invalidResponse:
                return .unexpected
                
            case let .apiError(status, _):
                switch status {
                case 401:
                    return .authenticationRequired
                case 403:
                    return .permissionDenied
                case 404:
                    return .spreadsheetUnavailable
                case 408:
                    return .connectionUnavailable
                case 429:
                    return .rateLimited
                case 500 ..< 600:
                    return .serviceUnavailable
                default:
                    return .unexpected
                }
                
            case .invalidData:
                return .invalidSpreadsheet
                
            case .writeConflict:
                return .remoteChanged
            }
        }
        
        return .unexpected
    }
}
