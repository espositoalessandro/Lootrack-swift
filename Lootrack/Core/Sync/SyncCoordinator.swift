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

    private(set) var lastSyncAttempt: Date?

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

    func synchronize(trigger: SyncTrigger = .manual) async {
        guard networkMonitor.status == .online else {
            return
        }

        guard syncEngine.isConfigured else {
            if trigger == .manual {
                status = .failed(.configurationRequired)
            }
            return
        }

        guard conflicts.isEmpty else {
            return
        }

        if let syncTask {
            await syncTask.value
            return
        }

        let task = Task { @MainActor in
            await performSynchronization(trigger: trigger)
        }

        syncTask = task
        await task.value
    }

    private func performSynchronization(trigger: SyncTrigger) async {
        lastSyncAttempt = .now
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
            let triggerName = trigger.rawValue
            AppLogger.sync.error("Synchronization failed [\(triggerName, privacy: .public)]: \(errorDescription, privacy: .public)")
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

        if let error = error as? SyncProviderError {
            switch error {
            case .authenticationRequired:
                return .authenticationRequired
            case .permissionDenied:
                return .permissionDenied
            case .configurationRequired:
                return .configurationRequired
            case .connectionUnavailable:
                return .connectionUnavailable
            case .remoteUnavailable:
                return .remoteUnavailable
            case .rateLimited:
                return .rateLimited
            case .serviceUnavailable:
                return .serviceUnavailable
            case .invalidRemoteData:
                return .invalidRemoteData
            case .remoteChanged:
                return .remoteChanged
            }
        }

        return .unexpected
    }

    func runForegroundAutomaticSync(interval: TimeInterval) async {
        await synchronizeIfStale(trigger: .foreground, interval: interval)
        
        while !Task.isCancelled {
            let delay = timeUntilNextAutomaticSync(interval: interval)
            
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            
            guard !Task.isCancelled else {
                return
            }
            
            await synchronizeIfStale(trigger: .automatic, interval: interval)
        }
    }
    
    private func synchronizeIfStale(trigger: SyncTrigger, interval: TimeInterval) async {
        guard networkMonitor.status == .online,
              syncEngine.isConfigured,
              conflicts.isEmpty
                else {
            return
        }
        
        if let lastSyncAttempt,
           Date.now.timeIntervalSince(lastSyncAttempt) < interval
            {
            return
        }
        
        await synchronize(trigger: trigger)
    }
    
    private func timeUntilNextAutomaticSync(interval: TimeInterval) -> TimeInterval {
        guard networkMonitor.status == .online,
              syncEngine.isConfigured,
              conflicts.isEmpty
                else {
            return interval
        }
        
        guard let lastSyncAttempt else {
            return interval
        }
        
        let elapsed = Date.now.timeIntervalSince(lastSyncAttempt)
        return max(1, interval - elapsed)
    }
}
