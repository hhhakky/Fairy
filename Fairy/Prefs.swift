//
//  Prefs.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import Foundation

enum Prefs {
    static let showMenuBarIcon = "showMenuBarIcon"
    static let showIsland = "showIsland"
    static let llmModel = "llmModel"
    static let serverEnabled = "serverEnabled"
    static let serverPort = "serverPort"

    static let defaultModel = "openai/gpt-oss-20b"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarIcon: true,
            showIsland: true,
            llmModel: defaultModel,
            serverEnabled: true,
            serverPort: 8765
        ])
    }
}
