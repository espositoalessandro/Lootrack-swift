//
//  AppLogger.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 20/08/2026.
//


import OSLog

nonisolated
enum AppLogger {
    static let persistence =
        Logger(subsystem: "com.alessandroesposito.Lootrack",
               category: "Persistence")

    static let sync =
        Logger(subsystem: "com.alessandroesposito.Lootrack",
               category: "Sync")

    static let googleSheets =
        Logger(subsystem: "com.alessandroesposito.Lootrack",
               category: "GoogleSheets")

    static let ai =
        Logger(subsystem: "com.alessandroesposito.Lootrack",
               category: "AI")

    static let ui =
        Logger(subsystem: "com.alessandroesposito.Lootrack",
               category: "UI")
}