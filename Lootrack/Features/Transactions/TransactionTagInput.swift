//
//  TransactionTagInput.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 19/08/2026.
//


import SwiftUI

struct TransactionTagInput: View {
    @Binding var tags: [String]

    let availableTags: [Tag]

    @State
    private var input = ""

    @FocusState
    private var isFocused: Bool

    private var suggestions: [Tag] {
        let query = input
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !query.isEmpty else {
            return []
        }

        return Array(
            availableTags
                .filter { tag in
                    !tags.contains(tag.name)
                        && tag.name.localizedCaseInsensitiveContains(
                            query
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
            if !tags.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(
                            tags,
                            id: \.self
                        ) { tag in
                            selectedTag(tag)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            TextField(
                "Add tag",
                text: $input
            )
            .focused($isFocused)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onChange(of: input) {
                inputDidChange()
            }
            .onSubmit {
                commitInput()
            }

            if !suggestions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(
                            suggestions,
                            id: \.name
                        ) { tag in
                            Button {
                                addTag(tag.name)
                                input = ""
                                restoreFocus()
                            } label: {
                                Label(
                                    tag.name,
                                    systemImage: "tag"
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .scrollIndicators(.hidden)
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
                .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func inputDidChange() {
        guard
            input.contains(
                where: \.isWhitespace
            )
        else {
            return
        }

        /*
         * Space means "commit tag". If a user
         * pastes multiple words at once, every
         * word becomes a tag in the same pass.
         */
        addTags(
            Tag.normalizedTokens(
                from: input
            )
        )

        input = ""
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

    private func restoreFocus() {
        Task { @MainActor in
            await Task.yield()
            isFocused = true
        }
    }
}
