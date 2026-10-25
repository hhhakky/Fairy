//
//  LLMRouter.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
//
import Foundation

struct LLMRouter {
    struct LLMError: Error { let message: String }
    
    /// То, что должна вернуть нейросеть
    struct Reply: Decodable {
        let action: String
        let target: String?
        let value: Int?
    }
    
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    //    private let model = "openai/gpt-oss-20b"
    private var model: String {
        let m = UserDefaults.standard.string(forKey: Prefs.llmModel)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return m.isEmpty ? Prefs.defaultModel : m
    }
    
    //    private let systemPrompt = """
    //    You convert a voice command (Russian or English) into JSON for a macOS assistant.
    //    Reply with JSON only: {"action": "open_app"|"quit_app"|"set_volume"|"mute"|"unmute"|"unknown", "target": string|null, "value": integer|null}
    //    open_app/quit_app: target = the app name as the user said it. set_volume: value is 0-100.
    //    If the command is not clearly one of these actions, or is gibberish, use "unknown".
    //    """
    //
    //    func route(_ text: String, apiKey: String) async throws -> Reply {
    //        var req = URLRequest(url: endpoint)
    //        req.httpMethod = "POST"
    //        req.timeoutInterval = 10
    //        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    //        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    //
    //        let body: [String: Any] = [
    //            "model": model,
    //            "temperature": 0,
    //            "max_tokens": 500,
    //            "reasoning_effort": "low",
    //            "response_format": ["type": "json_object"],
    //            "messages": [
    //                ["role": "system", "content": systemPrompt],
    //                ["role": "user", "content": text]
    //            ]
    //        ]
    //        req.httpBody = try JSONSerialization.data(withJSONObject: body)
    //
    //        let (data, response) = try await URLSession.shared.data(for: req)
    //        guard let http = response as? HTTPURLResponse else {
    //            throw LLMError(message: "Нет ответа")
    //        }
    //        guard http.statusCode == 200 else {
    //            switch http.statusCode {
    //            case 401: throw LLMError(message: "Неверный ключ")
    //            case 429: throw LLMError(message: "Лимит запросов")
    //            default:  throw LLMError(message: "Ошибка API \(http.statusCode)")
    //            }
    //        }
    //
    //        struct Envelope: Decodable {
    //            struct Choice: Decodable {
    //                struct Message: Decodable { let content: String }
    //                let message: Message
    //            }
    //            let choices: [Choice]
    //        }
    //        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
    //        guard let content = envelope.choices.first?.message.content.data(using: .utf8) else {
    //            throw LLMError(message: "Пустой ответ")
    //        }
    //        return try JSONDecoder().decode(Reply.self, from: content)
    //    }
    //}
    private func makePrompt(_ catalog: AppCatalog) -> String {
        let apps = catalog.entries.map(\.file).joined(separator: ", ")
        let aliases = catalog.aliases
            .map { "\($0.key) = \($0.value)" }
            .joined(separator: "; ")
        
        return """
        You convert a voice command (Russian or English) into JSON for a macOS assistant.
        Reply with JSON only: {"action": "open_app"|"quit_app"|"set_volume"|"mute"|"unmute"|"unknown", "target": string|null, "value": integer|null}
        set_volume: value is 0-100.
        For open_app and quit_app, "target" MUST be copied exactly from the installed apps list below. \
        Pick the best match by meaning (for example "command line" or "console" means a terminal app). \
        If no installed app fits, or the command is not one of these actions, or it is gibberish, use "unknown".
        User aliases (the user's preferred apps): \(aliases)
        Installed apps: \(apps)
        """
    }
    
    func route(_ text: String, apiKey: String, catalog: AppCatalog) async throws -> Reply {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "max_tokens": 500,
            "reasoning_effort": "low",
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": makePrompt(catalog)],
                ["role": "user", "content": text]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError(message: "Нет ответа")
        }
        guard http.statusCode == 200 else {
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
        print("LLM reply:", String(decoding: content, as: UTF8.self))   // для отладки
        return try JSONDecoder().decode(Reply.self, from: content)
    }
}
    
// Проверка ответа нейросети: превращаем в действие, только если всё сходится
extension FairyAction {
    init?(reply: LLMRouter.Reply, catalog: AppCatalog) {
        switch reply.action {
        case "open_app":
            guard let t = reply.target, let app = catalog.resolve(t) else { return nil }
            self = .openApp(app)
        case "quit_app":
            guard let t = reply.target, let app = catalog.resolve(t) else { return nil }
            self = .quitApp(app)
        case "set_volume":
            guard let v = reply.value, (0...100).contains(v) else { return nil }
            self = .setVolume(v)
        case "mute":   self = .mute(true)
        case "unmute": self = .mute(false)
        default:       return nil
        }
    }
}
