import Foundation
import Observation

enum SyncInterval: Int, CaseIterable, Identifiable {
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60

    var id: Int {
        rawValue
    }

    var duration: TimeInterval {
        TimeInterval(rawValue * 60)
    }

    var displayName: String {
        switch self {
        case .fiveMinutes:
            String(localized: "5 minutes")
        case .fifteenMinutes:
            String(localized: "15 minutes")
        case .thirtyMinutes:
            String(localized: "30 minutes")
        case .oneHour:
            String(localized: "1 hour")
        }
    }
}

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

    func displayName(locale: Locale) -> String {
        switch self {
        case .system:
            String(localized: "System", locale: locale)

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
                storage.set(language.rawValue,
                            forKey: Keys.language)
            }
        }
    }

    /// ISO 3166-1 region code, e.g. "IT", "US".
    /// nil means "follow the system".
    var regionCode: String? {
        didSet {
            persistOptional(regionCode,
                            forKey: Keys.regionCode)
        }
    }

    /// ISO 4217 currency code, e.g. "EUR", "USD".
    /// nil means "derive it from the effective locale".
    var currencyCode: String? {
        didSet {
            persistOptional(currencyCode,
                            forKey: Keys.currencyCode)
        }
    }

    // MARK: - Sync

    var automaticSyncEnabled: Bool {
        didSet {
            storage.set(automaticSyncEnabled, forKey: Keys.automaticSyncEnabled)
        }
    }

    var syncInterval: SyncInterval {
        didSet {
            storage.set(syncInterval.rawValue, forKey: Keys.syncInterval)
        }
    }

    // MARK: - Effective values

    var resolvedLanguageCode: String {
        language.languageCode
            ?? Locale.autoupdatingCurrent
            .language
            .languageCode?
            .identifier
            ?? "en"
    }

    var resolvedRegionCode: String {
        regionCode
            ?? Locale.autoupdatingCurrent
            .region?
            .identifier
            ?? "US"
    }

    var resolvedLocale: Locale {
        if language == .system, regionCode == nil {
            return .autoupdatingCurrent
        }

        return Locale(identifier:
            "\(resolvedLanguageCode)_\(resolvedRegionCode)")
    }

    var resolvedCurrencyCode: String {
        currencyCode
            ?? resolvedLocale
            .currency?
            .identifier
            ?? Locale.autoupdatingCurrent
            .currency?
            .identifier
            ?? "EUR"
    }

    var resolvedCurrencySymbol: String {
        let formatter = NumberFormatter()

        formatter.numberStyle = .currency
        formatter.locale = resolvedLocale
        formatter.currencyCode = resolvedCurrencyCode

        return formatter.currencySymbol ?? resolvedCurrencyCode
    }

    var decimalSeparator: String {
        resolvedLocale.decimalSeparator ?? "."
    }

    func formattedAmount(_ amountInCents: Int) -> String {
        let amount = Double(amountInCents) / 100

        return amount.formatted(.currency(code: resolvedCurrencyCode)
            .precision(.fractionLength(2))
            .locale(resolvedLocale))
    }

    // MARK: - Persistence

    private let storage: UserDefaults

    init(storage: UserDefaults = .standard) {
        self.storage = storage

        if let storedLanguage = storage.string(forKey: Keys.language) {
            language = AppLanguage(rawValue: storedLanguage) ?? .system
        } else {
            language = .system
        }

        regionCode = storage.string(forKey: Keys.regionCode)
        currencyCode = storage.string(forKey: Keys.currencyCode)

        if storage.object(forKey: Keys.automaticSyncEnabled) == nil {
            automaticSyncEnabled = true
        } else {
            automaticSyncEnabled = storage.bool(forKey: Keys.automaticSyncEnabled)
        }

        let storedSyncInterval = storage.integer(forKey: Keys.syncInterval)
        syncInterval =
            SyncInterval(rawValue: storedSyncInterval) ?? .fifteenMinutes
    }

    private func persistOptional(_ value: String?, forKey key: String) {
        if let value {
            storage.set(value, forKey: key)
        } else {
            storage.removeObject(forKey: key)
        }
    }

    private enum Keys {
        static let language = "settings.general.language"
        static let regionCode = "settings.general.region"
        static let currencyCode = "settings.general.currency"
        static let automaticSyncEnabled = "settings.sync.automatic"
        static let syncInterval = "settings.sync.interval"
    }
}
