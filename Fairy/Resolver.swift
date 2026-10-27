//
//  Resolver.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import Foundation

/// Reads Safari bookmarks locally so site names can be resolved without a hard-coded alias.
final class SiteCatalog {
    private struct Bookmark {
        let title: String
        let url: String
    }

    private let bookmarksURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Safari/Bookmarks.plist")
    private var fingerprint = ""
    private var bookmarks: [Bookmark] = []

    init() {
        reloadIfNeeded()
    }

    @discardableResult
    func reloadIfNeeded() -> Bool {
        let modified = (try? bookmarksURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate?.timeIntervalSince1970 ?? 0
        let currentFingerprint = "\(bookmarksURL.path):\(modified)"
        guard currentFingerprint != fingerprint else { return false }
        fingerprint = currentFingerprint
        bookmarks = Self.readBookmarks(from: bookmarksURL)
        return true
    }

    /// Exact title or URL match scores highest; unique title/host fragments score lower.
    func matchQuality(_ query: String) -> Int {
        let key = normalize(query)
        guard !key.isEmpty else { return 0 }
        let exact = matchingBookmarks(for: key, partial: false)
        if Set(exact.map(\.url)).count == 1, !exact.isEmpty { return 3 }
        guard key.count >= 3 else { return 0 }
        return Set(matchingBookmarks(for: key, partial: true).map(\.url)).count == 1 ? 1 : 0
    }

    func resolve(_ query: String) -> String? {
        let key = normalize(query)
        guard !key.isEmpty else { return nil }
        let exact = Set(matchingBookmarks(for: key, partial: false).map(\.url))
        if exact.count == 1 { return exact.first }
        guard key.count >= 3 else { return nil }
        let partial = Set(matchingBookmarks(for: key, partial: true).map(\.url))
        return partial.count == 1 ? partial.first : nil
    }

    var suggestedNames: [String] {
        Array(Set(bookmarks.map(\.title))).sorted().prefix(80).map { $0 }
    }

    private func matchingBookmarks(for key: String, partial: Bool) -> [Bookmark] {
        bookmarks.filter { bookmark in
            let title = normalize(bookmark.title)
            let urlText = normalize(bookmark.url)
            let host = normalize(URLComponents(string: bookmark.url)?.host ?? "")
            if partial {
                return title.contains(key) || host.contains(key) || urlText.contains(key)
            }
            return title == key || host == key || urlText == key
        }
    }

    private static func readBookmarks(from url: URL) -> [Bookmark] {
        guard let data = try? Data(contentsOf: url),
              let root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else { return [] }

        var result: [Bookmark] = []
        func visit(_ value: Any) {
            guard let dictionary = value as? [String: Any] else { return }

            if let rawURL = dictionary["URLString"] as? String,
               let components = URLComponents(string: rawURL),
               let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
               let host = components.host,
               let url = components.url {
                let uri = dictionary["URIDictionary"] as? [String: Any]
                let title = (uri?["title"] as? String)
                    ?? (dictionary["Title"] as? String)
                    ?? host
                result.append(Bookmark(title: title, url: url.absoluteString))
            }

            for child in (dictionary["Children"] as? [Any]) ?? [] {
                visit(child)
            }
        }
        visit(root)
        return result
    }
}

struct ParamResolver {
    let catalog: AppCatalog
    let sites: SiteCatalog
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
            return makeURL(aliases.sites[key] ?? sites.resolve(text) ?? key)

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
