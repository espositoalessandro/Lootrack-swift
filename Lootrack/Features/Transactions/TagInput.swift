import SwiftUI

struct TagInput: View {
    @Binding var tags: [String]

    let availableTags: [Tag]
    let onNeedsVisibility: () -> Void

    @State
    private var input = ""

    @FocusState
    private var isFocused: Bool

    init(tags: Binding<[String]>,
         availableTags: [Tag],
         onNeedsVisibility: @escaping () -> Void = {})
    {
        _tags = tags
        self.availableTags = availableTags
        self.onNeedsVisibility = onNeedsVisibility
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestions: [Tag] {
        guard !trimmedInput.isEmpty else {
            return []
        }

        return Array(availableTags
            .filter { tag in
                !tags.contains(tag.name)
                    && tag.name
                    .localizedCaseInsensitiveContains(trimmedInput)
            }
            .prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading,
               spacing: 10)
        {
            FlowLayout {
                ForEach(tags,
                        id: \.self)
                { tag in
                    Chip(tag,
                         trailingSystemImage:
                         "xmark.circle.fill")
                    {
                        removeTag(tag)
                    }
                }

                TextField("Add tag",
                          text: $input)
                    .frame(minWidth: 90,
                           idealWidth: 120,
                           maxWidth: 150)
                    .padding(.vertical,
                             4)
                    .focused($isFocused)
                    .textInputAutocapitalization(.words)
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
                        ForEach(suggestions,
                                id: \.name)
                        { tag in
                            Chip(tag.name,
                                 leadingSystemImage:
                                 "tag")
                            {
                                addTag(tag.name)

                                input = ""

                                restoreFocus()
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .onChange(of: isFocused) {
            guard isFocused else {
                return
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))

                guard isFocused else {
                    return
                }

                onNeedsVisibility()
            }
        }
        .onChange(of: suggestions.count) {
            guard
                isFocused,
                !suggestions.isEmpty
            else {
                return
            }

            onNeedsVisibility()
        }
    }

    // MARK: - Input

    private func inputDidChange() {
        guard
            input.contains(where: \.isWhitespace)
        else {
            return
        }

        /*
         * Space means "commit tag".
         *
         * If multiple words are pasted,
         * each word becomes its own tag.
         */
        addTags(Tag.normalizedTokens(from: input))

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
        addTags(Tag.normalizedTokens(from: input))

        input = ""

        restoreFocus()
    }

    // MARK: - Tags

    private func addTags(_ newTags: [String]) {
        for tag in newTags {
            addTag(tag)
        }
    }

    private func addTag(_ tag: String) {
        guard !tags.contains(tag) else {
            return
        }

        tags.append(tag)
    }

    private func removeTag(_ tag: String) {
        tags.removeAll {
            $0 == tag
        }

        restoreFocus()
    }

    // MARK: - Focus

    private func restoreFocus() {
        Task { @MainActor in
            await Task.yield()

            isFocused = true
        }
    }
}
