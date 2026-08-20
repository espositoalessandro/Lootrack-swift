import Foundation
import Observation

@MainActor
@Observable
final class SyncCoordinator {
    private let syncEngine: SyncEngine
    private let conflictResolutionService: ConflictResolutionService

    private var syncTask: Task<Void, Never>?

    var isSyncing = false
    var syncResult: String?
    var conflicts: [SyncConflictCandidate] = []

    init(syncEngine: SyncEngine,
         conflictResolutionService: ConflictResolutionService)
    {
        self.syncEngine = syncEngine
        self.conflictResolutionService =
            conflictResolutionService
    }

    func synchronize() async {
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
        isSyncing = true

        /*
         * Every synchronization attempt produces
         * a new reconciliation result.
         */
        conflicts = []
        syncResult = nil

        defer {
            isSyncing = false
            syncTask = nil
        }

        do {
            try await syncEngine.synchronize()

            syncResult =
                "Synchronization completed"

        } catch let error as SyncRunConflictError {
            conflicts = error.conflicts

        } catch {
            conflicts = []

            syncResult =
                "ERROR: \(String(describing: error))"

            print("Synchronization failed:",
                  error)
        }
    }

    func resolveConflict(_ conflict: SyncConflictCandidate,
                         using resolution: ConflictResolution)
    {
        do {
            try conflictResolutionService.resolve(conflict,
                                                  using: resolution)

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

            print("Conflict resolution failed:",
                  error)
        }
    }
}
