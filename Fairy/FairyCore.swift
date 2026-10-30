//
//  FairyCore.swift
//  Fairy
//
import Foundation

@MainActor
final class FairyCore {
    private let model: FairyModel
    private let catalog: AppCatalog
    private let sites: SiteCatalog
    private let store = SkillStore()
    private let llm = LLMRouter()
    private let runner = SkillRunner()

    /// Команды из разных источников выполняются по очереди.
    private var pipeline: Task<Void, Never>?
    private var pending = 0
    private let maxPending = 5
    private var hideTask: Task<Void, Never>?
    private var token = 0   // Защита от устаревших таймеров статуса.

    init(model: FairyModel) {
        self.model = model
        self.catalog = AppCatalog()
        self.sites = SiteCatalog()
        Storage.seedIfNeeded()
        store.reloadIfNeeded()
    }

    func skillsInfo() -> (skills: [Skill], errors: [String]) {
        store.reloadIfNeeded()
        return (store.skills, store.errors)
    }

    func siteInfo() -> (count: Int, readable: Bool) {
        sites.reloadIfNeeded()
        return (sites.count, sites.isReadable)
    }

    func appInfo() -> (total: Int, localized: Int) {
        catalog.reloadIfNeeded()
        return (catalog.entries.count, catalog.localizedCount)
    }

    func handle(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // Очередь не должна расти бесконечно: каждая команда может ждать нейросеть
        guard pending < maxPending else {
            flash(.error("Слишком много команд подряд"), for: 2)
            return
        }
        pending += 1
        defer { pending -= 1 }

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
        hideTask = nil
        catalog.reloadIfNeeded()
        sites.reloadIfNeeded()

        // Подхватываем правки в файлах навыков без перезапуска.
        if store.reloadIfNeeded(), let first = store.errors.first {
            flash(.error("Ошибка навыка: \(first.prefix(50))"), for: 4)
        }

        let resolver = ParamResolver(catalog: catalog, sites: sites, aliases: store.aliases)

        // Локальный путь остаётся мгновенным и не расходует сетевые запросы.
        let router = SkillRouter(skills: store.skills, resolver: resolver)
        if let invocations = router.routeSequence(clean) {
            await runChain(invocations)
            return
        }

        guard UserDefaults.standard.bool(forKey: Prefs.llmEnabled) else {
            flash(.error("Не поняла: \(clean.prefix(30))"), for: 2)
            return
        }
        guard let key = Keychain.load(account: "groq") else {
            flash(.error("Не поняла (нет ключа Groq)"), for: 2.5)
            return
        }

        set(.thinking)
        do {
            let reply = try await llm.route(
                clean,
                apiKey: key,
                skills: store.skills,
                catalog: catalog,
                aliases: store.aliases
            )
            guard let invocations = resolver.invocations(from: reply, skills: store.skills) else {
                flash(.error("Не поняла: \(clean.prefix(30))"), for: 2)
                return
            }
            await runChain(invocations)
        } catch let error as LLMRouter.LLMError {
            flash(.error(error.message), for: 2.5)
        } catch let error as URLError {
            print("URLError:", error.code.rawValue, error.localizedDescription)
            flash(.error("Сеть: \(error.code.rawValue)"), for: 4)
        } catch {
            flash(.error("Ошибка ответа"), for: 2.5)
        }
    }

    /// Выполняет команды по порядку; если шаг не удался, остальные пропускаются.
    private func runChain(_ invocations: [Invocation]) async {
        for (index, invocation) in invocations.enumerated() {
            guard await execute(invocation) else { return }
            if index < invocations.count - 1 {
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    /// true, если навык выполнился без ошибки
    @discardableResult
    private func execute(_ invocation: Invocation) async -> Bool {
        // Навыки с побочными эффектами требуют подтверждения, пока не появится UI подтверждения.
        if invocation.skill.confirm == true {
            flash(.error("Нужно подтверждение (скоро)"), for: 2.5)
            return false
        }

        let shown = runner.displayText(for: invocation)
        let icon = invocation.skill.display?.icon
        set(.executing(shown, icon: icon))

        do {
            let raw = try await runner.run(invocation)
            let output = SkillRunner.clean(raw)
            if invocation.skill.output == .show, !output.isEmpty {
                flash(.result(output, icon: icon), for: holdTime(for: output))
            } else {
                flash(.executing(shown, icon: icon), for: 1.2)
            }
            return true
        } catch let error as SkillRunner.RunError {
            print("Run error:", error.message)
            let line = error.message.components(separatedBy: .newlines).first ?? ""
            flash(.error("Ошибка: \(line.prefix(60))"), for: 3)
            return false
        } catch {
            flash(.error("Ошибка команды"), for: 2)
            return false
        }
    }

    /// Чем длиннее результат, тем дольше он отображается: от 3 до 10 секунд.
    private func holdTime(for text: String) -> Double {
        let factor = UserDefaults.standard.double(forKey: Prefs.holdFactor)
        let base = min(10, max(3, 2 + Double(text.count) * 0.07))
        return base * (factor > 0 ? factor : 1)
    }

    private func set(_ status: FairyStatus) {
        token += 1
        model.status = status
    }

    private func flash(_ status: FairyStatus, for seconds: Double) {
        hideTask?.cancel()
        set(status)
        let currentToken = token
        hideTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            guard !Task.isCancelled, token == currentToken else { return }
            model.status = .idle
            hideTask = nil
        }
    }
}
