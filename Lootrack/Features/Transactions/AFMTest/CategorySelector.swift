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
                "There are no categories available for this transaction type."
        case .invalidSelection:
            return "The model returned an invalid category."
        }
    }
}

// MARK: - Temporary AI metadata

extension Category {
    var aiDescription: String {
        switch name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        {
        case "home":
            return """
                Rent, utilities, furniture, appliances, household products,
                maintenance and other home-related expenses.
                """

        case "going out":
            return """
                Restaurants, bars, cafés, cinema, entertainment and social
                activities. Also groceries for social events.
                """

        case "groceries":
            return """
                Supermarkets, food, drinks and everyday household groceries.
                """

        case "car":
            return """
                Fuel, parking, tolls, maintenance, repairs and other car expenses.
                """

        case "travel":
            return """
                Flights, hotels, transport and expenses primarily related to trips
                and holidays. Also, any expense that ends with a country/city name (like coffee Kenya or lunch Budapest)
                """

        case "clothes":
            return """
                Clothes of any kind
                """

        case "health":
            return """
                Medicines, doctors, healthcare, pharmacy, personal care (like barber, cosmetics) and medical expenses.
                """

        case "subscriptions":
            return """
                Recurring digital or physical subscriptions and membership fees.
                """

        case "extra":
            return """
                Hobbies and related expenses, like tools, materials, electronics, devices.
                """

        case "salary":
            return """
                Salary, wages and regular employment income.
                """

        case "gifts":
            return """
                Gifts purchased for other people or money received as a gift.
                """

        default:
            return """
                Transactions that naturally belong to the category named "\(name)".
                """
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
        type: TransactionType,
        categories: [Category]
    ) {
        guard Self.isAvailable else {
            return
        }
        guard !categories.isEmpty else {
            return
        }

        let contextKey = makeContextKey(
            type: type,
            categories: categories
        )

        guard prewarmedContextKey != contextKey else {
            return
        }

        let session = makeSession()
        prewarmedSession = session
        prewarmedContextKey = contextKey

        let promptPrefix = makePromptPrefix(
            type: type,
            categories: categories
        )

        #if DEBUG
            let clock = ContinuousClock()
            let start = clock.now
        #endif

        session.prewarm(
            promptPrefix: Prompt(promptPrefix)
        )

        #if DEBUG
            print(
                "CATEGORY AI SESSION PREWARMING:",
                start.duration(to: clock.now)
            )
        #endif

    }

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(
            instructions: """
                Categorize personal finance transactions for an Italian user.
                Choose exactly one of the categories provided by the app.
                """
        )
    }

    func selectCategoryId(
        description: String,
        type: TransactionType,
        categories: [Category]
    ) async throws -> UUID {
        guard !categories.isEmpty else {
            throw CategoryAISelectorError.noCategories
        }

        guard Self.isAvailable else {
            throw CategoryAISelectorError.modelUnavailable
        }

        let categoryCodes = categories.indices.map(String.init)

        let categoryCodeSchema = DynamicGenerationSchema(
            type: String.self,
            guides: [
                .anyOf(categoryCodes)
            ]
        )

        let selectionSchema = DynamicGenerationSchema(
            name: "CategorySelection",
            properties: [
                DynamicGenerationSchema.Property(
                    name: "categoryCode",
                    description: "Code of the best matching category.",
                    schema: categoryCodeSchema
                )
            ]
        )

        let schema = try GenerationSchema(
            root: selectionSchema,
            dependencies: []
        )

        let contextKey = makeContextKey(
            type: type,
            categories: categories
        )

        let session: LanguageModelSession

        if prewarmedContextKey == contextKey,
            let prewarmedSession
        {
            session = prewarmedSession
        } else {
            session = makeSession()
        }

        self.prewarmedSession = nil
        prewarmedContextKey = nil

        let prompt =
            makePromptPrefix(
                type: type,
                categories: categories
            )
                + """
                Description: \(description)
                """

        #if DEBUG
            let clock = ContinuousClock()
            let start = clock.now
        #endif

        let response = try await session.respond(
            to: Prompt(prompt),
            schema: schema
        )

        #if DEBUG
            print(
                "CATEGORY AI INFERENCE:",
                start.duration(to: clock.now)
            )
        #endif

        let categoryCode: String =
            try response.content.value(
                String.self,
                forProperty: "categoryCode"
            )

        guard
            let categoryIndex = Int(categoryCode),
            categories.indices.contains(categoryIndex)
        else {
            throw CategoryAISelectorError.invalidSelection
        }

        return categories[categoryIndex].id
    }

    private func makePromptPrefix(
        type: TransactionType,
        categories: [Category]
    ) -> String {
        let categoryContext =
            categories
            .enumerated()
            .map { index, category in
                """
                \(index): \(category.name)
                \(category.aiDescription)
                """
            }
            .joined(separator: "\n\n")

        return """
            Categorize this \(type.rawValue) transaction.

            Available categories:

            \(categoryContext)

            Transaction:
            """
    }

    private func makeContextKey(
        type: TransactionType,
        categories: [Category]
    ) -> String {
        let categoriesKey =
            categories
            .map { category in
                "\(category.id.uuidString):\(category.name)"
            }
            .joined(separator: "|")

        return "\(type.rawValue)|\(categoriesKey)"
    }
}
