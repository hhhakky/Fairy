//
//  AppCatalog.swift
//  Fairy
//
//  Список установленных приложений и поиск по названию.
import Foundation

struct AppEntry {
    let file: String          // Для open -a: "Reminders".
    let keys: Set<String>     // Имена, по которым приложение можно найти.
}

final class AppCatalog {
    private(set) var entries: [AppEntry] = []
    /// Сколько приложений получили названия на других языках (для проверки в настройках)
    private(set) var localizedCount = 0
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
        let result = Self.scan()
        entries = result.entries
        localizedCount = result.localized
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

    private static func scan() -> (entries: [AppEntry], localized: Int) {
        var found: [String: AppEntry] = [:]
        var localized = 0

        for directory in searchDirectories() {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
            for item in items where item.hasSuffix(".app") {
                let fileName = String(item.dropLast(4))
                guard found[fileName] == nil else { continue }

                let appPath = "\(directory)/\(item)"
                var displayName = FileManager.default.displayName(atPath: appPath)
                if displayName.hasSuffix(".app") {
                    displayName = String(displayName.dropLast(4))
                }

                var keys: Set<String> = [normalize(fileName), normalize(displayName)]
                let extra = Set(localizedNames(of: URL(fileURLWithPath: appPath))
                    .map(normalize)
                    .filter { !$0.isEmpty })
                    .subtracting(keys)
                if !extra.isEmpty {
                    localized += 1
                    keys.formUnion(extra)
                }

                found[fileName] = AppEntry(file: fileName, keys: keys)
            }
        }

        return (found.values.sorted { $0.file < $1.file }, localized)
    }

    // MARK: - Названия на разных языках

    private static let languages = ["ru", "ru_RU", "Russian", "en", "English"]

    /// Читает названия из файлов локализации самого приложения.
    private static func localizedNames(of appURL: URL) -> [String] {
        let resources = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let nameKeys = ["CFBundleDisplayName", "CFBundleName"]
        var names: [String] = []

        func collect(_ dict: [String: Any]) {
            for key in nameKeys {
                if let name = dict[key] as? String { names.append(name) }
            }
        }

        // Классический формат: ru.lproj/InfoPlist.strings
        for lang in languages {
            let url = resources.appendingPathComponent("\(lang).lproj/InfoPlist.strings")
            if let dict = NSDictionary(contentsOf: url) as? [String: Any] { collect(dict) }
        }

        // Новый формат: один файл InfoPlist.loctable со всеми языками
        let table = resources.appendingPathComponent("InfoPlist.loctable")
        if let all = NSDictionary(contentsOf: table) as? [String: Any] {
            for lang in languages {
                if let dict = all[lang] as? [String: Any] { collect(dict) }
            }
        }

        return names
    }
}
