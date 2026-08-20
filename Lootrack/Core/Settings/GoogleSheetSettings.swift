//
//  GoogleSheetSettings.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 20/08/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class GoogleSheetSettings {
    var spreadsheetId: String? {
        didSet {
            persistOptional(spreadsheetId, forKey: Keys.spreadsheetId)
        }
    }

    var spreadsheetName: String? {
        didSet {
            persistOptional(spreadsheetName, forKey: Keys.spreadsheetName)
        }
    }

    private let storage: UserDefaults

    init(storage: UserDefaults = .standard, initialSpreadsheetId: String? = nil) {
        self.storage = storage

        if storage.bool(forKey: Keys.didInitialize) {
            spreadsheetId = storage.string(forKey: Keys.spreadsheetId)
        } else {
            spreadsheetId = initialSpreadsheetId
            persistInitial(initialSpreadsheetId, forKey: Keys.spreadsheetId)
            storage.set(true, forKey: Keys.didInitialize)
        }

        spreadsheetName = storage.string(forKey: Keys.spreadsheetName)
    }

    func select(spreadsheetId: String, name: String?) {
        self.spreadsheetId = spreadsheetId
        spreadsheetName = name
    }

    func clearSelection() {
        spreadsheetId = nil
        spreadsheetName = nil
    }

    private func persistInitial(_ value: String?, forKey key: String) {
        if let value {
            storage.set(value, forKey: key)
        }
    }

    private func persistOptional(_ value: String?, forKey key: String) {
        if let value {
            storage.set(value, forKey: key)
        } else {
            storage.removeObject(forKey: key)
        }
    }

    private enum Keys {
        static let didInitialize = "settings.sync.googleSheets.didInitialize"
        static let spreadsheetId = "settings.sync.googleSheets.spreadsheetId"
        static let spreadsheetName = "settings.sync.googleSheets.spreadsheetName"
    }
}
