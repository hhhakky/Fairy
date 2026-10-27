//
//  AppCatalog.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
// список установленных приложений и поиск по названию
import Foundation

struct AppEntry {
    let file: String          // для open -a: "Reminders"
    let keys: Set<String>     // как его можно назвать: "reminders", "напоминания"
}

final class AppCatalog {
    private(set) var entries: [AppEntry] = []
    private var fingerprint = ""

    init() {
        reloadIfNeeded()
    }

    /// Пересканирует папки приложений, если их mtime сменился.
    @discardableResult
    func reloadIfNeeded() -> Bool {
        let fp = Self.directoryFingerprint()
        guard fp != fingerprint else { return false }
        fingerprint = fp
        entries = Self.scan()
        return true
    }

    /// 3 — точное имя, 1 — единственный префикс, 0 — нет однозначного совпадения.
    func matchQuality(_ query: String) -> Int {
        let q = normalize(query)
        guard !q.isEmpty else { return 0 }
        if entries.contains(where: { $0.keys.contains(q) }) { return 3 }
        guard q.count >= 3 else { return 0 }
        let prefixed = entries.filter { $0.keys.contains { $0.hasPrefix(q) } }
        return prefixed.count == 1 ? 1 : 0
    }

    /// Возвращает настоящее имя приложения (для open -a) или nil
    func resolve(_ query: String) -> String? {
        let q = normalize(query)
        guard !q.isEmpty else { return nil }

        if let e = entries.first(where: { $0.keys.contains(q) }) { return e.file }
        guard q.count >= 3 else { return nil }
        let prefixed = entries.filter { $0.keys.contains { $0.hasPrefix(q) } }
        if prefixed.count == 1 { return prefixed[0].file }
        return nil
    }

    private static func searchDirs() -> [String] {
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
        searchDirs().map { dir in
            let mtime = (try? FileManager.default.attributesOfItem(atPath: dir)[.modificationDate] as? Date)?
                .timeIntervalSince1970 ?? 0
            return "\(dir):\(mtime)"
        }.joined(separator: "|")
    }

    private static func scan() -> [AppEntry] {
        var found: [String: AppEntry] = [:]
        for dir in searchDirs() {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
            for item in items where item.hasSuffix(".app") {
                let file = String(item.dropLast(4))
                guard found[file] == nil else { continue }

                var display = FileManager.default.displayName(atPath: "\(dir)/\(item)")
                if display.hasSuffix(".app") { display = String(display.dropLast(4)) }

                found[file] = AppEntry(file: file, keys: [normalize(file), normalize(display)])
            }
        }
        return found.values.sorted { $0.file < $1.file }
    }
}
