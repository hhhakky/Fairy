//
//  Skill.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
// формат навыка, проверка и загрузка из папки
import Foundation

enum ParamType: String, Codable {
    case app, folder, url, text, query, int
}

struct ParamSpec: Codable {
    let type: ParamType
    let min: Int?
    let max: Int?
}

enum OutputMode: String, Codable {
    case none, show
}

/// "display" можно писать строкой ("open -a {app}") или объектом ({"text": "...", "icon": "..."})
struct DisplaySpec: Codable {
    let text: String?
    let icon: String?

    private enum Keys: String, CodingKey { case text, icon }

    init(from decoder: Decoder) throws {
        if let o = try? decoder.container(keyedBy: Keys.self) {
            text = try o.decodeIfPresent(String.self, forKey: .text)
            icon = try o.decodeIfPresent(String.self, forKey: .icon)
        } else {
            text = try decoder.singleValueContainer().decode(String.self)
            icon = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var o = encoder.container(keyedBy: Keys.self)
        try o.encodeIfPresent(text, forKey: .text)
        try o.encodeIfPresent(icon, forKey: .icon)
    }
}

struct Skill: Codable {
    let id: String
    let description: String
    let triggers: [String]?
    let params: [String: ParamSpec]?
    let run: [[String]]
    let display: DisplaySpec?
    let output: OutputMode?
    let timeout: Int?
    let confirm: Bool?

    /// Возвращает понятное описание ошибки или nil, если навык корректен
    func validate() -> String? {
        if id.trimmingCharacters(in: .whitespaces).isEmpty { return "пустой id" }
        if run.isEmpty || run.contains(where: { $0.isEmpty }) {
            return "в «run» должна быть хотя бы одна непустая команда"
        }
        if run.contains(where: { $0[0].contains("{") }) {
            return "первый элемент в «run» (программа или скрипт) не может содержать параметры"
        }
        if let t = timeout, !(1...120).contains(t) {
            return "timeout должен быть от 1 до 120 секунд"
        }
        let known = Set((params ?? [:]).keys)
        var texts = run.flatMap { $0 } + (triggers ?? [])
        if let d = display?.text { texts.append(d) }
        for name in texts.flatMap(placeholders) where !known.contains(name) {
            return "используется {\(name)}, но такого параметра нет в «params»"
        }
        return nil
    }
}

struct Aliases: Codable {
    var apps: [String: String] = [:]
    var folders: [String: String] = [:]
    var sites: [String: String] = [:]

    enum CodingKeys: String, CodingKey { case apps, folders, sites }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apps = try c.decodeIfPresent([String: String].self, forKey: .apps) ?? [:]
        folders = try c.decodeIfPresent([String: String].self, forKey: .folders) ?? [:]
        sites = try c.decodeIfPresent([String: String].self, forKey: .sites) ?? [:]
    }

    func normalized() -> Aliases {
        func norm(_ d: [String: String]) -> [String: String] {
            Dictionary(d.map { (normalize($0.key), $0.value) }, uniquingKeysWith: { a, _ in a })
        }
        var r = Aliases()
        r.apps = norm(apps); r.folders = norm(folders); r.sites = norm(sites)
        return r
    }
}

func placeholders(in s: String) -> [String] {
    guard let re = try? NSRegularExpression(pattern: #"\{([^{}]+)\}"#) else { return [] }
    let ns = s as NSString
    return re.matches(in: s, range: NSRange(location: 0, length: ns.length))
        .map { ns.substring(with: $0.range(at: 1)) }
}

/// Подставляет {имя} в один проход. Подставленные значения повторно не разбираются.
func fill(_ template: String, _ values: [String: String]) -> String? {
    var out = ""
    var i = template.startIndex
    while i < template.endIndex {
        if template[i] == "{", let close = template[i...].firstIndex(of: "}") {
            let name = String(template[template.index(after: i)..<close])
            guard let v = values[name] else { return nil }
            out += v
            i = template.index(after: close)
        } else {
            out.append(template[i])
            i = template.index(after: i)
        }
    }
    return out
}

/// Читает навыки с диска. Обновляется только если файлы изменились.
final class SkillStore {
    private(set) var skills: [Skill] = []
    private(set) var aliases = Aliases()
    private(set) var errors: [String] = []
    private var fingerprint = ""

    @discardableResult
    func reloadIfNeeded() -> Bool {
        let fp = computeFingerprint()
        guard fp != fingerprint else { return false }
        fingerprint = fp
        load()
        return true
    }

    private func jsonFiles() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: Storage.skillsDir, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func computeFingerprint() -> String {
        (jsonFiles() + [Storage.aliasesFile]).map { url in
            let d = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            return "\(url.lastPathComponent):\(d?.timeIntervalSince1970 ?? 0)"
        }.joined(separator: "|")
    }

    private func load() {
        var loaded: [Skill] = []
        var errs: [String] = []
        var seen = Set<String>()

        for url in jsonFiles() {
            let name = url.lastPathComponent
            do {
                let skill = try JSONDecoder().decode(Skill.self, from: Data(contentsOf: url))
                if let problem = skill.validate() { errs.append("\(name): \(problem)"); continue }
                if !seen.insert(skill.id).inserted { errs.append("\(name): id «\(skill.id)» уже занят"); continue }
                loaded.append(skill)
            } catch {
                errs.append("\(name): \(describe(error))")
            }
        }

        aliases = Aliases()
        if let data = try? Data(contentsOf: Storage.aliasesFile) {
            if let a = try? JSONDecoder().decode(Aliases.self, from: data) {
                aliases = a.normalized()
            } else {
                errs.append("aliases.json: ошибка JSON (проверь запятые и кавычки)")
            }
        }

        skills = loaded
        errors = errs
        for e in errs { print("Skill error:", e) }
    }

    private func describe(_ e: Error) -> String {
        if let d = e as? DecodingError {
            switch d {
            case .keyNotFound(let k, _):
                return "нет поля «\(k.stringValue)»"
            case .typeMismatch(_, let c), .valueNotFound(_, let c):
                return "неверный тип в «\(c.codingPath.map(\.stringValue).joined(separator: "."))»"
            case .dataCorrupted(let c):
                switch c.codingPath.last?.stringValue {
                case "type":   return "неизвестный type (допустимо: app, folder, url, text, query, int)"
                case "output": return "неизвестный output (допустимо: none, show)"
                default:       return "ошибка JSON (проверь запятые и кавычки)"
                }
            @unknown default: break
            }
        }
        return "не удалось прочитать файл"
    }
}
