//
//  AppCatalog.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
//  Список установленных приложений и поиск по названию.
import Foundation

struct AppEntry {
    let file: String          // Для open -a: "Reminders".
    let keys: Set<String>     // Имена, по которым приложение можно найти.
}

final class AppCatalog {
    private(set) var entries: [AppEntry] = []
    private var fingerprint = ""

    init() {
        reloadIfNeeded()
    }

    /// Пересканирует папки приложений, только если изменилось их содержимое.
    @discardableResult
    func reloadIfNeeded() -> Bool {
        let currentFingerprint = Self.directoryFingerprint()
        guard currentFingerprint != fingerprint else { return false }

        fingerprint = currentFingerprint
        entries = Self.scan()
        return true
    }

    /// Точное совпадение — 3, единственный префикс или основа слова — 1, неоднозначность — 0.
    func matchQuality(_ query: String) -> Int {
        lookup(query)?.quality ?? 0
    }

    /// Возвращает настоящее имя приложения для open -a или nil, если оно не найдено однозначно.
    func resolve(_ query: String) -> String? {
        lookup(query)?.file
    }

    private func lookup(_ query: String) -> (file: String, quality: Int)? {
        let key = normalize(query)
        guard !key.isEmpty else { return nil }

        if let exact = entries.first(where: { $0.keys.contains(key) }) {
            return (exact.file, 3)
        }
        guard key.count >= 3 else { return nil }

        let prefixed = entries.filter { $0.keys.contains { $0.hasPrefix(key) } }
        if prefixed.count == 1 { return (prefixed[0].file, 1) }
        if prefixed.count > 1 { return nil }

        // «музыку» → «музыка», «заметку» → «заметки»: отбрасываем падежное окончание,
        // но снова только при единственном совпадении
        guard key.count >= 5 else { return nil }
        let stem = String(key.dropLast(key.count >= 7 ? 2 : 1))
        let stemmed = entries.filter { $0.keys.contains { $0.hasPrefix(stem) } }
        return stemmed.count == 1 ? (stemmed[0].file, 1) : nil
    }
    private static func searchDirectories() -> [String] {
        let home = NSHomeDirectory()
        return [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices",
            "\(home)/Applications"
        ]
    }

    private static func directoryFingerprint() -> String {
        searchDirectories().map { directory in
            let modified = (try? FileManager.default.attributesOfItem(atPath: directory)[.modificationDate]) as? Date
            return "\(directory):\(modified?.timeIntervalSince1970 ?? 0)"
        }.joined(separator: "|")
    }

    private static func scan() -> [AppEntry] {
        var found: [String: AppEntry] = [:]

        for directory in searchDirectories() {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
            for item in items where item.hasSuffix(".app") {
                let fileName = String(item.dropLast(4))
                guard found[fileName] == nil else { continue }

                var displayName = FileManager.default.displayName(atPath: "\(directory)/\(item)")
                if displayName.hasSuffix(".app") {
                    displayName = String(displayName.dropLast(4))
                }

                found[fileName] = AppEntry(
                    file: fileName,
                    keys: [normalize(fileName), normalize(displayName)]
                )
            }
        }

        return found.values.sorted { $0.file < $1.file }
    }
}
