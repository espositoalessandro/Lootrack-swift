import Foundation
import FoundationModels

enum SubcategoryAISelectorError: LocalizedError {
    case modelUnavailable
    case noSubcategories
    case invalidSelection

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return
                "Apple Intelligence isn't available on this device right now."

        case .noSubcategories:
            return
                "There are no subcategories available."

        case .invalidSelection:
            return
                "The model returned an invalid subcategory."
        }
    }
}

@MainActor
final class SubcategoryAISelector {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    private var prewarmedSession: LanguageModelSession?

    private var prewarmedContextKey: String?

    func prewarm(
        category: Category,
        subcategories: [Subcategory]
    ) {
        guard Self.isAvailable else {
            return
        }

        guard !subcategories.isEmpty else {
            return
        }

        let promptPrefix =
            makePromptPrefix(
                category: category,
                subcategories: subcategories
            )

        guard
            prewarmedContextKey
                != promptPrefix
        else {
            return
        }

        let session =
            makeSession()

        prewarmedSession =
            session

        prewarmedContextKey =
            promptPrefix

        session.prewarm(
            promptPrefix:
                Prompt(
                    promptPrefix
                )
        )
    }

    func selectSubcategoryId(
        description: String,
        category: Category,
        subcategories: [Subcategory]
    ) async throws -> UUID {
        guard !subcategories.isEmpty else {
            throw
                SubcategoryAISelectorError
                .noSubcategories
        }

        guard Self.isAvailable else {
            throw
                SubcategoryAISelectorError
                .modelUnavailable
        }

        let subcategoryCodes =
            subcategories.indices.map(
                String.init
            )

        let subcategoryCodeSchema =
            DynamicGenerationSchema(
                type: String.self,
                guides: [
                    .anyOf(
                        subcategoryCodes
                    )
                ]
            )

        let selectionSchema =
            DynamicGenerationSchema(
                name:
                    "SubcategorySelection",
                properties: [
                    DynamicGenerationSchema
                        .Property(
                            name:
                                "subcategoryCode",
                            description:
                                "Code of the best matching subcategory.",
                            schema:
                                subcategoryCodeSchema
                        )
                ]
            )

        let schema =
            try GenerationSchema(
                root:
                    selectionSchema,
                dependencies: []
            )

        let promptPrefix =
            makePromptPrefix(
                category: category,
                subcategories: subcategories
            )

        let session: LanguageModelSession

        if prewarmedContextKey
            == promptPrefix,
            let prewarmedSession
        {
            session =
                prewarmedSession
        } else {
            session =
                makeSession()
        }

        self.prewarmedSession =
            nil

        prewarmedContextKey =
            nil

        let prompt =
            promptPrefix
            + "\n"
            + description

        #if DEBUG
            let clock =
                ContinuousClock()

            let start =
                clock.now
        #endif

        let response =
            try await session.respond(
                to: Prompt(prompt),
                schema: schema
            )

        #if DEBUG
            print(
                "SUBCATEGORY AI INFERENCE:",
                start.duration(
                    to: clock.now
                )
            )
        #endif

        let subcategoryCode: String =
            try response.content.value(
                String.self,
                forProperty:
                    "subcategoryCode"
            )

        guard
            let subcategoryIndex =
                Int(subcategoryCode),
            subcategories.indices
                .contains(
                    subcategoryIndex
                )
        else {
            throw
                SubcategoryAISelectorError
                .invalidSelection
        }

        return subcategories[
            subcategoryIndex
        ].id
    }

    private func makeSession()
        -> LanguageModelSession
    {
        LanguageModelSession(
            instructions: """
                Categorize personal finance transactions for an Italian user.

                The parent category has already been selected by the app.

                Choose exactly one of the subcategories provided by the app.

                Never invent a new subcategory.
                """
        )
    }

    private func makePromptPrefix(
        category: Category,
        subcategories: [Subcategory]
    ) -> String {
        let categoryNote =
            category.note
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        let categoryContext: String

        if categoryNote.isEmpty {
            categoryContext =
                category.name
        } else {
            categoryContext = """
                \(category.name)

                \(categoryNote)
                """
        }

        let subcategoryContext =
            subcategories
            .enumerated()
            .map {
                index,
                subcategory in

                "\(index): \(subcategory.name)"
            }
            .joined(
                separator: "\n"
            )

        return """
            Choose the subcategory that best matches this personal finance transaction.

            Parent category:

            \(categoryContext)

            Available subcategories:

            \(subcategoryContext)

            Description:
            """
    }
}
