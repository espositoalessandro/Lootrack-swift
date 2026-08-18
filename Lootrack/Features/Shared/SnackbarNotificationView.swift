import SwiftUI

enum SnackbarNotificationStyle {
    case info
    case success
    case warning
    case danger

    var tint: Color {
        switch self {
        case .info:
            return .blue

        case .success:
            return .green

        case .warning:
            return .orange

        case .danger:
            return .red
        }
    }

    var defaultIcon: String {
        switch self {
        case .info:
            return "info.circle.fill"

        case .success:
            return "checkmark.circle.fill"

        case .warning:
            return "exclamationmark.triangle.fill"

        case .danger:
            return "exclamationmark.circle.fill"
        }
    }
}

enum SnackbarNotificationPosition {
    case top
    case bottom

    fileprivate var alignment: Alignment {
        switch self {
        case .top:
            return .top

        case .bottom:
            return .bottom
        }
    }

    fileprivate var paddingEdge: Edge.Set {
        switch self {
        case .top:
            return .top

        case .bottom:
            return .bottom
        }
    }

    fileprivate var transitionEdge: Edge {
        switch self {
        case .top:
            return .top

        case .bottom:
            return .bottom
        }
    }
}

struct SnackbarNotification: Identifiable {
    let id = UUID()

    let message: String
    let style: SnackbarNotificationStyle
    let icon: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let onDismiss: (() -> Void)?

    init(
        message: String,
        style: SnackbarNotificationStyle = .info,
        icon: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.message = message
        self.style = style
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
        self.onDismiss = onDismiss
    }
}

struct SnackbarNotificationView: View {
    let notification: SnackbarNotification
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(
                systemName:
                    notification.icon
                    ?? notification.style.defaultIcon
            )
            .font(.headline)
            .foregroundStyle(
                notification.style.tint
            )

            Text(notification.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 8)

            if let actionTitle = notification.actionTitle,
                notification.action != nil
            {
                Button(actionTitle) {
                    onAction()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    notification.style.tint
                )
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                notification.style.tint.opacity(0.3),
                lineWidth: 1
            )
        }
        .shadow(
            radius: 8,
            y: 3
        )
    }
}

private struct SnackbarNotificationModifier:
    ViewModifier
{
    @Binding
    var notification: SnackbarNotification?

    let position: SnackbarNotificationPosition
    let edgePadding: CGFloat
    let duration: Duration?

    func body(
        content: Content
    ) -> some View {
        content
            .overlay(
                alignment: position.alignment
            ) {
                if let notification {
                    let notificationId =
                        notification.id

                    SnackbarNotificationView(
                        notification: notification
                    ) {
                        notification.action?()

                        withAnimation(.snappy) {
                            self.notification = nil
                        }
                    }
                    .padding(.horizontal)
                    .padding(
                        position.paddingEdge,
                        edgePadding
                    )
                    .transition(
                        .move(
                            edge:
                                position
                                .transitionEdge
                        )
                        .combined(with: .opacity)
                    )
                    .task(id: notificationId) {
                        guard let duration else {
                            return
                        }

                        do {
                            try await Task.sleep(
                                for: duration
                            )
                        } catch {
                            return
                        }

                        guard
                            self.notification?.id
                                == notificationId
                        else {
                            return
                        }

                        withAnimation(.snappy) {
                            self.notification = nil
                        }
                    }
                    .onDisappear {
                        notification.onDismiss?()
                    }
                }
            }
            .animation(
                .snappy,
                value: notification?.id
            )
    }
}

extension View {
    func snackbar(
        notification:
            Binding<SnackbarNotification?>,
        position: SnackbarNotificationPosition =
            .bottom,
        edgePadding: CGFloat = 12,
        duration: Duration? = .seconds(5)
    ) -> some View {
        modifier(
            SnackbarNotificationModifier(
                notification: notification,
                position: position,
                edgePadding: edgePadding,
                duration: duration
            )
        )
    }
}
