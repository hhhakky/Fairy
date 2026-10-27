//
//  Prefs.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import Foundation

enum Prefs {
    // Основное
    static let showMenuBarIcon = "showMenuBarIcon"
    static let showIsland = "showIsland"

    // Нейросеть
    static let llmModel = "llmModel"
    static let llmEnabled = "llmEnabled"
    static let llmTimeout = "llmTimeout"

    // Сервер
    static let serverEnabled = "serverEnabled"
    static let serverPort = "serverPort"

    // Оформление острова
    static let islandStyle = "islandStyle"
    static let accentHex = "accentHex"
    static let cornerRadius = "cornerRadius"
    static let fontSize = "fontSize"
    static let fontDesign = "fontDesign"
    static let islandMaxWidth = "islandMaxWidth"
    static let showIcon = "showIcon"
    static let stateColors = "stateColors"
    static let glow = "glow"
    static let borderAlpha = "borderAlpha"
    static let islandAlpha = "islandAlpha"
    static let topOffset = "topOffset"
    static let animSpeed = "animSpeed"
    static let animBounce = "animBounce"
    static let holdFactor = "holdFactor"

    static let defaultModel = "openai/gpt-oss-20b"

    enum Default {
        static let style = "solid"
        static let accentHex = "#7DF9FF"
        static let cornerRadius = 18.0
        static let fontSize = 13.0
        static let fontDesign = "rounded"
        static let maxWidth = 420.0
        static let showIcon = true
        static let stateColors = true
        static let glow = 0.4
        static let borderAlpha = 0.15
        static let alpha = 1.0
        static let topOffset = 4.0
        static let animSpeed = 0.35
        static let bounce = 0.0
        static let holdFactor = 1.0
    }

    private static let appearanceKeys = [
        islandStyle, accentHex, cornerRadius, fontSize, fontDesign, islandMaxWidth,
        showIcon, stateColors, glow, borderAlpha, islandAlpha, topOffset,
        animSpeed, animBounce, holdFactor
    ]

    private static let otherKeys = [
        showMenuBarIcon, showIsland, llmModel, llmEnabled, llmTimeout,
        serverEnabled, serverPort
    ]

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarIcon: true,
            showIsland: true,
            llmModel: defaultModel,
            llmEnabled: true,
            llmTimeout: 10.0,
            serverEnabled: true,
            serverPort: 8765,
            islandStyle: Default.style,
            accentHex: Default.accentHex,
            cornerRadius: Default.cornerRadius,
            fontSize: Default.fontSize,
            fontDesign: Default.fontDesign,
            islandMaxWidth: Default.maxWidth,
            showIcon: Default.showIcon,
            stateColors: Default.stateColors,
            glow: Default.glow,
            borderAlpha: Default.borderAlpha,
            islandAlpha: Default.alpha,
            topOffset: Default.topOffset,
            animSpeed: Default.animSpeed,
            animBounce: Default.bounce,
            holdFactor: Default.holdFactor
        ])
    }

    static func resetAppearance() {
        for k in appearanceKeys { UserDefaults.standard.removeObject(forKey: k) }
    }

    /// Ключ API и токен сервера лежат в Keychain и не затрагиваются
    static func resetAll() {
        for k in appearanceKeys + otherKeys { UserDefaults.standard.removeObject(forKey: k) }
    }
}
