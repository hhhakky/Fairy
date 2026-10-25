//
//  LocalRouter.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
// быстрый разбор команд без нейросети
import Foundation

struct LocalRouter {
    let catalog: AppCatalog

    /// Слова, которые просто выбрасываем
    private let noise: Set<String> = [
        "фея", "fairy", "пожалуйста", "плиз", "please", "мне", "ну", "эй", "слушай",
        "давай", "быстро", "сейчас", "можешь", "можно", "будь", "добр", "а", "и",
        "приложение", "программу", "программа", "на", "ка", "ты", "бы", "не", "мог"
    ]
    
    private let openVerbs: [[String]] = [
        ["запусти"], ["запустить"], ["открой"], ["открыть"], ["включи"],
        ["open"], ["launch"], ["start"]
    ]
    private let quitVerbs: [[String]] = [
        ["закрой"], ["закрыть"], ["выключи"], ["выйди", "из"], ["quit"], ["close"]
    ]

    func route(_ raw: String) -> FairyAction? {
        let tokens = tokenize(raw).filter { !noise.contains($0) }
        guard !tokens.isEmpty else { return nil }
        let phrase = tokens.joined(separator: " ")

        // Звук (раньше глаголов, чтобы "выключи звук" не стало "закрыть приложение звук")
        if ["выключи звук", "без звука", "mute"].contains(phrase) { return .mute(true) }
        if ["включи звук", "верни звук", "unmute"].contains(phrase) { return .mute(false) }

        if tokens.contains(where: { $0 == "громкость" || $0 == "volume" }),
           let n = tokens.compactMap({ Int($0) }).first {
            return .setVolume(min(max(n, 0), 100))
        }

        // Приложения: нужен и известный глагол, и реально существующее приложение
        if let rest = strip(tokens, verbs: openVerbs),
           let app = catalog.resolve(rest.joined(separator: " ")) {
            return .openApp(app)
        }
        if let rest = strip(tokens, verbs: quitVerbs),
           let app = catalog.resolve(rest.joined(separator: " ")) {
            return .quitApp(app)
        }

        return nil
    }

    /// Если токены начинаются с одного из глаголов, возвращает остаток
    private func strip(_ tokens: [String], verbs: [[String]]) -> [String]? {
        for verb in verbs.sorted(by: { $0.count > $1.count })
        where tokens.count > verb.count && Array(tokens.prefix(verb.count)) == verb {
            return Array(tokens.dropFirst(verb.count))
        }
        return nil
    }
}
