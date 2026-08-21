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
            isEnabled: settings.automaticSyncEnabled,
            interval: settings.syncInterval.rawValue
        )
    }

    private var hasConflicts: Bool {
        !syncCoordinator.conflicts.isEmpty
    }

    private var syncBadgeCount: Int {
        if hasConflicts {
            return syncCoordinator.conflicts.count
        }

        return mutations.count
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

            guard scenePhase == .active, settings.automaticSyncEnabled
            else {
                return
            }

            Task {
                await syncCoordinator.synchronize(
                    trigger: .connectivityRestored
                )
            }
        }
        .task(id: automaticSyncTaskID) {
            guard scenePhase == .active,
                settings.automaticSyncEnabled
            else {
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

        if syncBadgeCount > 0 {
            ToolbarItem(placement: .topBarTrailing) {
                syncStatusButton
            }
        }
    }

    private var syncStatusButton: some View {
        Button {
            isSyncPresented = true
        } label: {
            Image(
                systemName:
                    hasConflicts
                    ? "exclamationmark.triangle.fill"
                    : "arrow.triangle.2.circlepath"
            )
            .overlay(alignment: .topTrailing) {
                if syncBadgeCount > 0 {
                    Text(syncBadgeCount > 99 ? "99+" : "\(syncBadgeCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(
                            hasConflicts ? Color.red : Color.accentColor,
                            in: Capsule()
                        )
                        .offset(x: 9, y: -8)
                }
            }
        }
        .accessibilityLabel(
            hasConflicts
                ? "Synchronization conflicts"
                : "Synchronization"
        )
    }
}
