//
//  FairyApp.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
//
import SwiftUI
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
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Команда для феи…", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let command = text
                    text = ""
                    Task { await core.handle(command) }
                }
            HStack {
                Button("Настройки…", action: openSettings)
                Button("Демо", action: demo)
                Spacer()
                Button("Выход") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 280)
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
    private var serverPort: UInt16?          // порт, на котором сервер запущен (или пытался)
    private var settingsWindow: NSWindow?

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

    // MARK: - Настройки

    func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 640),
                             styleMask: [.titled, .closable, .miniaturizable],
                             backing: .buffered, defer: false)
            w.title = "Fairy: настройки"
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

    // MARK: - Демо

    func runDemo() {
        Task {
            model.status = .listening
            try? await Task.sleep(for: .seconds(1.5))
            model.status = .thinking
            try? await Task.sleep(for: .seconds(1.5))
            model.status = .executing("open -a Ghostty")
            try? await Task.sleep(for: .seconds(2))
            model.status = .idle
        }
    }
}
