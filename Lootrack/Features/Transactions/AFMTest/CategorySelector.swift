import Foundation
import FoundationModels

enum CategoryAISelectorError: LocalizedError {
    case modelUnavailable
    case noCategories
    case invalidSelection

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return
                "Apple Intelligence isn't available on this device right now."

        case .noCategories:
            return
                "There are no categories available."

        case .invalidSelection:
            return
                "The model returned an invalid category."
        }
    }
}

@MainActor
final class CategoryAISelector {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    private var prewarmedSession: LanguageModelSession?

    private var prewarmedContextKey: String?

    func prewarm(
        categories: [Category]
    ) {
        guard Self.isAvailable else {
            return
        }

        guard !categories.isEmpty else {
            return
        }

        let promptPrefix =
            makePromptPrefix(
                categories: categories
            )

        guard
            prewarmedContextKey
                != promptPrefix
        else {
            return
        }

        let session = makeSession()

        prewarmedSession = session
        prewarmedContextKey = promptPrefix

        session.prewarm(
            promptPrefix: Prompt(
                promptPrefix
            )
        )
    }

    private func makeSession()
        -> LanguageModelSession
    {
        LanguageModelSession(
            instructions: """
                Categorize personal finance transactions for an Italian user.

                Choose exactly one of the categories provided by the app.
                """
        )
    }

    func selectCategoryId(
        description: String,
        categories: [Category]
    ) async throws -> UUID {
        guard !categories.isEmpty else {
            throw CategoryAISelectorError.noCategories
        }

        guard Self.isAvailable else {
            throw CategoryAISelectorError.modelUnavailable
        }

        let categoryCodes =
            categories.indices.map(
                String.init
            )

        let categoryCodeSchema =
            DynamicGenerationSchema(
                type: String.self,
                guides: [
                    .anyOf(
                        categoryCodes
                    )
                ]
            )

        let selectionSchema =
            DynamicGenerationSchema(
                name: "CategorySelection",
                properties: [
                    DynamicGenerationSchema
                        .Property(
                            name: "categoryCode",
                            description:
                                "Code of the best matching category.",
                            schema:
                                categoryCodeSchema
                        )
                ]
            )

        let schema =
            try GenerationSchema(
                root: selectionSchema,
                dependencies: []
            )

        let promptPrefix =
            makePromptPrefix(
                categories: categories
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

        self.prewarmedSession = nil
        prewarmedContextKey = nil

        let prompt =
            promptPrefix
            + "\n"
            + description

        #if DEBUG
            let clock = ContinuousClock()
            let start = clock.now
        #endif

        let response =
            try await session.respond(
                to: Prompt(prompt),
                schema: schema
            )

        #if DEBUG
            print(
                "CATEGORY AI INFERENCE:",
                start.duration(
                    to: clock.now
                )
            )
        #endif

        let categoryCode: String =
            try response.content.value(
                String.self,
                forProperty:
                    "categoryCode"
            )

        guard
            let categoryIndex =
                Int(categoryCode),
            categories.indices
                .contains(categoryIndex)
        else {
            throw
                CategoryAISelectorError
                .invalidSelection
        }

        return categories[
            categoryIndex
        ].id
    }

    private func makePromptPrefix(
        categories: [Category]
    ) -> String {
        let categoryContext =
            categories
            .enumerated()
            .map {
                index,
                category in

                let note =
                    category.note
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

                if note.isEmpty {
                    return
                        "\(index): \(category.name)"
                }

                return """
                    \(index): \(category.name)
                    \(note)
                    """
            }
            .joined(
                separator: "\n\n"
            )

        return """
            Choose the category that best matches this personal finance transaction.

            Available categories:

            \(categoryContext)

            Description:
            """
    }
}
