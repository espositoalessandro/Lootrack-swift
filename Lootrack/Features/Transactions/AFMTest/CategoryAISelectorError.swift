import Foundation
import FoundationModels

enum CategoryAISelectorError: LocalizedError {
    case modelUnavailable
    case noCategories
    case invalidSelection

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence isn't available on this device right now."
        case .noCategories:
            return "There are no categories available for this transaction type."
        case .invalidSelection:
            return "The model returned an invalid category."
        }
    }
}

@MainActor
enum CategoryAISelector {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static func selectCategoryId(
        description: String,
        amountInCents: Int,
        type: TransactionType,
        categories: [Category]
    ) async throws -> UUID {
        guard !categories.isEmpty else {
            throw CategoryAISelectorError.noCategories
        }

        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            throw CategoryAISelectorError.modelUnavailable
        }

        let allowedCategoryIds = categories.map {
            $0.id.uuidString
        }

        // The model is only allowed to produce one of these UUIDs.
        let categoryIdSchema = DynamicGenerationSchema(
            type: String.self,
            guides: [
                .anyOf(allowedCategoryIds)
            ]
        )

        let selectionSchema = DynamicGenerationSchema(
            name: "CategorySelection",
            description: "The best category for a personal finance transaction.",
            properties: [
                DynamicGenerationSchema.Property(
                    name: "categoryId",
                    description: "The id of the most appropriate category.",
                    schema: categoryIdSchema
                )
            ]
        )

        let schema = try GenerationSchema(
            root: selectionSchema,
            dependencies: []
        )

        let categoryContext = categories
            .map { category in
                """
                ID: \(category.id.uuidString)
                Name: \(category.name)
                Meaning: \(category.aiDescription)
                """
            }
            .joined(separator: "\n\n")

        let session = LanguageModelSession(
            instructions: """
            The person's locale is it_IT.
            
            Categorize personal finance transactions.
            
            Choose exactly one category from the categories provided by the app.
            Base the decision primarily on the transaction description and the
            meaning of each category.
            """
        )

        let response = try await session.respond(
            to: """
            Categorize this transaction.

            Type: \(type.rawValue)
            Amount: \(amountInCents) cents
            Description: \(description)

            Available categories:

            \(categoryContext)
            """,
            schema: schema
        )

        let categoryIdString: String = try response.content.value(
            String.self,
            forProperty: "categoryId"
        )

        guard
            let categoryId = UUID(uuidString: categoryIdString),
            categories.contains(where: { $0.id == categoryId })
        else {
            throw CategoryAISelectorError.invalidSelection
        }

        return categoryId
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
            activities outside the home.
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
            and holidays.
            """

        case "clothes":
            return """
            Clothes of any kind
            """

        case "health":
            return """
            Medicines, doctors, healthcare, pharmacy, personal care and medical expenses.
            """

        case "subscriptions":
            return """
            Recurring digital or physical subscriptions and membership fees.
            """

        case "extra":
            return """
            Irregular or miscellaneous expenses that do not reasonably fit
            another category, or any hobby related expenses.
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
