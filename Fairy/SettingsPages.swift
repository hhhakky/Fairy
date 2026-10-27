//
//  SettingsPages.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import SwiftUI
import AppKit
import Combine

// MARK: - Остров

struct IslandPage: View {
    @ObservedObject var app: AppDelegate

    @AppStorage(Prefs.islandStyle) private var style = Prefs.Default.style
    @AppStorage(Prefs.accentHex) private var accentHex = Prefs.Default.accentHex
    @AppStorage(Prefs.cornerRadius) private var cornerRadius = Prefs.Default.cornerRadius
    @AppStorage(Prefs.fontSize) private var fontSize = Prefs.Default.fontSize
    @AppStorage(Prefs.fontDesign) private var fontDesign = Prefs.Default.fontDesign
    @AppStorage(Prefs.islandMaxWidth) private var maxWidth = Prefs.Default.maxWidth
    @AppStorage(Prefs.showIcon) private var showIcon = Prefs.Default.showIcon
    @AppStorage(Prefs.stateColors) private var stateColors = Prefs.Default.stateColors
    @AppStorage(Prefs.glow) private var glow = Prefs.Default.glow
    @AppStorage(Prefs.borderAlpha) private var borderAlpha = Prefs.Default.borderAlpha
    @AppStorage(Prefs.islandAlpha) private var alpha = Prefs.Default.alpha
    @AppStorage(Prefs.topOffset) private var topOffset = Prefs.Default.topOffset
    @AppStorage(Prefs.animSpeed) private var animSpeed = Prefs.Default.animSpeed
    @AppStorage(Prefs.animBounce) private var animBounce = Prefs.Default.bounce
    @AppStorage(Prefs.holdFactor) private var holdFactor = Prefs.Default.holdFactor

    @State private var sample = 2

    private let samples: [(String, FairyStatus)] = [
        ("Слушаю", .listening),
        ("Думаю", .thinking),
        ("Команда", .executing("open -a Ghostty", icon: nil)),
        ("Результат", .result("☁️ +5°C ↘5km/h", icon: "cloud.sun")),
        ("Ошибка", .error("Не поняла: abc"))
    ]

    private let swatches = ["#7DF9FF", "#5BFF9D", "#B388FF", "#FF9F43", "#FF5FA2", "#FFFFFF"]

    private var accentBinding: Binding<Color> {
        Binding(get: { Color(hex: accentHex) }, set: { accentHex = $0.toHex() })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle("Остров", "Внешний вид и поведение пилюли")

            Card("Предпросмотр") {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.07)],
                                             startPoint: .top, endPoint: .bottom))
                    IslandPill(status: samples[sample].1)
                        .padding(.horizontal, 12)
                }
                .frame(height: 96)

                HStack(spacing: 6) {
                    ForEach(samples.indices, id: \.self) { i in
                        Button { sample = i } label: {
                            Text(samples[i].0)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(sample == i
                                    ? Color(hex: accentHex).opacity(0.22) : Color.white.opacity(0.06)))
                                .foregroundStyle(sample == i ? Color(hex: accentHex) : UI.text)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    ActionButton("Показать на экране") { app.preview(samples[sample].1) }
                }
            }

            Card("Стиль") {
                Row("Фон") {
                    Picker("", selection: $style) {
                        Text("Чёрный").tag("solid")
                        Text("Графит").tag("graphite")
                        Text("Неон").tag("tinted")
                        Text("Стекло").tag("glass")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                }
                Row("Акцентный цвет") {
                    HStack(spacing: 8) {
                        ForEach(swatches, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 18, height: 18)
                                .overlay(Circle().stroke(
                                    Color.white.opacity(accentHex.uppercased() == hex ? 0.9 : 0.15),
                                    lineWidth: 1.5))
                                .onTapGesture { accentHex = hex }
                        }
                        ColorPicker("", selection: accentBinding, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
                SwitchRow("Цвета состояний", subtitle: "Жёлтый при «думаю», красный при ошибке", isOn: $stateColors)
                SwitchRow("Иконка", isOn: $showIcon)
            }

            Card("Форма и текст") {
                SliderRow(title: "Скругление", value: $cornerRadius, range: 6...26)
                SliderRow(title: "Размер шрифта", value: $fontSize, range: 11...18)
                Row("Шрифт") {
                    Picker("", selection: $fontDesign) {
                        Text("Округлый").tag("rounded")
                        Text("Обычный").tag("default")
                        Text("Моно").tag("mono")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                }
                SliderRow(title: "Максимальная ширина", value: $maxWidth, range: 240...600)
            }

            Card("Эффекты") {
                SliderRow(title: "Свечение", value: $glow, range: 0...1, format: "%.1f")
                SliderRow(title: "Обводка", value: $borderAlpha, range: 0...0.6, format: "%.2f")
                SliderRow(title: "Прозрачность", value: $alpha, range: 0.5...1, format: "%.2f")
            }

            Card("Положение и анимация") {
                SliderRow(title: "Отступ от верха экрана", value: $topOffset, range: 0...40)
                SliderRow(title: "Скорость анимации (сек)", value: $animSpeed, range: 0.1...0.8, format: "%.2f")
                SliderRow(title: "Упругость", value: $animBounce, range: 0...0.5, format: "%.2f")
                SliderRow(title: "Время показа результата", value: $holdFactor, range: 0.5...3, format: "%.1f×")
            }

            HStack {
                Spacer()
                ActionButton("Сбросить оформление", destructive: true) { Prefs.resetAppearance() }
            }
        }
    }
}

// MARK: - Нейросеть

struct AIPage: View {
    @AppStorage(Prefs.llmModel) private var llmModel = Prefs.defaultModel
    @AppStorage(Prefs.llmEnabled) private var llmEnabled = true
    @AppStorage(Prefs.llmTimeout) private var llmTimeout = 10.0

    @State private var newKey = ""
    @State private var hasKey = Keychain.load(account: "groq") != nil
    @State private var keyCheck = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle("Нейросеть", "Groq понимает команды, которые не разобрали локальные правила")

            Card("Ключ Groq") {
                Row("Статус") {
                    Text(hasKey ? "сохранён ✓" : "не задан")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(hasKey ? Color.green : UI.dim)
                }
                SecureField("Вставь новый ключ gsk_…", text: $newKey).fieldStyle()
                HStack(spacing: 8) {
                    ActionButton("Сохранить") {
                        let k = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !k.isEmpty else { return }
                        Keychain.save(k, account: "groq")
                        newKey = ""
                        hasKey = true
                        keyCheck = ""
                    }
                    .disabled(newKey.isEmpty)
                    ActionButton("Проверить", action: checkKey).disabled(!hasKey)
                    ActionButton("Удалить", destructive: true) {
                        Keychain.delete(account: "groq")
                        hasKey = false
                        keyCheck = ""
                    }
                    .disabled(!hasKey)
                    Text(keyCheck).font(.system(size: 11)).foregroundStyle(UI.dim)
                }
            }

            Card("Модель") {
                TextField("Модель", text: $llmModel).fieldStyle()
                HStack(spacing: 8) {
                    ActionButton("gpt-oss-20b") { llmModel = "openai/gpt-oss-20b" }
                    ActionButton("gpt-oss-120b") { llmModel = "openai/gpt-oss-120b" }
                    ActionButton("По умолчанию") { llmModel = Prefs.defaultModel }
                        .disabled(llmModel == Prefs.defaultModel)
                }
                Text("Если приходит ошибка 404, модель, скорее всего, закрыли. Актуальный список есть в консоли Groq.")
                    .font(.system(size: 11)).foregroundStyle(UI.dim)
            }

            Card("Поведение") {
                SwitchRow("Использовать нейросеть",
                          subtitle: "Только если локальные правила команду не поняли",
                          isOn: $llmEnabled)
                SliderRow(title: "Таймаут запроса (сек)", value: $llmTimeout, range: 5...30)
            }
        }
    }

    private func checkKey() {
        guard let key = Keychain.load(account: "groq") else { keyCheck = "Ключа нет"; return }
        keyCheck = "Проверяю…"
        Task { @MainActor in
            var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
            req.timeoutInterval = 10
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                switch code {
                case 200: keyCheck = "Ключ работает ✓"
                case 401: keyCheck = "Неверный ключ"
                default:  keyCheck = "Ошибка \(code)"
                }
            } catch {
                keyCheck = "Нет связи"
            }
        }
    }
}

// MARK: - Навыки

struct SkillsPage: View {
    @ObservedObject var app: AppDelegate
    @State private var skills: [Skill] = []
    @State private var errors: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle("Навыки", "Команды, которые умеет Фея. Файлы лежат в папке навыков")

            Card("Управление") {
                HStack(spacing: 8) {
                    ActionButton("Навыки") { Storage.openSkillsFolder() }
                    ActionButton("Скрипты") { Storage.openScriptsFolder() }
                    ActionButton("Новый") {
                        if let url = Storage.createSkillTemplate() { NSWorkspace.shared.open(url) }
                        reload()
                    }
                    ActionButton("Обновить", action: reload)
                    ActionButton("Стандартные") { Storage.restoreDefaults(); reload() }
                }
                Text("«Новый» создаёт файл-шаблон и открывает его. «Стандартные» дописывает только удалённые стандартные навыки, твои правки не трогает.")
                    .font(.system(size: 11)).foregroundStyle(UI.dim)
            }

            if !errors.isEmpty {
                Card("Ошибки в файлах") {
                    ForEach(errors, id: \.self) { e in
                        Text(e)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.red)
                    }
                }
            }

            Card("Загружено: \(skills.count)") {
                ForEach(skills, id: \.id) { s in
                    HStack(spacing: 10) {
                        Image(systemName: symbol(for: s))
                            .frame(width: 22)
                            .foregroundStyle(UI.dim)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.id).font(.system(size: 12, weight: .medium, design: .monospaced))
                            Text(s.description)
                                .font(.system(size: 11)).foregroundStyle(UI.dim).lineLimit(1)
                        }
                        Spacer()
                        Text("\(s.triggers?.count ?? 0) фраз")
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(UI.dim)
                        if s.output == .show {
                            Text("вывод")
                                .font(.system(size: 10, design: .monospaced))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        let info = app.core.skillsInfo()
        skills = info.skills
        errors = info.errors
    }

    private func symbol(for s: Skill) -> String {
        if let n = s.display?.icon,
           NSImage(systemSymbolName: n, accessibilityDescription: nil) != nil { return n }
        return "terminal"
    }
}

// MARK: - iPhone

struct PhonePage: View {
    @ObservedObject var app: AppDelegate

    @AppStorage(Prefs.serverEnabled) private var serverEnabled = true
    @AppStorage(Prefs.serverPort) private var serverPort = 8765

    @State private var portText = ""
    @State private var tokenVisible = false
    @State private var confirmReset = false

    private var hostName: String { Host.current().localizedName ?? "mac" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle("iPhone", "Управление Фей с телефона через шорткат")

            Card("Сервер") {
                SwitchRow("Сервер включён", isOn: $serverEnabled)
                Row("Статус") {
                    Text(app.serverStatus).font(.system(size: 12, design: .monospaced)).foregroundStyle(UI.dim)
                }
                Row("Порт") {
                    HStack(spacing: 8) {
                        TextField("Порт", text: $portText).fieldStyle().frame(width: 90)
                        ActionButton("Применить") {
                            if let p = Int(portText), (1024...65535).contains(p) {
                                serverPort = p
                            } else {
                                portText = String(serverPort)
                            }
                        }
                        .disabled(portText == String(serverPort))
                    }
                }
            }

            Card("Токен доступа") {
                Text(tokenVisible ? app.serverToken : String(repeating: "•", count: 32))
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    ActionButton(tokenVisible ? "Скрыть" : "Показать") { tokenVisible.toggle() }
                    ActionButton("Копировать") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(app.serverToken, forType: .string)
                    }
                    ActionButton("Сбросить…", destructive: true) { confirmReset = true }
                }
                .confirmationDialog("Сбросить токен?", isPresented: $confirmReset) {
                    Button("Сбросить", role: .destructive) { app.regenerateToken() }
                } message: {
                    Text("Шорткат на iPhone придётся обновить новым токеном.")
                }
            }

            Card("Шорткат") {
                Text("http://<имя-в-Tailscale>:\(String(serverPort))/command")
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                Text("Метод POST, заголовок Authorization: Bearer <токен>, тело JSON с полем text. Имя этого Mac: \(hostName). Адрес в Tailscale может отличаться, посмотри его в приложении Tailscale.")
                    .font(.system(size: 11)).foregroundStyle(UI.dim)
            }
        }
        .onAppear { portText = String(serverPort) }
    }
}
