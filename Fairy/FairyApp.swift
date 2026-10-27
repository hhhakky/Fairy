//
//  FairyApp.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
//
import SwiftUI
import AppKit
import Combine
import Network

@main
struct FairyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage(Prefs.showMenuBarIcon) private var showMenuBarIcon = true

    init() { Prefs.registerDefaults() }

    var body: some Scene {
        MenuBarExtra("Fairy", systemImage: "sparkles", isInserted: $showMenuBarIcon) {
            CommandBar(core: delegate.core,
                       openSettings: delegate.openSettings,
                       demo: delegate.runDemo)
        }
        .menuBarExtraStyle(.window)
    }
}

struct CommandBar: View {
    let core: FairyCore
    let openSettings: () -> Void
    let demo: () -> Void

    @AppStorage(Prefs.accentHex) private var accentHex = Prefs.Default.accentHex
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: accentHex)).frame(width: 6, height: 6)
                Text("FAIRY")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: accentHex))
                TextField("Команда…", text: $text)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        let command = text
                        text = ""
                        Task { await core.handle(command) }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.07)))

            HStack(spacing: 6) {
                IconButton("gearshape", "Настройки", action: openSettings)
                IconButton("folder", "Папка навыков") { Storage.openSkillsFolder() }
                IconButton("play", "Демо", action: demo)
                Spacer()
                IconButton("power", "Выход") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 290)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let model = FairyModel()
    lazy var core = FairyCore(model: model)

    @Published var serverToken = ServerToken.loadOrCreate()
    @Published var serverStatus = "Выключен"

    private var panel: IslandPanel?
    private var server: CommandServer?
    private var serverPort: UInt16?
    private var settingsWindow: NSWindow?
    private var previewToken = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = IslandPanel(model: model)
        applySettings()

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applySettings() }
        }
    }

    /// Повторный запуск приложения (например, из Spotlight) открывает настройки
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    // MARK: - Окно настроек

    func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 580),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.appearance = NSAppearance(named: .darkAqua)
            w.backgroundColor = NSColor(red: 0.04, green: 0.045, blue: 0.065, alpha: 1)
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(app: self))
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func applySettings() {
        if UserDefaults.standard.bool(forKey: Prefs.showIsland) {
            panel?.show()
        } else {
            panel?.orderOut(nil)
        }
        syncServer()
    }

    // MARK: - Сервер

    private func syncServer() {
        let d = UserDefaults.standard
        let port = d.integer(forKey: Prefs.serverPort)
        let wanted: UInt16? = (d.bool(forKey: Prefs.serverEnabled) && (1024...65535).contains(port))
            ? UInt16(port) : nil

        guard wanted != serverPort else { return }

        server?.stop()
        server = nil
        serverPort = nil

        guard let port = wanted else {
            serverStatus = "Выключен"
            return
        }

        let s = CommandServer(token: serverToken) { [weak self] text in
            Task { @MainActor in await self?.core.handle(text) }
        }
        do {
            try s.start(port: port) { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.serverStatus = "Работает, порт \(port)"
                    case .failed(_):
                        self?.serverStatus = "Ошибка (порт \(port) занят?)"
                    default:
                        break
                    }
                }
            }
            server = s
            serverPort = port
            serverStatus = "Запускаю…"
        } catch {
            serverStatus = "Ошибка запуска"
        }
    }

    func regenerateToken() {
        Keychain.delete(account: "server-token")
        serverToken = ServerToken.loadOrCreate()
        server?.stop()
        server = nil
        serverPort = nil
        syncServer()
    }

    // MARK: - Демо и предпросмотр

    func preview(_ status: FairyStatus) {
        previewToken += 1
        let mine = previewToken
        model.status = status
        Task {
            try? await Task.sleep(for: .seconds(3))
            if previewToken == mine { model.status = .idle }
        }
    }

    func runDemo() {
        Task {
            model.status = .listening
            try? await Task.sleep(for: .seconds(1.5))
            model.status = .thinking
            try? await Task.sleep(for: .seconds(1.5))
            model.status = .executing("open -a Ghostty", icon: nil)
            try? await Task.sleep(for: .seconds(2))
            model.status = .idle
        }
    }
}
