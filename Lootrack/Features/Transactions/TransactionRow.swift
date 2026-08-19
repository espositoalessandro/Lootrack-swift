import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    let categoryName: String?
    let subcategoryName: String?

    let onEdit: () -> Void
    let onDelete: () -> Void

    @State
    private var isExpanded = false

    private var categoryPath: String {
        let category =
            categoryName
            ?? String(localized: "Uncategorized")

        guard let subcategoryName else {
            return category
        }

        return "\(category) → \(subcategoryName)"
    }

    private var formattedAmount: String {
        (Double(transaction.amountInCents)
            / 100)
            .formatted(
                .currency(code: "EUR")
            )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isExpanded {
                details
                    .transition(.opacity)
            }
        }
        .background(
            Color(
                uiColor: .secondarySystemGroupedBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .padding(.horizontal, 16)
        .swipeActions(
            edge: .trailing,
            allowsFullSwipe: true
        ) {
            Button(
                "Delete",
                systemImage: "trash",
                role: .destructive
            ) {
                onDelete()
            }

            Button(
                "Edit",
                systemImage: "pencil"
            ) {
                onEdit()
            }
            .tint(.blue)
        }
        .swipeActions(
            edge: .leading,
            allowsFullSwipe: true
        ) {
            Button(
                "Edit",
                systemImage: "pencil"
            ) {
                onEdit()
            }
            .tint(.blue)
        }
    }

    // MARK: - Header

    private var header: some View {
        Button {
            withAnimation(
                .easeInOut(duration: 0.2)
            ) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(transaction.note)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(categoryPath)
                        .foregroundStyle(.secondary)
                }

                Spacer(
                    minLength: 12
                )

                Text(formattedAmount)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        transaction.type == .expense
                            ? .red
                            : .green
                    )

                Image(
                    systemName: "chevron.right"
                )
                .font(
                    .subheadline.weight(.semibold)
                )
                .foregroundStyle(.secondary)
                .rotationEffect(
                    isExpanded
                        ? .degrees(90)
                        : .zero
                )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .contentShape(Rectangle())
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details

    private var details: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            Divider()

            tagsRow

            metadataRow(
                title: String(localized: "Created"),
                value:
                    transaction.createdAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
            )

            Divider()

            actions
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var tagsRow: some View {
        HStack(
            alignment: .top,
            spacing: 16
        ) {
            Text("Tags")
                .foregroundStyle(.primary)
            
            Spacer(
                minLength: 16
            )
            
            if transaction.tags.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(
                    horizontalSpacing: 6,
                    verticalSpacing: 6
                ) {
                    ForEach(
                        transaction.tags,
                        id: \.self
                    ) { tag in
                        Chip(tag)
                    }
                }
                .frame(
                    maxWidth: 220,
                    alignment: .trailing
                )
            }
        }
    }
    
    private func metadataRow(
        title: String,
        value: String
    ) -> some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 16
        ) {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                onEdit()
            } label: {
                Label(
                    "Edit",
                    systemImage: "pencil"
                )
                .frame(
                    maxWidth: .infinity
                )
            }
            .buttonStyle(.borderedProminent)

            Button(
                role: .destructive
            ) {
                onDelete()
            } label: {
                Label(
                    "Delete",
                    systemImage: "trash"
                )
                .frame(
                    maxWidth: .infinity
                )
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .controlSize(.large)
    }
}
