import Foundation


@MainActor
final class GoogleSheetsClient {
    private static let baseURL =
        "https://sheets.googleapis.com/v4/spreadsheets"

    private static let transactionHeaders = [
        "id",
        "type",
        "amountInCents",
        "description",
        "occurredOn",
        "categoryId",
        "createdAt",
        "updatedAt",
        "deletedAt",
        "revision",
        "lastMutationId"
    ]

    private static let categoryHeaders = [
        "id",
        "type",
        "name",
        "createdAt",
        "updatedAt",
        "deletedAt",
        "revision",
        "lastMutationId"
    ]

    func readSnapshot(
        accessToken: String,
        spreadsheetId: String
    ) async throws -> RemoteSyncSnapshot {
        guard var components = URLComponents(
            string:
                "\(Self.baseURL)/\(spreadsheetId)/values:batchGet"
        ) else {
            throw GoogleSheetsClientError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(
                name: "ranges",
                value: "Transactions!A1:K"
            ),
            URLQueryItem(
                name: "ranges",
                value: "Categories!A1:H"
            ),
            URLQueryItem(
                name: "ranges",
                value: "_Meta!A1:B3"
            ),
            URLQueryItem(
                name: "majorDimension",
                value: "ROWS"
            ),
            URLQueryItem(
                name: "valueRenderOption",
                value: "UNFORMATTED_VALUE"
            )
        ]

        guard let url = components.url else {
            throw GoogleSheetsClientError.invalidURL
        }

        let response: BatchGetResponse = try await request(
            url: url,
            accessToken: accessToken
        )

        guard response.valueRanges.count == 3 else {
            throw GoogleSheetsClientError.invalidData(
                "Google Sheets returned an unexpected number of ranges"
            )
        }

        let transactionValues =
            response.valueRanges[0].values ?? []

        let categoryValues =
            response.valueRanges[1].values ?? []

        let metaValues =
            response.valueRanges[2].values ?? []

        try validateMeta(metaValues)

        try validateHeaders(
            actual: transactionValues.first,
            expected: Self.transactionHeaders,
            sheetName: "Transactions"
        )

        try validateHeaders(
            actual: categoryValues.first,
            expected: Self.categoryHeaders,
            sheetName: "Categories"
        )

        let transactionRecords = try parseTransactions(
            Array(transactionValues.dropFirst())
        )

        let categoryRecords = try parseCategories(
            Array(categoryValues.dropFirst())
        )

        let records = transactionRecords + categoryRecords

        try validateUniqueRecords(records)

        return RemoteSyncSnapshot(
            records: records
        )
    }

    func push(
        _ request: SyncPushRequest,
        accessToken: String,
        spreadsheetId: String
    ) async throws -> SyncPushResult {
        fatalError("Not implemented yet")
    }

    // MARK: - Parsing

    private func parseTransactions(
        _ rows: [[Cell]]
    ) throws -> [RemoteSyncRecord] {
        try rows.enumerated().compactMap { index, row in
            if isBlank(row) {
                return nil
            }

            let context = "Transactions row \(index + 2)"

            let id = try readUUID(
                row,
                index: 0,
                context: context,
                field: "id"
            )

            let typeString = try readRequiredString(
                row,
                index: 1,
                context: context,
                field: "type"
            )

            guard let type = TransactionType(
                rawValue: typeString
            ) else {
                throw GoogleSheetsClientError.invalidData(
                    "\(context): invalid transaction type"
                )
            }

            let amountInCents = try readInteger(
                row,
                index: 2,
                context: context,
                field: "amountInCents",
                minimum: 0
            )

            let note = try readStringOrEmpty(
                row,
                index: 3,
                context: context,
                field: "description"
            )

            let occurredOn = try readDate(
                row,
                index: 4,
                context: context,
                field: "occurredOn"
            )

            let categoryId = try readOptionalUUID(
                row,
                index: 5,
                context: context,
                field: "categoryId"
            )

            let createdAt = try readDate(
                row,
                index: 6,
                context: context,
                field: "createdAt"
            )

            let updatedAt = try readDate(
                row,
                index: 7,
                context: context,
                field: "updatedAt"
            )

            let deletedAt = try readOptionalDate(
                row,
                index: 8,
                context: context,
                field: "deletedAt"
            )

            let revision = try readInteger(
                row,
                index: 9,
                context: context,
                field: "revision",
                minimum: 1
            )

            let mutationId = try readUUID(
                row,
                index: 10,
                context: context,
                field: "lastMutationId"
            )

            let snapshot = TransactionDTO(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                type: type,
                amountInCents: amountInCents,
                note: note,
                occurredOn: occurredOn,
                categoryId: categoryId
            )

            return RemoteSyncRecord(
                operation: deletedAt == nil
                    ? .upsert
                    : .delete,
                revision: revision,
                mutationId: mutationId,
                payload: .transaction(snapshot)
            )
        }
    }

    private func parseCategories(
        _ rows: [[Cell]]
    ) throws -> [RemoteSyncRecord] {
        try rows.enumerated().compactMap { index, row in
            if isBlank(row) {
                return nil
            }

            let context = "Categories row \(index + 2)"

            let id = try readUUID(
                row,
                index: 0,
                context: context,
                field: "id"
            )

            let typeString = try readRequiredString(
                row,
                index: 1,
                context: context,
                field: "type"
            )

            guard let type = TransactionType(
                rawValue: typeString
            ) else {
                throw GoogleSheetsClientError.invalidData(
                    "\(context): invalid category type"
                )
            }

            let name = try readRequiredString(
                row,
                index: 2,
                context: context,
                field: "name"
            )

            let createdAt = try readDate(
                row,
                index: 3,
                context: context,
                field: "createdAt"
            )

            let updatedAt = try readDate(
                row,
                index: 4,
                context: context,
                field: "updatedAt"
            )

            let deletedAt = try readOptionalDate(
                row,
                index: 5,
                context: context,
                field: "deletedAt"
            )

            let revision = try readInteger(
                row,
                index: 6,
                context: context,
                field: "revision",
                minimum: 1
            )

            let mutationId = try readUUID(
                row,
                index: 7,
                context: context,
                field: "lastMutationId"
            )

            let snapshot = CategoryDTO(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                type: type,
                name: name
            )

            return RemoteSyncRecord(
                operation: deletedAt == nil
                    ? .upsert
                    : .delete,
                revision: revision,
                mutationId: mutationId,
                payload: .category(snapshot)
            )
        }
    }

    // MARK: - Spreadsheet validation

    private func validateMeta(
        _ rows: [[Cell]]
    ) throws {
        try validateHeaders(
            actual: rows.first,
            expected: ["key", "value"],
            sheetName: "_Meta"
        )

        var metadata: [String: String] = [:]

        for row in rows.dropFirst() {
            guard row.count >= 2 else {
                continue
            }

            guard
                case .string(let key) = row[0],
                case .string(let value) = row[1]
            else {
                continue
            }

            metadata[key] = value
        }

        guard metadata["appId"] == "lootrack" else {
            throw GoogleSheetsClientError.invalidData(
                "Spreadsheet does not belong to Lootrack"
            )
        }

        guard metadata["schemaVersion"] == "1" else {
            throw GoogleSheetsClientError.invalidData(
                "Unsupported Lootrack spreadsheet schema: "
                    + (metadata["schemaVersion"] ?? "unknown")
            )
        }
    }

    private func validateHeaders(
        actual: [Cell]?,
        expected: [String],
        sheetName: String
    ) throws {
        guard let actual else {
            throw GoogleSheetsClientError.invalidData(
                "\(sheetName) has no header"
            )
        }

        let actualHeaders = try actual.map { cell in
            guard case .string(let value) = cell else {
                throw GoogleSheetsClientError.invalidData(
                    "\(sheetName) has an invalid header"
                )
            }

            return value
        }

        guard actualHeaders == expected else {
            throw GoogleSheetsClientError.invalidData(
                "\(sheetName) has an invalid or unsupported header"
            )
        }
    }

    private func validateUniqueRecords(
        _ records: [RemoteSyncRecord]
    ) throws {
        var keys = Set<SyncEntityKey>()

        for record in records {
            guard keys.insert(record.id).inserted else {
                throw GoogleSheetsClientError.invalidData(
                    "Duplicate remote entity: \(record.id)"
                )
            }
        }
    }

    // MARK: - Cell readers

    private func readRequiredString(
        _ row: [Cell],
        index: Int,
        context: String,
        field: String
    ) throws -> String {
        guard index < row.count else {
            throw GoogleSheetsClientError.invalidData(
                "\(context): missing \(field)"
            )
        }

        guard
            case .string(let value) = row[index],
            !value.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        else {
            throw GoogleSheetsClientError.invalidData(
                "\(context): \(field) must be a non-empty string"
            )
        }

        return value
    }

    private func readStringOrEmpty(
        _ row: [Cell],
        index: Int,
        context: String,
        field: String
    ) throws -> String {
        guard index < row.count else {
            return ""
        }

        switch row[index] {
        case .string(let value):
            return value

        default:
            throw GoogleSheetsClientError.invalidData(
                "\(context): \(field) must be a string"
            )
        }
    }

    private func readOptionalString(
        _ row: [Cell],
        index: Int,
        context: String,
        field: String
    ) throws -> String? {
        guard index < row.count else {
            return nil
        }

        switch row[index] {
        case .string(let value):
            return value.isEmpty ? nil : value

        default:
            throw GoogleSheetsClientError.invalidData(
                "\(context): \(field) must be a string or empty"
            )
        }
    }

    private func readInteger(
        _ row: [Cell],
        index: Int,
        context: String,
        field: String,
        minimum: Int
    ) throws -> Int {
        guard
            index < row.count,
            case .number(let value) = row[index],
            let integer = Int(exactly: value),
            integer >= minimum
        else {
            throw GoogleSheetsClientError.invalidData(
                "\(context): \(field) must be an integer >= \(minimum)"
            )
        }

        return integer
    }

    private func readUUID(
        _ row: [Cell],
        index: Int,
        context: String,
        field: String
    ) throws -> UUID {
        let value = try readRequiredString(
            row,
            index: index,
            context: context,
            field: field
        )

        guard let uuid = UUID(uuidString: value) else {
            throw GoogleSheetsClientError.invalidData(
                "\(context): \(field) is not a valid UUID"
            )
        }

        return uuid
    }

    private func readOptionalUUID(
        _ row: [Cell],
        index: Int,
        context: String,
        field: String
    ) throws -> UUID? {
        guard let value = try readOptionalString(
            row,
            index: index,
            context: context,
            field: field
        ) else {
            return nil
        }

        guard let uuid = UUID(uuidString: value) else {
            throw GoogleSheetsClientError.invalidData(
                "\(context): \(field) is not a valid UUID"
            )
        }

        return uuid
    }

    private func readDate(
        _ row: [Cell],
        index: Int,
        context: String,
        field: String
    ) throws -> Date {
        let value = try readRequiredString(
            row,
            index: index,
            context: context,
            field: field
        )

        return try parseDate(
            value,
            context: context,
            field: field
        )
    }

    private func readOptionalDate(
        _ row: [Cell],
        index: Int,
        context: String,
        field: String
    ) throws -> Date? {
        guard let value = try readOptionalString(
            row,
            index: index,
            context: context,
            field: field
        ) else {
            return nil
        }

        return try parseDate(
            value,
            context: context,
            field: field
        )
    }

    private func parseDate(
        _ value: String,
        context: String,
        field: String
    ) throws -> Date {
        if let date = Self.iso8601Fractional.date(
            from: value
        ) {
            return date
        }

        if let date = Self.iso8601.date(
            from: value
        ) {
            return date
        }

        if let date = Self.dateOnly.date(
            from: value
        ) {
            return date
        }

        throw GoogleSheetsClientError.invalidData(
            "\(context): \(field) is not a valid date"
        )
    }

    private func isBlank(
        _ row: [Cell]
    ) -> Bool {
        row.isEmpty || row.allSatisfy { cell in
            if case .string(let value) = cell {
                return value.isEmpty
            }

            return false
        }
    }

    // MARK: - HTTP

    private func request<T: Decodable>(
        url: URL,
        accessToken: String
    ) async throws -> T {
        var request = URLRequest(url: url)

        request.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let response = response as? HTTPURLResponse else {
            throw GoogleSheetsClientError.invalidResponse
        }

        guard (200..<300).contains(
            response.statusCode
        ) else {
            let errorResponse = try? JSONDecoder().decode(
                APIErrorResponse.self,
                from: data
            )

            throw GoogleSheetsClientError.apiError(
                status: response.statusCode,
                message: errorResponse?.error?.message
            )
        }

        return try JSONDecoder().decode(
            T.self,
            from: data
        )
    }

    // MARK: - API models

    private struct BatchGetResponse: Decodable {
        let valueRanges: [ValueRange]

        init(
            valueRanges: [ValueRange] = []
        ) {
            self.valueRanges = valueRanges
        }

        private enum CodingKeys: String, CodingKey {
            case valueRanges
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(
                keyedBy: CodingKeys.self
            )

            valueRanges = try container.decodeIfPresent(
                [ValueRange].self,
                forKey: .valueRanges
            ) ?? []
        }
    }

    private struct ValueRange: Decodable {
        let values: [[Cell]]?
    }

    private struct APIErrorResponse: Decodable {
        let error: APIErrorBody?
    }

    private struct APIErrorBody: Decodable {
        let message: String?
    }

    private enum Cell: Codable, Equatable {
        case string(String)
        case number(Double)
        case bool(Bool)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let value = try? container.decode(String.self) {
                self = .string(value)
                return
            }

            if let value = try? container.decode(Bool.self) {
                self = .bool(value)
                return
            }

            if let value = try? container.decode(Double.self) {
                self = .number(value)
                return
            }

            throw DecodingError.typeMismatch(
                Cell.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription:
                        "Unsupported Google Sheets cell"
                )
            )
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch self {
            case .string(let value):
                try container.encode(value)

            case .number(let value):
                try container.encode(value)

            case .bool(let value):
                try container.encode(value)
            }
        }
    }

    // MARK: - Date parsers

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [
            .withInternetDateTime
        ]

        return formatter
    }()

    private static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()

        formatter.locale = Locale(
            identifier: "en_US_POSIX"
        )

        formatter.calendar = Calendar(
            identifier: .gregorian
        )

        formatter.timeZone = TimeZone(
            secondsFromGMT: 0
        )

        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()
}

nonisolated enum GoogleSheetsClientError: Error {
    case invalidURL
    case invalidResponse
    case apiError(
        status: Int,
        message: String?
    )
    case invalidData(String)
}
