import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(SyncCoordinator.self)
    private var syncCoordinator

    @Query(MutationQueries.pendingByOldest)
    private var mutations: [Mutation]

    @State private var isSidebarOpen = false
    @State private var isSyncPresented = false

    private var hasConflicts: Bool {
        !syncCoordinator.conflicts.isEmpty
    }

    private var syncBadgeCount: Int {
        if hasConflicts {
            syncCoordinator.conflicts.count
        } else {
            mutations.count
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            TabView {
                Tab("Home", systemImage: "house") {
                    NavigationStack {
                        HomeView()
                            .toolbar {
                                appToolbar
                            }
                    }
                }

                Tab("Transactions", systemImage: "list.bullet") {
                    NavigationStack {
                        TransactionListView()
                            .toolbar {
                                appToolbar
                            }
                    }
                }

                Tab("Categories", systemImage: "square.grid.2x2") {
                    NavigationStack {
                        CategoryListView()
                            .toolbar {
                                appToolbar
                            }
                    }
                }
            }

            if isSidebarOpen {
                Color.black
                    .opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeSidebar()
                    }
                    .transition(.opacity)
                    .zIndex(1)

                AppSidebar(
                    mutationCount: mutations.count,
                    conflictCount: syncCoordinator.conflicts.count
                ) {
                    closeSidebar()
                    isSyncPresented = true
                }
                .frame(width: 300)
                .transition(
                    .move(edge: .leading)
                )
                .zIndex(2)
            }
        }
        .animation(
            .snappy,
            value: isSidebarOpen
        )
        .overlay(alignment: .leading) {
            if !isSidebarOpen {
                sidebarEdgeGesture
            }
        }
        .sheet(
            isPresented: $isSyncPresented
        ) {
            NavigationStack {
                SyncView()
            }
        }
        .background {
            UndoResponderView()
                .frame(width: 0, height: 0)
        }
    }

    @ToolbarContentBuilder
    private var appToolbar: some ToolbarContent {
        ToolbarItem(
            placement: .topBarLeading
        ) {
            Button(
                "Menu",
                systemImage: "line.3.horizontal"
            ) {
                openSidebar()
            }
        }

        if syncBadgeCount > 0 {
            ToolbarItem(
                placement: .topBarTrailing
            ) {
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
            .overlay(
                alignment: .topTrailing
            ) {
                Text(
                    syncBadgeCount > 99
                        ? "99+"
                        : "\(syncBadgeCount)"
                )
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .frame(
                    minWidth: 16,
                    minHeight: 16
                )
                .background(
                    hasConflicts
                        ? Color.red
                        : Color.accentColor,
                    in: Capsule()
                )
                .offset(
                    x: 9,
                    y: -8
                )
            }
        }
        .accessibilityLabel(
            hasConflicts
                ? "Synchronization conflicts"
                : "Pending synchronization"
        )
    }

    private var sidebarEdgeGesture: some View {
        Color.clear
            .frame(width: 24)
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .gesture(
                DragGesture(
                    minimumDistance: 12
                )
                .onEnded { value in
                    let horizontal =
                        value.translation.width

                    let vertical =
                        abs(value.translation.height)

                    guard
                        horizontal > 60,
                        horizontal > vertical
                    else {
                        return
                    }

                    openSidebar()
                }
            )
    }

    private func openSidebar() {
        withAnimation(.snappy) {
            isSidebarOpen = true
        }
    }

    private func closeSidebar() {
        withAnimation(.snappy) {
            isSidebarOpen = false
        }
    }
}
