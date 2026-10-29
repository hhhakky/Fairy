//
//  LLMRouter.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
//
import Foundation

struct LLMRouter {
    struct LLMError: Error { let message: String }

    /// Значение аргумента может прийти строкой или числом
    struct FlexString: Decodable {
        let value: String
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) { value = s }
            else if let i = try? c.decode(Int.self) { value = String(i) }
            else if let d = try? c.decode(Double.self) {
                value = d == d.rounded() ? String(Int(d)) : String(d)
            } else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "bad arg")
            }
        }
    }

    struct Reply: Decodable {
        let skill: String
        let args: [String: FlexString]?
    }

    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

    private var model: String {
        let m = UserDefaults.standard.string(forKey: Prefs.llmModel)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return m.isEmpty ? Prefs.defaultModel : m
    }

    private func makePrompt(skills: [Skill], catalog: AppCatalog, aliases: Aliases) -> String {
        let types = Set(skills.flatMap { ($0.params ?? [:]).values.map(\.type) })

        let skillLines = skills.map { s -> String in
            let ps = (s.params ?? [:]).sorted { $0.key < $1.key }
                .map { "\($0.key):\($0.value.type.rawValue)" }.joined(separator: ", ")
            return "- \(s.id)(\(ps)): \(s.description)"
        }.joined(separator: "\n")

        var lines = [
            "You convert a voice command (Russian or English) into JSON for a macOS assistant.",
            #"Reply with JSON only: {"skill": "<skill id>" or "unknown", "args": {"<param>": "<value>"}}"#,
            "Available skills, as id(param:type): description",
            skillLines,
            "Rules:",
            #"- Pick a skill only if the command clearly asks for it. Otherwise, or if it is gibberish, reply {"skill":"unknown","args":{}}."#,
            "- Fill every param of the chosen skill.",
            "- text/query: plain text. int: a number."
        ]

        if types.contains(.app) {
            let pairs = aliases.apps.map { "\($0.key) = \($0.value)" }.joined(separator: "; ")
            lines.append("- app: copy a name exactly from the installed apps list, choosing by meaning (for example \"command line\" or \"console\" means a terminal app).")
            lines.append("App aliases: \(pairs)")
            lines.append("Installed apps: \(catalog.entries.map(\.file).joined(separator: ", "))")
        }
        if types.contains(.folder) {
            lines.append("- folder: a folder alias from the list, or a path starting with ~.")
            lines.append("Folder aliases: \(aliases.folders.keys.sorted().joined(separator: ", "))")
        }
        if types.contains(.url) {
            lines.append("- url: a site alias from the list, or a domain like example.com.")
            lines.append("Site aliases: \(aliases.sites.keys.sorted().joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    func route(_ text: String, apiKey: String, skills: [Skill],
               catalog: AppCatalog, aliases: Aliases) async throws -> Reply {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        let t = UserDefaults.standard.double(forKey: Prefs.llmTimeout)
        req.timeoutInterval = t > 0 ? t : 10
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "max_tokens": 500,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": makePrompt(skills: skills, catalog: catalog, aliases: aliases)],
                ["role": "user", "content": text]
            ]
        ]
        // reasoning_effort понимают только модели gpt-oss, на остальных он даёт ошибку 400
        if model.contains("gpt-oss") { body["reasoning_effort"] = "low" }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError(message: "Нет ответа")
        }
        guard http.statusCode == 200 else {
            print("Groq error \(http.statusCode):", String(decoding: data.prefix(300), as: UTF8.self))
            switch http.statusCode {
            case 401: throw LLMError(message: "Неверный ключ")
            case 429: throw LLMError(message: "Лимит запросов")
            default:  throw LLMError(message: "Ошибка API \(http.statusCode)")
            }
        }

        struct Envelope: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let content = envelope.choices.first?.message.content.data(using: .utf8) else {
            throw LLMError(message: "Пустой ответ")
        }
        print("LLM reply:", String(decoding: content, as: UTF8.self))
        return try JSONDecoder().decode(Reply.self, from: content)
    }
}
