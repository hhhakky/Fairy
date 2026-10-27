//
//  Storage.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import AppKit

enum Storage {
    static let root = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Fairy", isDirectory: true)
    static let skillsDir = root.appendingPathComponent("skills", isDirectory: true)
    static let scriptsDir = skillsDir.appendingPathComponent("scripts", isDirectory: true)
    static let aliasesFile = root.appendingPathComponent("aliases.json")

    /// Первый запуск: создаём папки и кладём стандартные навыки
    static func seedIfNeeded() {
        let firstRun = !FileManager.default.fileExists(atPath: skillsDir.path)
        if firstRun { restoreDefaults() }
    }

    /// Дописывает только недостающие стандартные файлы, твои правки не трогает
    static func restoreDefaults() {
        let fm = FileManager.default
        try? fm.createDirectory(at: scriptsDir, withIntermediateDirectories: true)

        for (name, text) in Defaults.skills {
            writeIfMissing(text, to: skillsDir.appendingPathComponent(name))
        }
        for (name, text) in Defaults.scripts {
            writeIfMissing(text, to: scriptsDir.appendingPathComponent(name))
        }
        writeIfMissing(Defaults.aliases, to: aliasesFile)
    }

    private static func writeIfMissing(_ text: String, to url: URL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
    /// Создаёт файл-шаблон нового навыка и возвращает его адрес
    static func createSkillTemplate() -> URL? {
        let fm = FileManager.default
        try? fm.createDirectory(at: skillsDir, withIntermediateDirectories: true)
        var n = 1
        while fm.fileExists(atPath: skillsDir.appendingPathComponent("my_skill_\(n).json").path) { n += 1 }
        let id = "my_skill_\(n)"
        let text = """
        {
          "id": "\(id)",
          "description": "Say hello (example skill; describe the real action in English)",
          "triggers": ["привет фея"],
          "run": [["echo", "Привет!"]],
          "output": "show",
          "display": { "text": "привет…", "icon": "hand.wave" }
        }
        """
        let url = skillsDir.appendingPathComponent("\(id).json")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
    static func openSkillsFolder() { NSWorkspace.shared.open(skillsDir) }
    static func openScriptsFolder() { NSWorkspace.shared.open(scriptsDir) }
}
