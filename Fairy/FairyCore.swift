//
//  FairyCore.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
//
import Foundation

@MainActor
final class FairyCore {
    private let model: FairyModel
    private let catalog: AppCatalog
    private let router: LocalRouter
    private let llm = LLMRouter()
    private let executor = Executor()

    init(model: FairyModel) {
        self.model = model
        let catalog = AppCatalog()
        self.catalog = catalog
        self.router = LocalRouter(catalog: catalog)
    }

    func handle(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // 1. Быстрый локальный путь: без сети и без токенов
        if let action = router.route(clean) {
            await execute(action)
            return
        }

        // 2. Запасной путь: нейросеть
        guard let key = Keychain.load(account: "groq") else {
            await show(.error("Не поняла (нет ключа Groq)"), for: 2.5)
            return
        }

        model.status = .thinking
        do {
            let reply = try await llm.route(clean, apiKey: key, catalog: catalog)
            guard let action = FairyAction(reply: reply, catalog: catalog) else {
                await show(.error("Не поняла: \(clean.prefix(30))"), for: 2)
                return
            }
            await execute(action)
        } catch let error as LLMRouter.LLMError {
            await show(.error(error.message), for: 2.5)
        } catch let error as URLError {
            print("URLError:", error.code.rawValue, error.localizedDescription)
            await show(.error("Сеть: \(error.code.rawValue)"), for: 4)
        } catch {
            await show(.error("Ошибка ответа"), for: 2.5)
        }
    }

    private func execute(_ action: FairyAction) async {
        model.status = .executing(action.display)
        do {
            try await executor.run(action)
            await show(.executing(action.display), for: 1.2)
        } catch {
            await show(.error("Ошибка команды"), for: 2)
        }
    }

    private func show(_ status: FairyStatus, for seconds: Double) async {
        model.status = status
        try? await Task.sleep(for: .seconds(seconds))
        model.status = .idle
    }
}
