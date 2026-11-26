import SwiftData
import SwiftUI

private enum AppTab: Hashable {
    case dashboard
    case transactions
    case categories
    case settings
}

private struct AutomaticSyncTaskID: Equatable {
    let isActive: Bool
    let isEnabled: Bool
    let interval: Int
}

struct RootView: View {
    @Environment(SyncCoordinator.self)
    private var syncCoordinator

    @Environment(NetworkMonitor.self)
    private var networkMonitor

    @Environment(\.scenePhase)
    private var scenePhase

    @Environment(AppSettings.self)
    private var settings

    @Query(MutationQueries.pendingByOldest)
    private var mutations: [Mutation]

    @State
    private var selectedTab: AppTab = .transactions

    @State
    private var isSyncPresented = false

    @State
    private var showOnlineStatus = false

    private var automaticSyncTaskID: AutomaticSyncTaskID {
        AutomaticSyncTaskID(
            isActive: scenePhase == .active,
            isEnabled: settings.automaticSyncEnabled && syncCoordinator.isProviderReady,
            interval: settings.syncInterval.rawValue
        )
    }

    private var connectivityStatusLabel: some View {
        let isOffline = networkMonitor.status == .offline

        return HStack(spacing: 5) {
            Circle()
                .fill(isOffline ? Color.red : Color.green)
                .frame(width: 7, height: 7)

            Text(isOffline ? "Offline" : "Online")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isOffline ? .red : .green)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(
                "Dashboard",
                systemImage: "rectangle.3.group",
                value: AppTab.dashboard
            ) {
                NavigationStack {
                    Dashboard()
                        .toolbar {
                            appToolbar
                        }
                }
            }

            Tab(
                "Transactions",
                systemImage: "list.bullet",
                value: AppTab.transactions
            ) {
                NavigationStack {
                    TransactionListView()
                        .toolbar {
                            appToolbar
                        }
                }
            }

            Tab(
                "Categories",
                systemImage: "square.grid.2x2",
                value: AppTab.categories
            ) {
                NavigationStack {
                    CategoryListView()
                        .toolbar {
                            appToolbar
                        }
                }
            }
            Tab(
                "Settings",
                systemImage: "gear",
                value: AppTab.settings
            ) {
                NavigationStack {
                    SettingsView()
                        .toolbar {
                            appToolbar
                        }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = syncCoordinator.synchronizationError {
                syncErrorBanner(error)
            }
        }
        .sheet(isPresented: $isSyncPresented) {
            NavigationStack {
                SyncView()
            }
        }
        .background {
            UndoResponderView()
                .frame(
                    width: 0,
                    height: 0
                )
        }
        .onChange(of: networkMonitor.status) { oldStatus, newStatus in
            if newStatus == .offline {
                showOnlineStatus = false
                return
            }

            guard oldStatus == .offline, newStatus == .online else {
                return
            }

            showOnlineStatus = true

            guard automaticSyncTaskID.isActive, automaticSyncTaskID.isEnabled else {
                return
            }

            Task {
                await syncCoordinator.synchronize(
                    trigger: .connectivityRestored
                )
            }
        }
        .task(id: automaticSyncTaskID) {
            guard automaticSyncTaskID.isActive, automaticSyncTaskID.isEnabled else {
                return
            }

            await syncCoordinator.runForegroundAutomaticSync(
                interval: settings.syncInterval.duration
            )
        }
        .task(id: showOnlineStatus) {
            guard showOnlineStatus else {
                return
            }

            try? await Task.sleep(for: .seconds(2))

            guard !Task.isCancelled else {
                return
            }

            showOnlineStatus = false
        }
    }

    @ToolbarContentBuilder
    private var appToolbar: some ToolbarContent {
        if networkMonitor.status == .offline || showOnlineStatus {
            ToolbarItem(placement: .principal) {
                connectivityStatusLabel
            }
        }

        let conflictCount = syncCoordinator.conflicts.count
        let hasConflicts = conflictCount > 0
        let badgeCount = hasConflicts ? conflictCount : mutations.count
        if syncCoordinator.isProviderReady, badgeCount > 0 {
            ToolbarItem(placement: .topBarTrailing) {
                syncStatusButton(count: badgeCount, hasConflicts: hasConflicts)
            }
        }
    }

    private func syncStatusButton(count: Int, hasConflicts: Bool) -> some View {
        Button {
            isSyncPresented = true
        } label: {
            Image(systemName: hasConflicts ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath")
                .overlay(alignment: .topTrailing) {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(hasConflicts ? Color.red : Color.accentColor, in: Capsule())
                        .offset(x: 9, y: -8)
                }
        }
        .accessibilityLabel(hasConflicts ? "Synchronization conflicts" : "Synchronization")
    }

    private func syncErrorBanner(_ error: SyncError) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(error.errorDescription ?? String(localized: "Synchronization failed."))
                    .font(.subheadline.weight(.semibold))

                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button {
                syncCoordinator.dismissSynchronizationError()
            } label: {
                Label("Close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}
