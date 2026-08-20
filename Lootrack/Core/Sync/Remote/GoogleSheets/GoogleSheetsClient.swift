import Foundation

@MainActor
final class GoogleSheetsClient {
    private static let baseURL =
        "https://sheets.googleapis.com/v4/spreadsheets"

    private static let transactionHeaders = ["id",
                                             "type",
                                             "amountInCents",
                                             "description",
                                             "occurredOn",
                                             "categoryId",
                                             "subcategoryId",
                                             "tags",
                                             "createdAt",
                                             "updatedAt",
                                             "deletedAt",
                                             "revision",
                                             "lastMutationId"]

    private static let categoryHeaders = ["id",
                                          "type",
                                          "name",
                                          "note",
                                          "createdAt",
                                          "updatedAt",
                                          "deletedAt",
                                          "revision",
                                          "lastMutationId"]

    private static let subcategoryHeaders = ["id",
                                             "categoryId",
                                             "name",
                                             "createdAt",
                                             "updatedAt",
                                             "deletedAt",
                                             "revision",
                                             "lastMutationId"]

    // MARK: - Pull

    func readSnapshot(accessToken: String,
                      spreadsheetId: String) async throws -> RemoteSyncSnapshot
    {
        guard var components = URLComponents(string:
            "\(Self.baseURL)/\(spreadsheetId)/values:batchGet")
        else {
            throw GoogleSheetsClientError.invalidURL
        }

        components.queryItems = [URLQueryItem(name: "ranges",
                                              value: "Transactions!A1:M"),
                                 URLQueryItem(name: "ranges",
                                              value: "Categories!A1:I"),
                                 URLQueryItem(name: "ranges",
                                              value: "Subcategories!A1:H"),
                                 URLQueryItem(name: "ranges",
                                              value: "_Meta!A1:B3"),
                                 URLQueryItem(name: "majorDimension",
                                              value: "ROWS"),
                                 URLQueryItem(name: "valueRenderOption",
                                              value: "UNFORMATTED_VALUE")]

        guard let url = components.url else {
            throw GoogleSheetsClientError.invalidURL
        }

        let response: BatchGetResponse =
            try await request(url: url,
                              accessToken:
                              accessToken)

        guard response.valueRanges.count
            == 4
        else {
            throw
                GoogleSheetsClientError
                .invalidData("Google Sheets returned an unexpected number of ranges")
        }

        let transactionValues =
            response
                .valueRanges[0]
                .values
                ?? []

        let categoryValues =
            response
                .valueRanges[1]
                .values
                ?? []

        let subcategoryValues =
            response
                .valueRanges[2]
                .values
                ?? []

        let metaValues =
            response
                .valueRanges[3]
                .values
                ?? []

        try validateMeta(metaValues)

        try validateHeaders(actual:
            transactionValues
                .first,
            expected:
            Self.transactionHeaders,
            sheetName:
            "Transactions")

        try validateHeaders(actual:
            categoryValues
                .first,
            expected:
            Self.categoryHeaders,
            sheetName:
            "Categories")

        try validateHeaders(actual:
            subcategoryValues
                .first,
            expected:
            Self.subcategoryHeaders,
            sheetName:
            "Subcategories")

        let transactionRecords =
            try parseTransactions(Array(transactionValues
                    .dropFirst()))

        let categoryRecords =
            try parseCategories(Array(categoryValues
                    .dropFirst()))

        let subcategoryRecords =
            try parseSubcategories(Array(subcategoryValues
                    .dropFirst()))

        let records =
            transactionRecords
                + categoryRecords
                + subcategoryRecords

        try validateUniqueRecords(records)

        return RemoteSyncSnapshot(records: records)
    }

    // MARK: - Push

    func push(_ pushRequest:
        SyncPushRequest,
        accessToken: String,
        spreadsheetId: String) async throws -> SyncPushResult
    {
        guard !pushRequest
            .mutations
            .isEmpty
        else {
            return SyncPushResult(records: [])
        }

        /*
         * Re-read immediately before writing.
         * The snapshot used by SyncReconciler
         * may already be stale.
         */
        let snapshot =
            try await readSnapshot(accessToken:
                accessToken,
                spreadsheetId:
                spreadsheetId)

        var recordsByKey =
            Dictionary(uniqueKeysWithValues:
                snapshot.records.map {
                    record in
                    (record.id,
                     record)
                })

        var affectedRecordsByKey:
            [SyncEntityKey:
                RemoteSyncRecord] = [:]

        /*
         * Mutations are processed in order.
         * A later mutation may depend on the
         * remote version produced by the
         * previous one.
         */
        for mutation
            in pushRequest.mutations
        {
            let key =
                mutation.payload.key

            let currentRecord =
                recordsByKey[key]

            /*
             * Idempotency: a previous request
             * may have reached Google Sheets
             * even if Lootrack never received
             * its response.
             */
            if currentRecord?
                .mutationId
                == mutation.id
            {
                if let currentRecord {
                    affectedRecordsByKey[key] = currentRecord
                }

                continue
            }

            guard matchesExpectedRemote(currentRecord,
                                        mutation:
                                        mutation)
            else {
                throw
                    GoogleSheetsClientError
                    .writeConflict(key)
            }

            let nextRecord =
                try recordFromMutation(mutation)

            recordsByKey[key] =
                nextRecord

            affectedRecordsByKey[key] = nextRecord
        }

        let transactionRecords =
            recordsByKey
                .values
                .filter {
                    $0.entityType
                        == .transaction
                }
                .sorted {
                    $0.entityId.uuidString
                        < $1.entityId
                        .uuidString
                }

        let categoryRecords =
            recordsByKey
                .values
                .filter {
                    $0.entityType
                        == .category
                }
                .sorted {
                    $0.entityId.uuidString
                        < $1.entityId
                        .uuidString
                }

        let subcategoryRecords =
            recordsByKey
                .values
                .filter {
                    $0.entityType
                        == .subcategory
                }
                .sorted {
                    $0.entityId.uuidString
                        < $1.entityId
                        .uuidString
                }

        let transactionValues =
            try buildTransactionSheetValues(Array(transactionRecords))

        let categoryValues =
            try buildCategorySheetValues(Array(categoryRecords))

        let subcategoryValues =
            try buildSubcategorySheetValues(Array(subcategoryRecords))

        guard let url = URL(string:
            "\(Self.baseURL)/\(spreadsheetId)/values:batchUpdate")
        else {
            throw
                GoogleSheetsClientError
                .invalidURL
        }

        let body =
            BatchUpdateRequest(valueInputOption:
                "RAW",
                includeValuesInResponse:
                false,
                data: [WriteValueRange(range:
                    "Transactions!A1:M\(transactionValues.count)",
                    majorDimension:
                    "ROWS",
                    values:
                    transactionValues),
                WriteValueRange(range:
                    "Categories!A1:I\(categoryValues.count)",
                    majorDimension:
                    "ROWS",
                    values:
                    categoryValues),
                WriteValueRange(range:
                    "Subcategories!A1:H\(subcategoryValues.count)",
                    majorDimension:
                    "ROWS",
                    values:
                    subcategoryValues)])

        let encodedBody =
            try JSONEncoder()
                .encode(body)

        let _: BatchUpdateResponse =
            try await request(url: url,
                              accessToken:
                              accessToken,
                              method: "POST",
                              body:
                              encodedBody)

        return SyncPushResult(records:
            Array(affectedRecordsByKey
                .values))
    }

    // MARK: - Mutation handling

    private func matchesExpectedRemote(_ current:
        RemoteSyncRecord?,
        mutation: MutationDTO) -> Bool
    {
        guard let current else {
            return mutation
                .expectedRevision
                == nil
                && mutation
                .expectedMutationId
                == nil
        }

        return current.revision
            == mutation
            .expectedRevision
            && current.mutationId
            == mutation
            .expectedMutationId
    }

    private func recordFromMutation(_ mutation: MutationDTO) throws -> RemoteSyncRecord {
        let deletedAt: Date? =
            switch mutation.payload {
            case let .transaction(transaction):
                transaction.deletedAt

            case let .category(category):
                category.deletedAt

            case let .subcategory(subcategory):
                subcategory.deletedAt
            }

        switch mutation.operation {
        case .upsert:
            guard deletedAt == nil
            else {
                throw
                    GoogleSheetsClientError
                    .invalidData("""
                    \(mutation.entityType) mutation \(mutation.id): \
                    upsert payload is deleted
                    """)
            }

        case .delete:
            guard deletedAt != nil
            else {
                throw
                    GoogleSheetsClientError
                    .invalidData("""
                    \(mutation.entityType) mutation \(mutation.id): \
                    delete payload is not deleted
                    """)
            }
        }

        return RemoteSyncRecord(operation:
            mutation.operation,
            revision: (mutation
                .expectedRevision
                ?? 0) + 1,
            mutationId:
            mutation.id,
            payload:
            mutation.payload)
    }

    // MARK: - Sheet building

    private func buildTransactionSheetValues(_ records:
        [RemoteSyncRecord]) throws -> [[Cell]]
    {
        var values: [[Cell]] = [Self
            .transactionHeaders
            .map {
                .string($0)
            }]

        for record in records {
            guard case let .transaction(transaction) = record.payload
            else {
                throw
                    GoogleSheetsClientError
                    .invalidData("Expected transaction payload")
            }

            values.append([.string(transaction.id
                               .uuidString
                               .lowercased()),
                .string(transaction.type
                    .rawValue),
                .number(Double(transaction
                        .amountInCents)),
                .string(transaction.note),
                .string(formatDateOnly(transaction
                        .occurredOn)),
                .string(transaction
                    .categoryId?
                    .uuidString
                    .lowercased()
                    ?? ""),
                .string(transaction
                    .subcategoryId?
                    .uuidString
                    .lowercased()
                    ?? ""),
                .string(transaction.tags
                    .joined(separator: " ")),
                .string(Self
                    .iso8601Fractional
                    .string(from:
                        transaction
                            .createdAt)),
                .string(Self
                    .iso8601Fractional
                    .string(from:
                        transaction
                            .updatedAt)),
                .string(transaction
                    .deletedAt
                    .map {
                        Self
                            .iso8601Fractional
                            .string(from: $0)
                    }
                    ?? ""),
                .number(Double(record.revision)),
                .string(record
                    .mutationId
                    .uuidString
                    .lowercased())])
        }

        return values
    }

    private func buildCategorySheetValues(_ records:
        [RemoteSyncRecord]) throws -> [[Cell]]
    {
        var values: [[Cell]] = [Self
            .categoryHeaders
            .map {
                .string($0)
            }]

        for record in records {
            guard case let .category(category) = record.payload
            else {
                throw
                    GoogleSheetsClientError
                    .invalidData("Expected category payload")
            }

            values.append([.string(category.id
                               .uuidString
                               .lowercased()),
                .string(category.type
                    .rawValue),
                .string(category.name),
                .string(category.note),
                .string(Self
                    .iso8601Fractional
                    .string(from:
                        category
                            .createdAt)),
                .string(Self
                    .iso8601Fractional
                    .string(from:
                        category
                            .updatedAt)),
                .string(category
                    .deletedAt
                    .map {
                        Self
                            .iso8601Fractional
                            .string(from: $0)
                    }
                    ?? ""),
                .number(Double(record.revision)),
                .string(record
                    .mutationId
                    .uuidString
                    .lowercased())])
        }

        return values
    }

    private func buildSubcategorySheetValues(_ records:
        [RemoteSyncRecord]) throws -> [[Cell]]
    {
        var values: [[Cell]] = [Self
            .subcategoryHeaders
            .map {
                .string($0)
            }]

        for record in records {
            guard case let .subcategory(subcategory) = record.payload
            else {
                throw
                    GoogleSheetsClientError
                    .invalidData("Expected subcategory payload")
            }

            values.append([.string(subcategory.id
                               .uuidString
                               .lowercased()),
                .string(subcategory
                    .categoryId
                    .uuidString
                    .lowercased()),
                .string(subcategory.name),
                .string(Self
                    .iso8601Fractional
                    .string(from:
                        subcategory
                            .createdAt)),
                .string(Self
                    .iso8601Fractional
                    .string(from:
                        subcategory
                            .updatedAt)),
                .string(subcategory
                    .deletedAt
                    .map {
                        Self
                            .iso8601Fractional
                            .string(from: $0)
                    }
                    ?? ""),
                .number(Double(record.revision)),
                .string(record
                    .mutationId
                    .uuidString
                    .lowercased())])
        }

        return values
    }

    // MARK: - Parsing

    private func parseTransactions(_ rows: [[Cell]]) throws -> [RemoteSyncRecord] {
        try rows
            .enumerated()
            .compactMap {
                index,
                row in
                if isBlank(row) {
                    return nil
                }

                let context =
                    "Transactions row \(index + 2)"

                let id =
                    try readUUID(row,
                                 index: 0,
                                 context:
                                 context,
                                 field: "id")

                let typeString =
                    try readRequiredString(row,
                                           index: 1,
                                           context:
                                           context,
                                           field: "type")

                guard let type =
                    TransactionType(rawValue:
                        typeString)
                else {
                    throw
                        GoogleSheetsClientError
                        .invalidData("\(context): invalid transaction type")
                }

                let amountInCents =
                    try readInteger(row,
                                    index: 2,
                                    context:
                                    context,
                                    field:
                                    "amountInCents",
                                    minimum: 0)

                let note =
                    try readStringOrEmpty(row,
                                          index: 3,
                                          context:
                                          context,
                                          field:
                                          "description")

                let occurredOn =
                    try readDate(row,
                                 index: 4,
                                 context:
                                 context,
                                 field:
                                 "occurredOn")

                let categoryId =
                    try readOptionalUUID(row,
                                         index: 5,
                                         context:
                                         context,
                                         field:
                                         "categoryId")

                let subcategoryId = try readOptionalUUID(row,
                                                         index: 6,
                                                         context:
                                                         context,
                                                         field:
                                                         "subcategoryId")

                let tags = try Tag.normalizedTokens(from:
                    readStringOrEmpty(row,
                                      index: 7,
                                      context:
                                      context,
                                      field: "tags"))

                let createdAt =
                    try readDate(row,
                                 index: 8,
                                 context:
                                 context,
                                 field:
                                 "createdAt")

                let updatedAt =
                    try readDate(row,
                                 index: 9,
                                 context:
                                 context,
                                 field:
                                 "updatedAt")

                let deletedAt =
                    try readOptionalDate(row,
                                         index: 10,
                                         context:
                                         context,
                                         field:
                                         "deletedAt")

                let revision =
                    try readInteger(row,
                                    index: 11,
                                    context:
                                    context,
                                    field:
                                    "revision",
                                    minimum: 1)

                let mutationId =
                    try readUUID(row,
                                 index: 12,
                                 context:
                                 context,
                                 field:
                                 "lastMutationId")

                let snapshot =
                    TransactionDTO(id: id,
                                   createdAt:
                                   createdAt,
                                   updatedAt:
                                   updatedAt,
                                   deletedAt:
                                   deletedAt,
                                   type: type,
                                   amountInCents:
                                   amountInCents,
                                   note: note,
                                   occurredOn:
                                   occurredOn,
                                   categoryId:
                                   categoryId,
                                   subcategoryId:
                                   subcategoryId,
                                   tags: tags)

                return RemoteSyncRecord(operation:
                    deletedAt == nil
                        ? .upsert
                        : .delete,
                    revision:
                    revision,
                    mutationId:
                    mutationId,
                    payload:
                    .transaction(snapshot))
            }
    }

    private func parseCategories(_ rows: [[Cell]]) throws -> [RemoteSyncRecord] {
        try rows
            .enumerated()
            .compactMap {
                index,
                row in
                if isBlank(row) {
                    return nil
                }

                let context =
                    "Categories row \(index + 2)"

                let id =
                    try readUUID(row,
                                 index: 0,
                                 context:
                                 context,
                                 field: "id")

                let typeString =
                    try readRequiredString(row,
                                           index: 1,
                                           context:
                                           context,
                                           field: "type")

                guard let type =
                    TransactionType(rawValue:
                        typeString)
                else {
                    throw
                        GoogleSheetsClientError
                        .invalidData("\(context): invalid category type")
                }

                let name =
                    try readRequiredString(row,
                                           index: 2,
                                           context:
                                           context,
                                           field: "name")

                let note =
                    try readStringOrEmpty(row,
                                          index: 3,
                                          context:
                                          context,
                                          field: "note")

                let createdAt =
                    try readDate(row,
                                 index: 4,
                                 context:
                                 context,
                                 field:
                                 "createdAt")

                let updatedAt =
                    try readDate(row,
                                 index: 5,
                                 context:
                                 context,
                                 field:
                                 "updatedAt")

                let deletedAt =
                    try readOptionalDate(row,
                                         index: 6,
                                         context:
                                         context,
                                         field:
                                         "deletedAt")

                let revision =
                    try readInteger(row,
                                    index: 7,
                                    context:
                                    context,
                                    field:
                                    "revision",
                                    minimum: 1)

                let mutationId =
                    try readUUID(row,
                                 index: 8,
                                 context:
                                 context,
                                 field:
                                 "lastMutationId")

                let snapshot =
                    CategoryDTO(id: id,
                                createdAt:
                                createdAt,
                                updatedAt:
                                updatedAt,
                                deletedAt:
                                deletedAt,
                                type: type,
                                name: name,
                                note: note)

                return RemoteSyncRecord(operation:
                    deletedAt == nil
                        ? .upsert
                        : .delete,
                    revision:
                    revision,
                    mutationId:
                    mutationId,
                    payload:
                    .category(snapshot))
            }
    }

    private func parseSubcategories(_ rows: [[Cell]]) throws -> [RemoteSyncRecord] {
        try rows
            .enumerated()
            .compactMap {
                index,
                row in
                if isBlank(row) {
                    return nil
                }

                let context =
                    "Subcategories row \(index + 2)"

                let id =
                    try readUUID(row,
                                 index: 0,
                                 context:
                                 context,
                                 field: "id")

                let categoryId =
                    try readUUID(row,
                                 index: 1,
                                 context:
                                 context,
                                 field:
                                 "categoryId")

                let name =
                    try readRequiredString(row,
                                           index: 2,
                                           context:
                                           context,
                                           field: "name")

                let createdAt =
                    try readDate(row,
                                 index: 3,
                                 context:
                                 context,
                                 field:
                                 "createdAt")

                let updatedAt =
                    try readDate(row,
                                 index: 4,
                                 context:
                                 context,
                                 field:
                                 "updatedAt")

                let deletedAt =
                    try readOptionalDate(row,
                                         index: 5,
                                         context:
                                         context,
                                         field:
                                         "deletedAt")

                let revision =
                    try readInteger(row,
                                    index: 6,
                                    context:
                                    context,
                                    field:
                                    "revision",
                                    minimum: 1)

                let mutationId =
                    try readUUID(row,
                                 index: 7,
                                 context:
                                 context,
                                 field:
                                 "lastMutationId")

                let snapshot =
                    SubcategoryDTO(id: id,
                                   createdAt:
                                   createdAt,
                                   updatedAt:
                                   updatedAt,
                                   deletedAt:
                                   deletedAt,
                                   categoryId:
                                   categoryId,
                                   name: name)

                return RemoteSyncRecord(operation:
                    deletedAt == nil
                        ? .upsert
                        : .delete,
                    revision:
                    revision,
                    mutationId:
                    mutationId,
                    payload:
                    .subcategory(snapshot))
            }
    }

    // MARK: - Spreadsheet validation

    private func validateMeta(_ rows: [[Cell]]) throws {
        try validateHeaders(actual:
            rows.first,
            expected: ["key",
                       "value"],
            sheetName:
            "_Meta")

        var metadata: [String: String] = [:]

        for row
            in rows.dropFirst()
        {
            guard row.count >= 2
            else {
                continue
            }

            guard case let .string(key) = row[0],
                  case let .string(value) = row[1]
            else {
                continue
            }

            metadata[key] = value
        }

        guard metadata["appId"]
            == "lootrack"
        else {
            throw
                GoogleSheetsClientError
                .invalidData("Spreadsheet does not belong to Lootrack")
        }

        guard metadata["schemaVersion"] == "4"
        else {
            throw
                GoogleSheetsClientError
                .invalidData("""
                Unsupported Lootrack spreadsheet schema: \
                \(metadata["schemaVersion"] ?? "unknown")
                """)
        }
    }

    private func validateHeaders(actual: [Cell]?,
                                 expected: [String],
                                 sheetName: String) throws
    {
        guard let actual else {
            throw
                GoogleSheetsClientError
                .invalidData("\(sheetName) has no header")
        }

        let actualHeaders =
            try actual.map {
                cell in
                guard case let .string(value) = cell
                else {
                    throw
                        GoogleSheetsClientError
                        .invalidData("\(sheetName) has an invalid header")
                }

                return value
            }

        guard actualHeaders == expected
        else {
            throw
                GoogleSheetsClientError
                .invalidData("\(sheetName) has an invalid or unsupported header")
        }
    }

    private func validateUniqueRecords(_ records:
        [RemoteSyncRecord]) throws
    {
        var keys =
            Set<SyncEntityKey>()

        for record in records {
            guard keys.insert(record.id).inserted
            else {
                throw
                    GoogleSheetsClientError
                    .invalidData("Duplicate remote entity: \(record.id)")
            }
        }
    }

    // MARK: - Cell readers

    private func readRequiredString(_ row: [Cell],
                                    index: Int,
                                    context: String,
                                    field: String) throws -> String
    {
        guard index < row.count else {
            throw
                GoogleSheetsClientError
                .invalidData("\(context): missing \(field)")
        }

        guard case let .string(value) = row[index],
              !value
              .trimmingCharacters(in:
                  .whitespacesAndNewlines)
              .isEmpty
        else {
            throw
                GoogleSheetsClientError
                .invalidData("\(context): \(field) must be a non-empty string")
        }

        return value
    }

    private func readStringOrEmpty(_ row: [Cell],
                                   index: Int,
                                   context: String,
                                   field: String) throws -> String
    {
        guard index < row.count else {
            return ""
        }

        switch row[index] {
        case let .string(value):
            return value

        default:
            throw
                GoogleSheetsClientError
                .invalidData("\(context): \(field) must be a string")
        }
    }

    private func readOptionalString(_ row: [Cell],
                                    index: Int,
                                    context: String,
                                    field: String) throws -> String?
    {
        guard index < row.count else {
            return nil
        }

        switch row[index] {
        case let .string(value):
            return value.isEmpty
                ? nil
                : value

        default:
            throw
                GoogleSheetsClientError
                .invalidData("\(context): \(field) must be a string or empty")
        }
    }

    private func readInteger(_ row: [Cell],
                             index: Int,
                             context: String,
                             field: String,
                             minimum: Int) throws -> Int
    {
        guard index < row.count,
              case let .number(value) = row[index],
              let integer =
              Int(exactly: value),
              integer >= minimum
        else {
            throw
                GoogleSheetsClientError
                .invalidData("\(context): \(field) must be an integer >= \(minimum)")
        }

        return integer
    }

    private func readUUID(_ row: [Cell],
                          index: Int,
                          context: String,
                          field: String) throws -> UUID
    {
        let value =
            try readRequiredString(row,
                                   index: index,
                                   context: context,
                                   field: field)

        guard let uuid =
            UUID(uuidString: value)
        else {
            throw
                GoogleSheetsClientError
                .invalidData("\(context): \(field) is not a valid UUID")
        }

        return uuid
    }

    private func readOptionalUUID(_ row: [Cell],
                                  index: Int,
                                  context: String,
                                  field: String) throws -> UUID?
    {
        guard let value =
            try readOptionalString(row,
                                   index: index,
                                   context: context,
                                   field: field)
        else {
            return nil
        }

        guard let uuid =
            UUID(uuidString: value)
        else {
            throw
                GoogleSheetsClientError
                .invalidData("\(context): \(field) is not a valid UUID")
        }

        return uuid
    }

    private func readDate(_ row: [Cell],
                          index: Int,
                          context: String,
                          field: String) throws -> Date
    {
        let value =
            try readRequiredString(row,
                                   index: index,
                                   context: context,
                                   field: field)

        return try parseDate(value,
                             context: context,
                             field: field)
    }

    private func readOptionalDate(_ row: [Cell],
                                  index: Int,
                                  context: String,
                                  field: String) throws -> Date?
    {
        guard let value =
            try readOptionalString(row,
                                   index: index,
                                   context: context,
                                   field: field)
        else {
            return nil
        }

        return try parseDate(value,
                             context: context,
                             field: field)
    }

    private func parseDate(_ value: String,
                           context: String,
                           field: String) throws -> Date
    {
        if let date =
            Self
                .iso8601Fractional
                .date(from: value)
        {
            return date
        }

        if let date =
            Self
                .iso8601
                .date(from: value)
        {
            return date
        }

        if let date =
            Self
                .dateOnly
                .date(from: value)
        {
            return date
        }

        throw
            GoogleSheetsClientError
            .invalidData("\(context): \(field) is not a valid date")
    }

    private func isBlank(_ row: [Cell]) -> Bool {
        row.isEmpty
            || row.allSatisfy {
                cell in
                if case let .string(value) = cell {
                    return value.isEmpty
                }

                return false
            }
    }

    // MARK: - Date formatting

    private func formatDateOnly(_ date: Date) -> String {
        let components =
            Calendar.current
                .dateComponents([.year,
                                 .month,
                                 .day],
                                from: date)

        guard let year =
            components.year,
            let month =
            components.month,
            let day =
            components.day
        else {
            return Self
                .dateOnly
                .string(from: date)
        }

        return String(format:
            "%04d-%02d-%02d",
            year,
            month,
            day)
    }

    // MARK: - HTTP

    private func request<T: Decodable>(url: URL,
                                       accessToken: String,
                                       method: String = "GET",
                                       body: Data? = nil) async throws -> T
    {
        var request =
            URLRequest(url: url)

        request.httpMethod =
            method

        request.httpBody =
            body

        request.setValue("Bearer \(accessToken)",
                         forHTTPHeaderField:
                         "Authorization")

        request.setValue("application/json",
                         forHTTPHeaderField:
                         "Accept")

        if body != nil {
            request.setValue("application/json",
                             forHTTPHeaderField:
                             "Content-Type")
        }

        let (data,
             response) =
            try await URLSession
                .shared
                .data(for: request)

        guard let response =
            response
                as? HTTPURLResponse
        else {
            throw
                GoogleSheetsClientError
                .invalidResponse
        }

        guard (200 ..< 300)
            .contains(response
                .statusCode)
        else {
            let errorResponse =
                try? JSONDecoder()
                    .decode(APIErrorResponse
                        .self,
                        from: data)

            throw
                GoogleSheetsClientError
                .apiError(status:
                    response
                        .statusCode,
                    message:
                    errorResponse?
                        .error?
                        .message)
        }

        return try JSONDecoder()
            .decode(T.self,
                    from: data)
    }

    // MARK: - API models

    private struct BatchGetResponse:
        Decodable
    {
        let valueRanges: [ValueRange]

        private enum CodingKeys:
            String,
            CodingKey
        {
            case valueRanges
        }

        init(from decoder:
            Decoder) throws
        {
            let container =
                try decoder
                    .container(keyedBy:
                        CodingKeys.self)

            valueRanges =
                try container
                    .decodeIfPresent([ValueRange].self,
                                     forKey:
                                     .valueRanges)
                    ?? []
        }
    }

    private struct ValueRange:
        Decodable
    {
        let values: [[Cell]]?
    }

    private struct BatchUpdateRequest:
        Encodable
    {
        let valueInputOption: String

        let includeValuesInResponse: Bool

        let data: [WriteValueRange]
    }

    private struct WriteValueRange:
        Encodable
    {
        let range: String
        let majorDimension: String
        let values: [[Cell]]
    }

    private struct BatchUpdateResponse:
        Decodable
    {
        let spreadsheetId: String?
        let totalUpdatedRows: Int?
    }

    private struct APIErrorResponse:
        Decodable
    {
        let error: APIErrorBody?
    }

    private struct APIErrorBody:
        Decodable
    {
        let message: String?
    }

    private enum Cell:
        Codable,
        Equatable
    {
        case string(String)
        case number(Double)
        case bool(Bool)

        init(from decoder:
            Decoder) throws
        {
            let container =
                try decoder
                    .singleValueContainer()

            if let value =
                try? container
                    .decode(String.self)
            {
                self =
                    .string(value)
                return
            }

            if let value =
                try? container
                    .decode(Bool.self)
            {
                self =
                    .bool(value)
                return
            }

            if let value =
                try? container
                    .decode(Double.self)
            {
                self =
                    .number(value)
                return
            }

            throw
                DecodingError
                .typeMismatch(Cell.self,
                              DecodingError
                                  .Context(codingPath:
                                      decoder
                                          .codingPath,
                                      debugDescription:
                                      "Unsupported Google Sheets cell"))
        }

        func encode(to encoder: Encoder) throws {
            var container =
                encoder
                    .singleValueContainer()

            switch self {
            case let .string(value):
                try container
                    .encode(value)

            case let .number(value):
                try container
                    .encode(value)

            case let .bool(value):
                try container
                    .encode(value)
            }
        }
    }

    // MARK: - Date parsers

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter =
            ISO8601DateFormatter()

        formatter.formatOptions = [.withInternetDateTime,
                                   .withFractionalSeconds]

        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter =
            ISO8601DateFormatter()

        formatter.formatOptions = [.withInternetDateTime]

        return formatter
    }()

    private static let dateOnly: DateFormatter = {
        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(identifier:
                "en_US_POSIX")

        formatter.calendar =
            Calendar(identifier:
                .gregorian)

        formatter.timeZone =
            .current

        formatter.dateFormat =
            "yyyy-MM-dd"

        return formatter
    }()
}

nonisolated enum GoogleSheetsClientError:
    Error
{
    case invalidURL
    case invalidResponse

    case apiError(status: Int,
                  message: String?)

    case invalidData(String)

    case writeConflict(SyncEntityKey)
}
