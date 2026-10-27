//
//  SettingsView.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import SwiftUI
import AppKit
import Combine
import ServiceManagement

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, island, ai, skills, phone, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "Основное"
        case .island: return "Остров"
        case .ai: return "Нейросеть"
        case .skills: return "Навыки"
        case .phone: return "iPhone"
        case .about: return "О Фее"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .island: return "capsule"
        case .ai: return "cpu"
        case .skills: return "bolt"
        case .phone: return "iphone"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var app: AppDelegate
    @AppStorage(Prefs.accentHex) private var accentHex = Prefs.Default.accentHex
    @State private var tab: SettingsTab = .general

    private var accent: Color { Color(hex: accentHex) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(UI.stroke).frame(width: 1)
            ScrollView {
                page
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 800, height: 580)
        .background(
            ZStack {
                UI.bg
                RadialGradient(colors: [accent.opacity(0.10), Color.clear],
                               center: .topTrailing, startRadius: 0, endRadius: 440)
            }
            .ignoresSafeArea()
        )
        .foregroundStyle(UI.text)
        .tint(accent)
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle().fill(accent).frame(width: 7, height: 7)
                    .shadow(color: accent.opacity(0.8), radius: 4)
                Text("FAIRY")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(3)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 18)

            ForEach(SettingsTab.allCases) { t in
                Button { tab = t } label: {
                    HStack(spacing: 10) {
                        Image(systemName: t.symbol).frame(width: 18)
                        Text(t.title).font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tab == t ? accent.opacity(0.16) : Color.clear))
                    .foregroundStyle(tab == t ? accent : UI.text)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 40)
        .padding(.bottom, 16)
        .frame(width: 190)
    }

    @ViewBuilder private var page: some View {
        switch tab {
        case .general: GeneralPage()
        case .island: IslandPage(app: app)
        case .ai: AIPage()
        case .skills: SkillsPage(app: app)
        case .phone: PhonePage(app: app)
        case .about: AboutPage()
        }
    }
}

struct GeneralPage: View {
    @AppStorage(Prefs.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Prefs.showIsland) private var showIsland = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle("Основное", "Запуск и видимость")

            Card("Запуск") {
                SwitchRow("Запускать при входе в систему",
                          subtitle: "Надёжнее всего работает из папки «Программы»",
                          isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Card("Видимость") {
                SwitchRow("Иконка в меню-баре", isOn: $showMenuBarIcon)
                if !showMenuBarIcon {
                    Text("Чтобы вернуть иконку или открыть настройки, запусти Fairy ещё раз (Spotlight или Finder).")
                        .font(.system(size: 11)).foregroundStyle(UI.dim)
                }
                SwitchRow("Остров сверху экрана", isOn: $showIsland)
            }
        }
    }
}

struct AboutPage: View {
    @State private var confirmReset = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle("О Фее", "Версия \(version)")

            Card("Файлы") {
                Row("Папка данных", subtitle: Storage.root.path) {
                    ActionButton("Показать") {
                        NSWorkspace.shared.activateFileViewerSelecting([Storage.root])
                    }
                }
            }

            Card("Сброс") {
                Row("Сбросить все настройки",
                    subtitle: "Ключ Groq, токен и навыки не затрагиваются") {
                    ActionButton("Сбросить…", destructive: true) { confirmReset = true }
                }
            }
            .confirmationDialog("Сбросить все настройки?", isPresented: $confirmReset) {
                Button("Сбросить", role: .destructive) { Prefs.resetAll() }
            }
        }
    }
}
