//
//  TransactionTagInput.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 19/08/2026.
//

import SwiftUI

private struct TagFlowLayout: Layout {
    let horizontalSpacing: CGFloat = 8
    let verticalSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth =
            proposal.width ?? .infinity

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size =
                subview.sizeThatFits(
                    .unspecified
                )

            if currentX > 0,
                currentX + size.width > maxWidth
            {
                currentX = 0
                currentY +=
                    rowHeight
                    + verticalSpacing

                rowHeight = 0
            }

            currentX +=
                size.width
                + horizontalSpacing

            rowHeight = max(
                rowHeight,
                size.height
            )
        }

        return CGSize(
            width:
                proposal.width
                ?? currentX,
            height:
                currentY + rowHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX =
            bounds.minX

        var currentY =
            bounds.minY

        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size =
                subview.sizeThatFits(
                    .unspecified
                )

            if currentX > bounds.minX,
                currentX + size.width
                    > bounds.maxX
            {
                currentX =
                    bounds.minX

                currentY +=
                    rowHeight
                    + verticalSpacing

                rowHeight = 0
            }

            subview.place(
                at: CGPoint(
                    x: currentX,
                    y: currentY
                ),
                proposal:
                    ProposedViewSize(
                        size
                    )
            )

            currentX +=
                size.width
                + horizontalSpacing

            rowHeight = max(
                rowHeight,
                size.height
            )
        }
    }
}

struct TransactionTagInput: View {
    @Binding var tags: [String]

    let availableTags: [Tag]

    @State
    private var input = ""

    @FocusState
    private var isFocused: Bool

    private var trimmedInput: String {
        input.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var suggestions: [Tag] {
        guard !trimmedInput.isEmpty else {
            return []
        }

        return Array(
            availableTags
                .filter { tag in
                    !tags.contains(tag.name)
                        && tag.name
                            .localizedCaseInsensitiveContains(
                                trimmedInput
                            )
                }
                .prefix(5)
        )
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            TagFlowLayout {
                ForEach(
                    tags,
                    id: \.self
                ) { tag in
                    selectedTag(tag)
                }
                
                TextField(
                    "Add tag",
                    text: $input
                )
                .frame(
                    minWidth: 90,
                    idealWidth: 120,
                    maxWidth: 150
                )
                .padding(
                    .vertical,
                    4
                )
                .focused($isFocused)
                .textInputAutocapitalization(
                    .words
                )
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onChange(of: input) {
                    inputDidChange()
                }
                .onSubmit {
                    submit()
                }
            }

            if !suggestions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(
                            suggestions,
                            id: \.name
                        ) { tag in
                            Button {
                                addTag(
                                    tag.name
                                )

                                input = ""

                                restoreFocus()
                            } label: {
                                Label(
                                    tag.name,
                                    systemImage:
                                        "tag"
                                )
                            }
                            .buttonStyle(
                                .bordered
                            )
                            .controlSize(
                                .small
                            )
                        }
                    }
                }
                .scrollIndicators(
                    .hidden
                )
            }
        }
    }

    private func selectedTag(
        _ tag: String
    ) -> some View {
        Button {
            tags.removeAll {
                $0 == tag
            }

            restoreFocus()
        } label: {
            HStack(spacing: 5) {
                Text(tag)

                Image(
                    systemName:
                        "xmark.circle.fill"
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Input

    private func inputDidChange() {
        guard
            input.contains(
                where: \.isWhitespace
            )
        else {
            return
        }

        /*
         * Space means "commit tag".
         *
         * If multiple words are pasted,
         * each word becomes its own tag.
         */
        addTags(
            Tag.normalizedTokens(
                from: input
            )
        )

        input = ""
    }

    private func submit() {
        guard !trimmedInput.isEmpty else {
            isFocused = false
            return
        }

        commitInput()
    }

    private func commitInput() {
        addTags(
            Tag.normalizedTokens(
                from: input
            )
        )

        input = ""

        restoreFocus()
    }

    // MARK: - Tags

    private func addTags(
        _ newTags: [String]
    ) {
        for tag in newTags {
            addTag(tag)
        }
    }

    private func addTag(
        _ tag: String
    ) {
        guard !tags.contains(tag) else {
            return
        }

        tags.append(tag)
    }

    // MARK: - Focus

    private func restoreFocus() {
        Task { @MainActor in
            await Task.yield()

            isFocused = true
        }
    }
}
