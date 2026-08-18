import Foundation
import SwiftData
import SwiftUI

private enum CategorySelectionOrigin {
    case none
    case ai
    case human
}

struct TransactionForm: View {
    @Binding var draft: TransactionDraft

    let autoSelectCategoryWithAI: Bool

    @Query(CategoryQueries.activeByName)
    private var categories: [Category]

    @State private var categorySelectionOrigin: CategorySelectionOrigin = .none

    @State private var aiSelectionTask: Task<Void, Never>?
    @State private var activeAIRequestId: UUID?
    @State private var isSelectingCategoryWithAI = false

    init(
        draft: Binding<TransactionDraft>,
        autoSelectCategoryWithAI: Bool = false
    ) {
        self._draft = draft
        self.autoSelectCategoryWithAI = autoSelectCategoryWithAI
    }

    private var matchingCategories: [Category] {
        categories.filter { category in
            category.type == draft.type
        }
    }

    private var selectedCategory: Category? {
        guard let categoryId = draft.categoryId else {
            return nil
        }

        return matchingCategories.first { category in
            category.id == categoryId
        }
    }

    private var categorySelection: Binding<UUID?> {
        Binding(
            get: {
                draft.categoryId
            },
            set: { categoryId in
                // This setter is only invoked by the Picker,
                // so this is explicitly a human choice.
                cancelAISelection()

                draft.categoryId = categoryId
                categorySelectionOrigin = .human
            }
        )
    }

    var body: some View {
        Form {
            Section("Transaction") {
                TextField(
                    "Description",
                    text: $draft.note
                )
                .onChange(of: draft.note) {
                    descriptionDidChange()
                }

                TextField(
                    "Amount",
                    text: $draft.amount
                )
                .keyboardType(.decimalPad)
                .onChange(of: draft.amount) {
                    amountDidChange()
                }

                Picker(
                    "Type",
                    selection: $draft.type
                ) {
                    Text("Expense")
                        .tag(TransactionType.expense)

                    Text("Income")
                        .tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.type) {
                    transactionTypeDidChange()
                }

                Picker(
                    "Category",
                    selection: categorySelection
                ) {
                    Text("Uncategorized")
                        .tag(UUID?.none)

                    ForEach(matchingCategories) { category in
                        HStack(spacing: 5) {
                            Text(category.name)

                            if categorySelectionOrigin == .ai,
                                draft.categoryId == category.id
                            {
                                Image(systemName: "sparkles")
                            }
                        }
                        .tag(Optional(category.id))
                    }
                }

                if isSelectingCategoryWithAI {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)

                        Text("Selecting with Apple Intelligence…")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                DatePicker(
                    "Occurred on",
                    selection: $draft.occurredOn,
                    displayedComponents: .date
                )
            }
        }
        .onDisappear {
            cancelAISelection()
        }
    }

    // MARK: - Input changes

    private func descriptionDidChange() {
        guard autoSelectCategoryWithAI else {
            return
        }

        // A human-selected category owns the field.
        // Description changes must not touch it.
        guard categorySelectionOrigin != .human else {
            return
        }

        cancelAISelection()

        // An AI suggestion is now stale as soon as the
        // description changes.
        if categorySelectionOrigin == .ai {
            draft.categoryId = nil
            categorySelectionOrigin = .none
        }

        scheduleAISelection()
    }

    private func amountDidChange() {
        guard autoSelectCategoryWithAI else {
            return
        }

        // Amount isn't normally enough reason to replace an
        // existing category.
        //
        // This listener exists so that:
        //
        // 1. user types description first
        // 2. amount is still empty
        // 3. user then types amount
        // 4. AI can finally run
        guard categorySelectionOrigin == .none else {
            return
        }

        cancelAISelection()
        scheduleAISelection()
    }

    private func transactionTypeDidChange() {
        cancelAISelection()

        // A category from the previous type is invalid regardless
        // of whether it was chosen by AI or by the user.
        draft.categoryId = nil
        categorySelectionOrigin = .none

        guard autoSelectCategoryWithAI else {
            return
        }

        scheduleAISelection()
    }

    // MARK: - AI selection

    private func scheduleAISelection() {
        let description = draft.note
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !description.isEmpty else {
            isSelectingCategoryWithAI = false
            return
        }

        guard
            let amountInCents = draft.amountInCents,
            amountInCents > 0
        else {
            isSelectingCategoryWithAI = false
            return
        }

        guard !matchingCategories.isEmpty else {
            isSelectingCategoryWithAI = false
            return
        }

        guard CategoryAISelector.isAvailable else {
            isSelectingCategoryWithAI = false
            return
        }

        let requestId = UUID()

        // Capture everything belonging to THIS request.
        let requestedDescription = description
        let requestedAmount = amountInCents
        let requestedType = draft.type
        let requestedCategories = matchingCategories

        activeAIRequestId = requestId
        isSelectingCategoryWithAI = true

        aiSelectionTask = Task {
            do {
                // Debounce:
                //
                // every new character cancels this task and starts
                // another one, so AFM only gets called once the user
                // has stopped typing for a moment.
                try await Task.sleep(
                    for: .milliseconds(650)
                )

                try Task.checkCancellation()

                let categoryId =
                    try await CategoryAISelector.selectCategoryId(
                        description: requestedDescription,
                        amountInCents: requestedAmount,
                        type: requestedType,
                        categories: requestedCategories
                    )

                try Task.checkCancellation()

                // The request may technically have completed after
                // being invalidated. Never allow an old result to win.
                guard activeAIRequestId == requestId else {
                    return
                }

                // Most important safety check:
                // human input always wins.
                guard categorySelectionOrigin != .human else {
                    return
                }

                draft.categoryId = categoryId
                categorySelectionOrigin = .ai

            } catch is CancellationError {
                // Expected while typing or when the user selects
                // a category manually.
            } catch {
                guard activeAIRequestId == requestId else {
                    return
                }

                print(
                    "FAILED TO AUTO-SELECT CATEGORY:",
                    error
                )
            }

            if activeAIRequestId == requestId {
                activeAIRequestId = nil
                aiSelectionTask = nil
                isSelectingCategoryWithAI = false
            }
        }
    }

    private func cancelAISelection() {
        aiSelectionTask?.cancel()
        aiSelectionTask = nil

        activeAIRequestId = nil
        isSelectingCategoryWithAI = false
    }
}
