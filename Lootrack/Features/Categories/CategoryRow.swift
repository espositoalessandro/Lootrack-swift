import SwiftUI

struct CategoryRow: View {
    let category: Category
    let subcategories: [Subcategory]

    let onEdit: () -> Void
    let onDelete: () -> Void

    @State
    private var isExpanded = false

    private var typeLabel: String {
        switch category.type {
        case .expense:
            return String(localized: "Expense")

        case .income:
            return String(localized: "Income")
        }
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
                uiColor:
                    .secondarySystemGroupedBackground
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
            allowsFullSwipe: false
        ) {
            Button(
                "Delete",
                systemImage: "trash",
                role: .destructive
            ) {
                onDelete()
            }
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
                .easeInOut(
                    duration: 0.2
                )
            ) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(
                    minLength: 12
                )

                Text(typeLabel)
                    .foregroundStyle(
                        .secondary
                    )

                Image(
                    systemName:
                        "chevron.right"
                )
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )
                .foregroundStyle(
                    .secondary
                )
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
            .contentShape(
                Rectangle()
            )
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details

    private var details: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            Divider()

            descriptionSection

            subcategoriesSection

            Divider()

            actions
        }
        .padding(
            .horizontal,
            16
        )
        .padding(
            .bottom,
            16
        )
    }

    private var descriptionSection: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("Description")
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )

            if category.note.isEmpty {
                Text(
                    "No description"
                )
                .foregroundStyle(
                    .secondary
                )
            } else {
                Text(category.note)
                    .foregroundStyle(
                        .secondary
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }
        }
    }

    private var subcategoriesSection: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text("Subcategories")
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )

            if subcategories.isEmpty {
                Text("None")
                    .foregroundStyle(
                        .secondary
                    )
            } else {
                FlowLayout(
                    horizontalSpacing: 6,
                    verticalSpacing: 6
                ) {
                    ForEach(
                        subcategories
                    ) { subcategory in
                        Chip(
                            subcategory.name
                        )
                    }
                }
            }
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
            .buttonStyle(
                .borderedProminent
            )

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
            .buttonStyle(
                .bordered
            )
            .tint(.red)
        }
        .controlSize(.large)
    }
}
