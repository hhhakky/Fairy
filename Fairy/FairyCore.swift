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
    private let store = SkillStore()
    private let llm = LLMRouter()
    private let runner = SkillRunner()

    /// Команды из меню и с iPhone не пересекаются: следующая ждёт конца предыдущей.
    private var pipeline: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?

    init(model: FairyModel) {
        self.model = model
        self.catalog = AppCatalog()
        Storage.seedIfNeeded()
        store.reloadIfNeeded()
    }

    func handle(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let previous = pipeline
        let task = Task { @MainActor in
            await previous?.value
            await self.process(clean)
        }
        pipeline = task
        await task.value
    }

    private func process(_ clean: String) async {
        hideTask?.cancel()

        catalog.reloadIfNeeded()

        // Подхватываем правки в файлах навыков (без перезапуска)
        if store.reloadIfNeeded(), let first = store.errors.first {
            flash(.error("Ошибка навыка: \(first.prefix(50))"), for: 4)
        }

        let resolver = ParamResolver(catalog: catalog, aliases: store.aliases)

        // 1. Локальный путь: мгновенно, без сети и токенов
        let router = SkillRouter(skills: store.skills, resolver: resolver)
        if let inv = router.route(clean) {
            await execute(inv)
            return
        }

        // 2. Нейросеть выбирает навык из списка
        guard let key = Keychain.load(account: "groq") else {
            flash(.error("Не поняла (нет ключа Groq)"), for: 2.5)
            return
        }

        model.status = .thinking
        do {
            let reply = try await llm.route(clean, apiKey: key, skills: store.skills,
                                            catalog: catalog, aliases: store.aliases)
            guard let inv = resolver.invocation(from: reply, skills: store.skills) else {
                flash(.error("Не поняла: \(clean.prefix(30))"), for: 2)
                return
            }
            await execute(inv)
        } catch let error as LLMRouter.LLMError {
            flash(.error(error.message), for: 2.5)
        } catch let error as URLError {
            print("URLError:", error.code.rawValue, error.localizedDescription)
            flash(.error("Сеть: \(error.code.rawValue)"), for: 4)
        } catch {
            flash(.error("Ошибка ответа"), for: 2.5)
        }
    }

    private func execute(_ inv: Invocation) async {
        // Подтверждения мы ещё не сделали, поэтому такие навыки не запускаем
        if inv.skill.confirm == true {
            flash(.error("Нужно подтверждение (скоро)"), for: 2.5)
            return
        }
        let shown = runner.displayText(for: inv)
        model.status = .executing(shown)
        do {
            try await runner.run(inv)
            flash(.executing(shown), for: 1.2)
        } catch let error as SkillRunner.RunError {
            print("Run error:", error.message)
            let brief = error.message.split(whereSeparator: \.isNewline).first.map(String.init) ?? error.message
            flash(.error(brief.isEmpty ? "Ошибка команды" : String(brief.prefix(60))), for: 2.5)
        } catch {
            flash(.error("Ошибка команды"), for: 2)
        }
    }

    private func flash(_ status: FairyStatus, for seconds: Double) {
        hideTask?.cancel()
        model.status = status
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            if model.status == status {
                model.status = .idle
            }
        }
    }
}
