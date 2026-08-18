import Foundation
import Observation

@MainActor
@Observable
final class SyncCoordinator {
    private let syncEngine: SyncEngine
    private let conflictResolutionService: ConflictResolutionService

    var isSyncing = false
    var syncResult: String?
    var conflicts: [SyncConflictCandidate] = []

    init(
        syncEngine: SyncEngine,
        conflictResolutionService: ConflictResolutionService
    ) {
        self.syncEngine = syncEngine
        self.conflictResolutionService = conflictResolutionService
    }

    func synchronize() async {
        guard !isSyncing else {
            return
        }

        isSyncing = true

        /*
         * Every synchronization attempt produces
         * a new reconciliation result.
         */
        conflicts = []
        syncResult = nil

        defer {
            isSyncing = false
        }

        do {
            try await syncEngine.synchronize()

            syncResult = "Synchronization completed"

        } catch let error as SyncRunConflictError {
            conflicts = error.conflicts

        } catch {
            conflicts = []

            syncResult =
                "ERROR: \(String(describing: error))"

            print(
                "Synchronization failed:",
                error
            )
        }
    }

    func resolveConflict(
        _ conflict: SyncConflictCandidate,
        using resolution: ConflictResolution
    ) {
        do {
            try conflictResolutionService.resolve(
                conflict,
                using: resolution
            )

            conflicts.removeAll {
                $0.id == conflict.id
            }

            if conflicts.isEmpty {
                syncResult =
                    "Conflicts resolved. Synchronize again to continue."
            }

        } catch {
            syncResult =
                "ERROR: \(String(describing: error))"

            print(
                "Conflict resolution failed:",
                error
            )
        }
    }
}
