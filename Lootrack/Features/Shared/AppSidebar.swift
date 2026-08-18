import SwiftUI

struct AppSidebar: View {
    let mutationCount: Int
    let conflictCount: Int

    let openSync: () -> Void

    private var count: Int {
        conflictCount > 0
            ? conflictCount
            : mutationCount
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 24
        ) {
            Text("Lootrack")
                .font(.title.bold())

            Divider()

            Button {
                openSync()
            } label: {
                HStack {
                    Label(
                        "Synchronization",
                        systemImage:
                            conflictCount > 0
                            ? "exclamationmark.triangle.fill"
                            : "arrow.triangle.2.circlepath"
                    )

                    Spacer()

                    if count > 0 {
                        Text("\(count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                .thinMaterial,
                                in: Capsule()
                            )
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
        .safeAreaPadding(.top)
        .frame(
            maxHeight: .infinity,
            alignment: .top
        )
        .background(.regularMaterial)
        .gesture(
            DragGesture()
                .onEnded { value in
                    guard
                        value.translation.width < -60
                    else {
                        return
                    }

                    openSyncOrClose(false)
                }
        )
    }

    private func openSyncOrClose(
        _ shouldOpenSync: Bool
    ) {
        if shouldOpenSync {
            openSync()
        }
    }
}
