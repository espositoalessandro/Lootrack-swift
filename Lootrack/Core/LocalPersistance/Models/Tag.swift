import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique)
    private(set) var name: String

    init(_ name: String) {
        let tokens = Self.normalizedTokens(from: name)

        precondition(
            tokens.count == 1,
            "A Tag must contain exactly one non-empty word"
        )

        self.name = tokens[0]
    }

    nonisolated static func normalizedTokens(
        from input: String
    ) -> [String] {
        var found = Set<String>()
        var result: [String] = []

        for rawToken in input.split(
            whereSeparator: \.isWhitespace
        ) {
            let normalized = String(rawToken)
                .lowercased()
                .capitalized

            guard
                !normalized.isEmpty,
                found.insert(normalized).inserted
            else {
                continue
            }

            result.append(normalized)
        }

        return result
    }

    nonisolated static func normalizedTags(
        _ tags: [String]
    ) -> [String] {
        var found = Set<String>()
        var result: [String] = []

        for rawTag in tags {
            for tag in normalizedTokens(from: rawTag) {
                guard found.insert(tag).inserted else {
                    continue
                }

                result.append(tag)
            }
        }

        return result
    }
}
