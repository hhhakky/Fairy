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
    private var token = 0   // защита от старых таймеров: новая команда отменяет «возврат в idle»

    init(model: FairyModel) {
        self.model = model
        self.catalog = AppCatalog()
        Storage.seedIfNeeded()
        store.reloadIfNeeded()
    }
    
    func skillsInfo() -> (skills: [Skill], errors: [String]) {
        store.reloadIfNeeded()
        return (store.skills, store.errors)
    }

    func handle(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // Подхватываем правки в файлах навыков (без перезапуска)
        if store.reloadIfNeeded(), let first = store.errors.first {
            await show(.error("Ошибка навыка: \(first.prefix(50))"), for: 4)
        }

        let resolver = ParamResolver(catalog: catalog, aliases: store.aliases)

        // 1. Локальный путь: мгновенно, без сети и токенов
        let router = SkillRouter(skills: store.skills, resolver: resolver)
        if let inv = router.route(clean) {
            await execute(inv)
            return
        }
        guard UserDefaults.standard.bool(forKey: Prefs.llmEnabled) else {
            await show(.error("Не поняла: \(clean.prefix(30))"), for: 2)
            return
        }
        // 2. Нейросеть выбирает навык из списка
        guard let key = Keychain.load(account: "groq") else {
            await show(.error("Не поняла (нет ключа Groq)"), for: 2.5)
            return
        }

        set(.thinking)
        do {
            let reply = try await llm.route(clean, apiKey: key, skills: store.skills,
                                            catalog: catalog, aliases: store.aliases)
            guard let inv = resolver.invocation(from: reply, skills: store.skills) else {
                await show(.error("Не поняла: \(clean.prefix(30))"), for: 2)
                return
            }
            await execute(inv)
        } catch let error as LLMRouter.LLMError {
            await show(.error(error.message), for: 2.5)
        } catch let error as URLError {
            print("URLError:", error.code.rawValue, error.localizedDescription)
            await show(.error("Сеть: \(error.code.rawValue)"), for: 4)
        } catch {
            await show(.error("Ошибка ответа"), for: 2.5)
        }
    }

    private func execute(_ inv: Invocation) async {
        // Подтверждения мы ещё не сделали, поэтому такие навыки не запускаем
        if inv.skill.confirm == true {
            await show(.error("Нужно подтверждение (скоро)"), for: 2.5)
            return
        }

        let shown = runner.displayText(for: inv)
        let icon = inv.skill.display?.icon
        set(.executing(shown, icon: icon))

        do {
            let raw = try await runner.run(inv)
            let output = SkillRunner.clean(raw)

            if inv.skill.output == .show, !output.isEmpty {
                await show(.result(output, icon: icon), for: holdTime(for: output))
            } else {
                await show(.executing(shown, icon: icon), for: 1.2)
            }
        } catch let error as SkillRunner.RunError {
            print("Run error:", error.message)
            let line = error.message.components(separatedBy: .newlines).first ?? ""
            await show(.error("Ошибка: \(line.prefix(60))"), for: 3)
        } catch {
            await show(.error("Ошибка команды"), for: 2)
        }
    }

    /// Чем длиннее текст, тем дольше он висит: от 3 до 10 секунд
    private func holdTime(for text: String) -> Double {
        let factor = UserDefaults.standard.double(forKey: Prefs.holdFactor)
        let base = min(10, max(3, 2 + Double(text.count) * 0.07))
        return base * (factor > 0 ? factor : 1)
    }

    private func set(_ status: FairyStatus) {
        token += 1
        model.status = status
    }

    private func show(_ status: FairyStatus, for seconds: Double) async {
        set(status)
        let mine = token
        try? await Task.sleep(for: .seconds(seconds))
        if token == mine { model.status = .idle }
    }
}
