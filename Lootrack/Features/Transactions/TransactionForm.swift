import Foundation
import SwiftData
import SwiftUI

private enum AISelectionOrigin {
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
    let autoSelectSubcategoryWithAI: Bool
    let quickAmountEntry: Bool

    @Query(CategoryQueries.activeByName)
    private var categories: [Category]

    @Query(SubcategoryQueries.activeByName)
    private var subcategories: [Subcategory]

    @Query(TagQueries.byName)
    private var tags: [Tag]

    @FocusState
    private var focusedField: TransactionFormField?

    // MARK: - AI Selectors

    @State
    private var categoryAISelector =
        CategoryAISelector()

    @State
    private var subcategoryAISelector =
        SubcategoryAISelector()

    // MARK: - Selection Ownership

    @State
    private var categorySelectionOrigin: AISelectionOrigin = .none

    @State
    private var subcategorySelectionOrigin: AISelectionOrigin = .none

    // MARK: - Category AI State

    @State
    private var categoryAISelectionTask: Task<Void, Never>?

    @State
    private var activeCategoryAIRequestId: UUID?

    @State
    private var isSelectingCategoryWithAI =
        false

    // MARK: - Subcategory AI State

    @State
    private var subcategoryAISelectionTask: Task<Void, Never>?

    @State
    private var activeSubcategoryAIRequestId: UUID?

    @State
    private var isSelectingSubcategoryWithAI =
        false

    init(
        draft: Binding<TransactionDraft>,
        autoSelectCategoryWithAI: Bool = false,
        autoSelectSubcategoryWithAI: Bool = false,
        quickAmountEntry: Bool = false
    ) {
        self._draft = draft

        self.autoSelectCategoryWithAI =
            autoSelectCategoryWithAI

        self.autoSelectSubcategoryWithAI =
            autoSelectSubcategoryWithAI

        self.quickAmountEntry =
            quickAmountEntry
    }

    // MARK: - Available Values

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

    private var selectedCategory: Category? {
        guard
            let categoryId =
                draft.categoryId
        else {
            return nil
        }

        return categories.first {
            category in

            category.id
                == categoryId
        }
    }

    // MARK: - Picker Bindings

    private var categorySelection: Binding<UUID?> {
        Binding(
            get: {
                draft.categoryId
            },
            set: { categoryId in
                /*
                 * This setter is invoked by the
                 * Picker, therefore this is an
                 * explicitly human-owned choice.
                 */

                cancelCategoryAISelection()
                cancelSubcategoryAISelection()

                setCategory(
                    categoryId,
                    origin: .human
                )

                /*
                 * A manually selected category can
                 * still have its subcategory inferred.
                 */
                prewarmSubcategoryAI()
                scheduleSubcategoryAISelection()
            }
        )
    }

    private var subcategorySelection: Binding<UUID?> {
        Binding(
            get: {
                draft.subcategoryId
            },
            set: { subcategoryId in
                /*
                 * Once the user touches this Picker,
                 * AFM no longer owns the field.
                 */

                cancelSubcategoryAISelection()

                setSubcategory(
                    subcategoryId,
                    origin: .human
                )
            }
        )
    }

    // MARK: - Body

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
                        .keyboardType(
                            .decimalPad
                        )
                    }

                    TextField(
                        "Description",
                        text: $draft.note
                    )
                    .focused(
                        $focusedField,
                        equals: .description
                    )
                    .onChange(
                        of: draft.note
                    ) {
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
                    .pickerStyle(
                        .segmented
                    )
                    .onChange(
                        of: draft.type
                    ) {
                        transactionTypeDidChange()
                    }

                    categoryPicker

                    subcategoryPicker

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
                        tags:
                            $draft.tags,
                        availableTags:
                            tags,
                        onNeedsVisibility: {
                            withAnimation(
                                .easeInOut(
                                    duration: 0.2
                                )
                            ) {
                                proxy.scrollTo(
                                    TransactionFormScrollTarget
                                        .tags,
                                    anchor: .bottom
                                )
                            }
                        }
                    )
                    .id(
                        TransactionFormScrollTarget
                            .tags
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

            if autoSelectSubcategoryWithAI {
                prewarmSubcategoryAI()
            }

            if quickAmountEntry {
                await Task.yield()

                focusedField =
                    .amount
            }
        }
        .toolbar {
            ToolbarItemGroup(
                placement: .keyboard
            ) {
                if focusedField
                    == .amount
                {
                    Spacer()

                    Button("Next") {
                        focusedField =
                            .description
                    }
                }
            }
        }
        .onDisappear {
            cancelAllAISelection()
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        Picker(
            selection:
                categorySelection
        ) {
            Text("Uncategorized")
                .tag(
                    UUID?.none
                )

            ForEach(
                matchingCategories
            ) { category in
                HStack(spacing: 5) {
                    Text(
                        category.name
                    )

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
                    aiSelectionIndicator(
                        isActive:
                            isSelectingCategoryWithAI
                    )
                }
            }
        }
    }

    // MARK: - Subcategory Picker

    private var subcategoryPicker: some View {
        Picker(
            selection:
                subcategorySelection
        ) {
            Text("None")
                .tag(
                    UUID?.none
                )

            ForEach(
                matchingSubcategories
            ) { subcategory in
                HStack(spacing: 5) {
                    Text(
                        subcategory.name
                    )

                    if subcategorySelectionOrigin
                        == .ai,
                        draft.subcategoryId
                            == subcategory.id
                    {
                        Image(
                            systemName:
                                "sparkles"
                        )
                    }
                }
                .tag(
                    Optional(
                        subcategory.id
                    )
                )
            }
        } label: {
            HStack(
                alignment:
                    .firstTextBaseline,
                spacing: 6
            ) {
                Text("Subcategory")

                if isSelectingSubcategoryWithAI {
                    aiSelectionIndicator(
                        isActive:
                            isSelectingSubcategoryWithAI
                    )
                }
            }
        }
        .disabled(
            draft.categoryId == nil
        )
    }

    // MARK: - AI Indicator

    private func aiSelectionIndicator(
        isActive: Bool
    ) -> some View {
        HStack(spacing: 5) {
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
                    isActive
            )

            Text("Selecting...")
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(1)
        }
    }

    // MARK: - Input Changes

    private func descriptionDidChange() {
        /*
         * If AFM still owns Category, it must
         * resolve Category first.
         *
         * Subcategory selection will be started
         * as soon as Category finishes.
         */
        if autoSelectCategoryWithAI,
            categorySelectionOrigin
                != .human
        {
            cancelCategoryAISelection()
            cancelSubcategoryAISelection()

            /*
             * Existing AFM values become stale
             * immediately when the description
             * changes.
             */
            if categorySelectionOrigin
                == .ai
            {
                setCategory(
                    nil,
                    origin: .none
                )
            }

            scheduleCategoryAISelection()

            return
        }

        /*
         * Category is human-owned or its AI
         * autocomplete is disabled.
         *
         * Subcategory can therefore be inferred
         * independently.
         */
        guard
            autoSelectSubcategoryWithAI
        else {
            return
        }

        guard
            subcategorySelectionOrigin
                != .human
        else {
            return
        }

        cancelSubcategoryAISelection()

        if subcategorySelectionOrigin
            == .ai
        {
            setSubcategory(
                nil,
                origin: .none
            )
        }

        prewarmSubcategoryAI()
        scheduleSubcategoryAISelection()
    }

    private func transactionTypeDidChange() {
        cancelAllAISelection()

        /*
         * Type invalidates Category.
         * Category invalidates Subcategory.
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

        scheduleCategoryAISelection()
    }

    // MARK: - Value Setters

    private func setCategory(
        _ categoryId: UUID?,
        origin: AISelectionOrigin
    ) {
        if draft.categoryId
            != categoryId
        {
            draft.categoryId =
                categoryId

            /*
             * Hard form invariant:
             * any Category change invalidates
             * the selected Subcategory.
             */
            draft.subcategoryId =
                nil

            subcategorySelectionOrigin =
                .none
        } else {
            draft.categoryId =
                categoryId
        }

        categorySelectionOrigin =
            origin
    }

    private func setSubcategory(
        _ subcategoryId: UUID?,
        origin: AISelectionOrigin
    ) {
        draft.subcategoryId =
            subcategoryId

        subcategorySelectionOrigin =
            origin
    }

    // MARK: - Category AI

    private func scheduleCategoryAISelection() {
        let description =
            draft.note
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard
            !description.isEmpty
        else {
            isSelectingCategoryWithAI =
                false

            return
        }

        guard
            !matchingCategories.isEmpty
        else {
            isSelectingCategoryWithAI =
                false

            return
        }

        guard
            CategoryAISelector
                .isAvailable
        else {
            isSelectingCategoryWithAI =
                false

            return
        }

        guard
            categorySelectionOrigin
                != .human
        else {
            isSelectingCategoryWithAI =
                false

            return
        }

        let requestId =
            UUID()

        let requestedDescription =
            description

        let requestedCategories =
            matchingCategories

        activeCategoryAIRequestId =
            requestId

        isSelectingCategoryWithAI =
            true

        categoryAISelectionTask =
            Task {
                do {
                    try await Task.sleep(
                        for:
                            .milliseconds(
                                200
                            )
                    )

                    try Task
                        .checkCancellation()

                    let categoryId =
                        try await categoryAISelector
                        .selectCategoryId(
                            description:
                                requestedDescription,
                            categories:
                                requestedCategories
                        )

                    try Task
                        .checkCancellation()

                    guard
                        activeCategoryAIRequestId
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

                    /*
                     * Category is now known.
                     * Subcategory inference can
                     * immediately follow it.
                     */
                    if autoSelectSubcategoryWithAI {
                        prewarmSubcategoryAI()
                        scheduleSubcategoryAISelection()
                    }

                } catch is CancellationError {
                    /*
                     * Expected while typing or
                     * manually selecting.
                     */
                } catch {
                    guard
                        activeCategoryAIRequestId
                            == requestId
                    else {
                        return
                    }

                    print(
                        "FAILED TO AUTO-SELECT CATEGORY:",
                        error
                    )
                }

                if activeCategoryAIRequestId
                    == requestId
                {
                    activeCategoryAIRequestId =
                        nil

                    categoryAISelectionTask =
                        nil

                    isSelectingCategoryWithAI =
                        false
                }
            }
    }

    private func cancelCategoryAISelection() {
        categoryAISelectionTask?
            .cancel()

        categoryAISelectionTask =
            nil

        activeCategoryAIRequestId =
            nil

        isSelectingCategoryWithAI =
            false
    }

    // MARK: - Subcategory AI

    private func prewarmSubcategoryAI() {
        guard
            autoSelectSubcategoryWithAI
        else {
            return
        }

        guard
            let category =
                selectedCategory
        else {
            return
        }

        guard
            !matchingSubcategories.isEmpty
        else {
            return
        }

        subcategoryAISelector.prewarm(
            category:
                category,
            subcategories:
                matchingSubcategories
        )
    }

    private func scheduleSubcategoryAISelection() {
        guard
            autoSelectSubcategoryWithAI
        else {
            return
        }

        guard
            subcategorySelectionOrigin
                != .human
        else {
            isSelectingSubcategoryWithAI =
                false

            return
        }

        let description =
            draft.note
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard
            !description.isEmpty
        else {
            isSelectingSubcategoryWithAI =
                false

            return
        }

        guard
            let categoryId =
                draft.categoryId,
            let category =
                selectedCategory
        else {
            isSelectingSubcategoryWithAI =
                false

            return
        }

        guard
            !matchingSubcategories.isEmpty
        else {
            isSelectingSubcategoryWithAI =
                false

            return
        }

        guard
            SubcategoryAISelector
                .isAvailable
        else {
            isSelectingSubcategoryWithAI =
                false

            return
        }

        let requestId =
            UUID()

        let requestedDescription =
            description

        let requestedCategoryId =
            categoryId

        let requestedCategory =
            category

        let requestedSubcategories =
            matchingSubcategories

        activeSubcategoryAIRequestId =
            requestId

        isSelectingSubcategoryWithAI =
            true

        subcategoryAISelectionTask =
            Task {
                do {
                    try await Task.sleep(
                        for:
                            .milliseconds(
                                200
                            )
                    )

                    try Task
                        .checkCancellation()

                    let subcategoryId =
                        try await subcategoryAISelector
                        .selectSubcategoryId(
                            description:
                                requestedDescription,
                            category:
                                requestedCategory,
                            subcategories:
                                requestedSubcategories
                        )

                    try Task
                        .checkCancellation()

                    guard
                        activeSubcategoryAIRequestId
                            == requestId
                    else {
                        return
                    }

                    /*
                     * Never apply a stale result
                     * generated for a previous
                     * Category.
                     */
                    guard
                        draft.categoryId
                            == requestedCategoryId
                    else {
                        return
                    }

                    guard
                        subcategorySelectionOrigin
                            != .human
                    else {
                        return
                    }

                    setSubcategory(
                        subcategoryId,
                        origin: .ai
                    )

                } catch is CancellationError {
                    /*
                     * Expected while typing,
                     * changing Category, or manually
                     * selecting a Subcategory.
                     */
                } catch {
                    guard
                        activeSubcategoryAIRequestId
                            == requestId
                    else {
                        return
                    }

                    print(
                        "FAILED TO AUTO-SELECT SUBCATEGORY:",
                        error
                    )
                }

                if activeSubcategoryAIRequestId
                    == requestId
                {
                    activeSubcategoryAIRequestId =
                        nil

                    subcategoryAISelectionTask =
                        nil

                    isSelectingSubcategoryWithAI =
                        false
                }
            }
    }

    private func cancelSubcategoryAISelection() {
        subcategoryAISelectionTask?
            .cancel()

        subcategoryAISelectionTask =
            nil

        activeSubcategoryAIRequestId =
            nil

        isSelectingSubcategoryWithAI =
            false
    }

    private func cancelAllAISelection() {
        cancelCategoryAISelection()
        cancelSubcategoryAISelection()
    }
}
