//
//  SettingsView.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var app: AppDelegate

    @AppStorage(Prefs.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Prefs.showIsland) private var showIsland = true
    @AppStorage(Prefs.llmModel) private var llmModel = Prefs.defaultModel
    @AppStorage(Prefs.serverEnabled) private var serverEnabled = true
    @AppStorage(Prefs.serverPort) private var serverPort = 8765

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var newKey = ""
    @State private var hasKey = Keychain.load(account: "groq") != nil
    @State private var keyCheck = ""
    @State private var portText = ""
    @State private var tokenVisible = false
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Основное") {
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }

                Toggle("Иконка в меню-баре", isOn: $showMenuBarIcon)
                if !showMenuBarIcon {
                    Text("Чтобы вернуть иконку или открыть настройки, запусти Fairy ещё раз (Spotlight или Finder).")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Toggle("Остров сверху экрана", isOn: $showIsland)
            }

            Section("Нейросеть (Groq)") {
                HStack {
                    Text("Ключ")
                    Spacer()
                    Text(hasKey ? "сохранён ✓" : "не задан")
                        .foregroundStyle(hasKey ? .green : .secondary)
                }
                SecureField("Вставь новый ключ gsk_…", text: $newKey)
                HStack {
                    Button("Сохранить") {
                        let k = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !k.isEmpty else { return }
                        Keychain.save(k, account: "groq")
                        newKey = ""
                        hasKey = true
                        keyCheck = ""
                    }
                    .disabled(newKey.isEmpty)
                    Button("Проверить", action: checkKey).disabled(!hasKey)
                    Button("Удалить", role: .destructive) {
                        Keychain.delete(account: "groq")
                        hasKey = false
                        keyCheck = ""
                    }
                    .disabled(!hasKey)
                    Spacer()
                    Text(keyCheck).font(.caption).foregroundStyle(.secondary)
                }
                TextField("Модель", text: $llmModel)
                Button("Вернуть модель по умолчанию") { llmModel = Prefs.defaultModel }
                    .disabled(llmModel == Prefs.defaultModel)
            }

            Section("Управление с iPhone") {
                Toggle("Сервер включён", isOn: $serverEnabled)
                LabeledContent("Статус", value: app.serverStatus)
                HStack {
                    TextField("Порт", text: $portText)
                        .frame(width: 80)
                    Button("Применить") {
                        if let p = Int(portText), (1024...65535).contains(p) {
                            serverPort = p
                        } else {
                            portText = String(serverPort)
                        }
                    }
                    .disabled(portText == String(serverPort))
                }

                Text(tokenVisible ? app.serverToken : String(repeating: "•", count: 32))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)
                HStack {
                    Button(tokenVisible ? "Скрыть токен" : "Показать токен") { tokenVisible.toggle() }
                    Button("Копировать") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(app.serverToken, forType: .string)
                    }
                    Button("Сбросить…", role: .destructive) { confirmReset = true }
                }
                .confirmationDialog("Сбросить токен?", isPresented: $confirmReset) {
                    Button("Сбросить", role: .destructive) { app.regenerateToken() }
                } message: {
                    Text("Шорткат на iPhone придётся обновить новым токеном.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 640)
        .onAppear { portText = String(serverPort) }
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
