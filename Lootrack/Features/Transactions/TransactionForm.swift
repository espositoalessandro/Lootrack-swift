import Foundation
import SwiftData
import SwiftUI

private enum CategorySelectionOrigin {
    case none
    case ai
    case human
}

enum TransactionFormField: Hashable {
    case amount
    case description
}

private enum TransactionFormScrollTarget: Hashable {
    case tags
}

struct TransactionForm: View {
    @Binding var draft: TransactionDraft

    let autoSelectCategoryWithAI: Bool
    let quickAmountEntry: Bool

    @Query(CategoryQueries.activeByName)
    private var categories: [Category]

    @Query(SubcategoryQueries.activeByName)
    private var subcategories: [Subcategory]

    @Query(TagQueries.byName)
    private var tags: [Tag]

    @FocusState
    private var focusedField: TransactionFormField?

    @State
    private var categoryAISelector =
        CategoryAISelector()

    @State
    private var categorySelectionOrigin: CategorySelectionOrigin = .none

    @State
    private var aiSelectionTask: Task<Void, Never>?

    @State
    private var activeAIRequestId: UUID?

    @State
    private var isSelectingCategoryWithAI =
        false

    init(
        draft: Binding<TransactionDraft>,
        autoSelectCategoryWithAI: Bool = false,
        quickAmountEntry: Bool = false
    ) {
        self._draft = draft
        self.autoSelectCategoryWithAI =
            autoSelectCategoryWithAI
        self.quickAmountEntry =
            quickAmountEntry
    }

    private var matchingCategories: [Category] {
        categories.filter { category in
            category.type == draft.type
        }
    }

    private var matchingSubcategories: [Subcategory] {
        guard
            let categoryId =
                draft.categoryId
        else {
            return []
        }

        return subcategories.filter {
            subcategory in

            subcategory.categoryId
                == categoryId
        }
    }

    private var categorySelection: Binding<UUID?> {
        Binding(
            get: {
                draft.categoryId
            },
            set: { categoryId in
                /*
                 * This setter is only invoked by the
                 * Picker, so this is explicitly a human
                 * category choice.
                 */
                cancelAISelection()

                setCategory(
                    categoryId,
                    origin: .human
                )
            }
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section("Transaction") {
                    if quickAmountEntry {
                        TransactionAmountInput(
                            amount: $draft.amount,
                            focus: $focusedField
                        )
                        .listRowSeparator(
                            .hidden,
                            edges: .bottom
                        )
                    } else {
                        TextField(
                            "Amount",
                            text: $draft.amount
                        )
                        .keyboardType(.decimalPad)
                    }

                    TextField(
                        "Description",
                        text: $draft.note
                    )
                    .focused(
                        $focusedField,
                        equals: .description
                    )
                    .onChange(of: draft.note) {
                        descriptionDidChange()
                    }

                    Picker(
                        "Type",
                        selection: $draft.type
                    ) {
                        Text("Expense")
                            .tag(
                                TransactionType.expense
                            )

                        Text("Income")
                            .tag(
                                TransactionType.income
                            )
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: draft.type) {
                        transactionTypeDidChange()
                    }

                    Picker(
                        selection:
                            categorySelection
                    ) {
                        Text("Uncategorized")
                            .tag(UUID?.none)

                        ForEach(
                            matchingCategories
                        ) { category in
                            HStack(spacing: 5) {
                                Text(category.name)

                                if categorySelectionOrigin
                                    == .ai,
                                    draft.categoryId
                                        == category.id
                                {
                                    Image(
                                        systemName:
                                            "sparkles"
                                    )
                                }
                            }
                            .tag(
                                Optional(
                                    category.id
                                )
                            )
                        }
                    } label: {
                        HStack(
                            alignment:
                                .firstTextBaseline,
                            spacing: 6
                        ) {
                            Text("Category")

                            if isSelectingCategoryWithAI {
                                Image(
                                    systemName:
                                        "apple.intelligence"
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            .pink,
                                            .purple,
                                            .blue,
                                            .cyan,
                                        ],
                                        startPoint:
                                            .topLeading,
                                        endPoint:
                                            .bottomTrailing
                                    )
                                )
                                .symbolEffect(
                                    .breathe,
                                    options:
                                        .repeat(
                                            .continuous
                                        ),
                                    isActive:
                                        isSelectingCategoryWithAI
                                )

                                Text(
                                    "Selecting..."
                                )
                                .font(.caption2)
                                .foregroundStyle(
                                    .secondary
                                )
                                .lineLimit(1)
                            }
                        }
                    }

                    Picker(
                        "Subcategory",
                        selection:
                            $draft.subcategoryId
                    ) {
                        Text("None")
                            .tag(UUID?.none)

                        ForEach(
                            matchingSubcategories
                        ) { subcategory in
                            Text(
                                subcategory.name
                            )
                            .tag(
                                Optional(
                                    subcategory.id
                                )
                            )
                        }
                    }
                    .disabled(
                        draft.categoryId == nil
                    )

                    DatePicker(
                        "Occurred on",
                        selection:
                            $draft.occurredOn,
                        displayedComponents:
                            .date
                    )
                }

                Section("Tags") {
                    TagInput(
                        tags: $draft.tags,
                        availableTags: tags,
                        onNeedsVisibility: {
                            withAnimation(
                                .easeInOut(
                                    duration: 0.2
                                )
                            ) {
                                proxy.scrollTo(
                                    TransactionFormScrollTarget.tags,
                                    anchor: .bottom
                                )
                            }
                        }
                    )
                    .id(
                        TransactionFormScrollTarget.tags
                    )
                }
            }
        }
        .task {
            if autoSelectCategoryWithAI {
                categoryAISelector.prewarm(
                    categories:
                        matchingCategories
                )
            }

            if quickAmountEntry {
                await Task.yield()
                focusedField = .amount
            }
        }
        .toolbar {
            ToolbarItemGroup(
                placement: .keyboard
            ) {
                if focusedField == .amount {
                    Spacer()

                    Button("Next") {
                        focusedField =
                            .description
                    }
                }
            }
        }
        .onDisappear {
            cancelAISelection()
        }
    }

    // MARK: - Input changes

    private func descriptionDidChange() {
        guard
            autoSelectCategoryWithAI
        else {
            return
        }

        /*
         * A human-selected category owns the
         * field. Description changes must not
         * touch it.
         */
        guard
            categorySelectionOrigin
                != .human
        else {
            return
        }

        cancelAISelection()

        /*
         * An AI suggestion is stale as soon as
         * the description changes.
         */
        if categorySelectionOrigin == .ai {
            setCategory(
                nil,
                origin: .none
            )
        }

        scheduleAISelection()
    }

    private func transactionTypeDidChange() {
        cancelAISelection()

        /*
         * Type changes invalidate the category;
         * category changes always invalidate the
         * subcategory as agreed.
         */
        setCategory(
            nil,
            origin: .none
        )

        guard
            autoSelectCategoryWithAI
        else {
            return
        }

        categoryAISelector.prewarm(
            categories:
                matchingCategories
        )

        scheduleAISelection()
    }

    private func setCategory(
        _ categoryId: UUID?,
        origin: CategorySelectionOrigin
    ) {
        if draft.categoryId != categoryId {
            draft.categoryId = categoryId

            /*
             * Hard invariant for the form:
             * ANY category change resets
             * subcategory to nil.
             */
            draft.subcategoryId = nil
        } else {
            draft.categoryId = categoryId
        }

        categorySelectionOrigin = origin
    }

    // MARK: - AI selection

    private func scheduleAISelection() {
        let description = draft.note
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !description.isEmpty else {
            isSelectingCategoryWithAI =
                false
            return
        }

        guard !matchingCategories.isEmpty else {
            isSelectingCategoryWithAI =
                false
            return
        }

        guard
            CategoryAISelector.isAvailable
        else {
            isSelectingCategoryWithAI =
                false
            return
        }

        let requestId = UUID()

        let requestedDescription =
            description

        let requestedCategories =
            matchingCategories

        activeAIRequestId = requestId
        isSelectingCategoryWithAI = true

        aiSelectionTask = Task {
            do {
                try await Task.sleep(
                    for:
                        .milliseconds(
                            200
                        )
                )

                try Task.checkCancellation()

                let categoryId =
                    try await categoryAISelector
                    .selectCategoryId(
                        description:
                            requestedDescription,
                        categories:
                            requestedCategories
                    )

                try Task.checkCancellation()

                guard
                    activeAIRequestId
                        == requestId
                else {
                    return
                }

                guard
                    categorySelectionOrigin
                        != .human
                else {
                    return
                }

                setCategory(
                    categoryId,
                    origin: .ai
                )

            } catch is CancellationError {
                /*
                 * Normal while typing or
                 * manually selecting.
                 */
            } catch {
                guard
                    activeAIRequestId
                        == requestId
                else {
                    return
                }

                print(
                    "FAILED TO AUTO-SELECT CATEGORY:",
                    error
                )
            }

            if activeAIRequestId
                == requestId
            {
                activeAIRequestId = nil
                aiSelectionTask = nil
                isSelectingCategoryWithAI =
                    false
            }
        }
    }

    private func cancelAISelection() {
        aiSelectionTask?.cancel()
        aiSelectionTask = nil

        activeAIRequestId = nil
        isSelectingCategoryWithAI =
            false
    }
}
