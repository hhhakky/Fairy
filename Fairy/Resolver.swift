//
//  Resolver.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import Foundation

struct ParamResolver {
    let catalog: AppCatalog
    let aliases: Aliases

    func resolveAll(_ skill: Skill, given: [String: String]) -> [String: String]? {
        var out: [String: String] = [:]
        for (name, spec) in skill.params ?? [:] {
            guard let raw = given[name], let value = resolve(raw, spec) else { return nil }
            out[name] = value
        }
        return out
    }

    func resolve(_ raw: String, _ spec: ParamSpec) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 500 else { return nil }

        switch spec.type {
        case .app:
            let key = normalize(text)
            guard let name = catalog.resolve(aliases.apps[key] ?? key),
                  !name.hasPrefix("-") else { return nil }
            return name

        case .folder:
            return resolveFolder(text)

        case .url:
            let key = normalize(text)
            return makeURL(aliases.sites[key] ?? key)

        case .text:
            return text

        case .query:
            // кодируем всё, кроме безопасных символов: подмешать лишний параметр в адрес нельзя
            let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
            return text.addingPercentEncoding(withAllowedCharacters: safe)

        case .int:
            guard var v = Int(text) else { return nil }
            if let lo = spec.min { v = max(v, lo) }
            if let hi = spec.max { v = min(v, hi) }
            return String(v)
        }
    }

    private func resolveFolder(_ text: String) -> String? {
        let key = normalize(text)
        var path = aliases.folders[key] ?? key
        if !path.hasPrefix("/") && !path.hasPrefix("~") { path = "~/" + path }
        path = ((path as NSString).expandingTildeInPath as NSString).standardizingPath

        let home = NSHomeDirectory()
        let allowed = path == home || path.hasPrefix(home + "/")
            || path == "/Applications" || path.hasPrefix("/Applications/")
            || path.hasPrefix("/Volumes/")

        var isDir: ObjCBool = false
        guard allowed,
              FileManager.default.fileExists(atPath: path, isDirectory: &isDir),
              isDir.boolValue else { return nil }
        return path
    }

    private func makeURL(_ s: String) -> String? {
        guard !s.contains(" ") else { return nil }
        let full = s.contains("://") ? s : "https://" + s
        guard let c = URLComponents(string: full),
              let scheme = c.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = c.host, host.contains("."),
              let url = c.url else { return nil }
        return url.absoluteString
    }
}

extension ParamResolver {
    /// Ответ нейросети превращаем в действие по тем же правилам проверки, что и локальный путь
    func invocation(from reply: LLMRouter.Reply, skills: [Skill]) -> Invocation? {
        guard let skill = skills.first(where: { $0.id == reply.skill }) else { return nil }
        let given = (reply.args ?? [:]).mapValues(\.value)
        guard let values = resolveAll(skill, given: given) else { return nil }
        return Invocation(skill: skill, values: values)
    }
}
