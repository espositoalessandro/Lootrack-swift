import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case italian = "it"

    var id: String {
        rawValue
    }

    var languageCode: String? {
        switch self {
        case .system:
            nil

        case .english:
            "en"

        case .italian:
            "it"
        }
    }

    var displayName: String {
        switch self {
        case .system:
            String(localized: "System")

        case .english:
            "English"

        case .italian:
            "Italiano"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    // MARK: - General

    var language: AppLanguage {
        didSet {
            if language == .system {
                storage.removeObject(forKey: Keys.language)
            } else {
                storage.set(
                    language.rawValue,
                    forKey: Keys.language
                )
            }
        }
    }

    /// ISO 3166-1 region code, e.g. "IT", "US".
    /// nil means "follow the system".
    var regionCode: String? {
        didSet {
            persistOptional(
                regionCode,
                forKey: Keys.regionCode
            )
        }
    }

    /// ISO 4217 currency code, e.g. "EUR", "USD".
    /// nil means "derive it from the effective locale".
    var currencyCode: String? {
        didSet {
            persistOptional(
                currencyCode,
                forKey: Keys.currencyCode
            )
        }
    }

    // MARK: - Effective values

    var resolvedLanguageCode: String {
        language.languageCode
            ?? Locale.current.language
            .languageCode?
            .identifier
            ?? "en"
    }

    var resolvedRegionCode: String {
        regionCode
            ?? Locale.current.region?.identifier
            ?? "US"
    }

    var resolvedLocale: Locale {
        if language == .system,
            regionCode == nil
        {
            return .current
        }

        return Locale(
            identifier:
                "\(resolvedLanguageCode)_\(resolvedRegionCode)"
        )
    }

    var resolvedCurrencyCode: String {
        currencyCode
            ?? resolvedLocale.currency?.identifier
            ?? Locale.current.currency?.identifier
            ?? "USD"
    }

    // MARK: - Persistence

    private let storage: UserDefaults

    init(storage: UserDefaults = .standard) {
        self.storage = storage

        if let storedLanguage = storage.string(forKey: Keys.language) {
            language =
                AppLanguage(rawValue: storedLanguage) ?? .system
        } else {
            language = .system
        }

        regionCode = storage.string(forKey: Keys.regionCode)

        currencyCode = storage.string(forKey: Keys.currencyCode)
    }

    private func persistOptional(
        _ value: String?,
        forKey key: String
    ) {
        if let value {
            storage.set(
                value,
                forKey: key
            )
        } else {
            storage.removeObject(forKey: key)
        }
    }

    private enum Keys {
        static let language =
            "settings.general.language"

        static let regionCode =
            "settings.general.region"

        static let currencyCode =
            "settings.general.currency"
    }
}
