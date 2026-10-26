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
    static let aliasesFile = root.appendingPathComponent("aliases.json")

    /// Первый запуск: создаём папку и кладём стандартные навыки
    static func seedIfNeeded() {
        let firstRun = !FileManager.default.fileExists(atPath: skillsDir.path)
        if firstRun { restoreDefaults() }
    }

    /// Дописывает только недостающие стандартные файлы, твои правки не трогает
    static func restoreDefaults() {
        let fm = FileManager.default
        try? fm.createDirectory(at: skillsDir, withIntermediateDirectories: true)
        for (name, text) in Defaults.skills {
            let url = skillsDir.appendingPathComponent(name)
            if !fm.fileExists(atPath: url.path) {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        if !fm.fileExists(atPath: aliasesFile.path) {
            try? Defaults.aliases.write(to: aliasesFile, atomically: true, encoding: .utf8)
        }
    }

    static func openSkillsFolder() {
        NSWorkspace.shared.open(skillsDir)
    }
}
