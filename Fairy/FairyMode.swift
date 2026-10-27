//
//  FairyMode.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
// состояния ассистента, один источник правды
import SwiftUI
import AppKit
import Combine

enum FairyStatus: Equatable {
    case idle
    case listening
    case thinking
    case executing(String, icon: String? = nil)
    case result(String, icon: String? = nil)
    case error(String)

    var text: String {
        switch self {
        case .idle: return ""
        case .listening: return "Слушаю…"
        case .thinking: return "Думаю…"
        case .executing(let cmd, _): return cmd
        case .result(let text, _): return text
        case .error(let msg): return msg
        }
    }

    var icon: String {
        switch self {
        case .idle: return "sparkle"
        case .listening: return "waveform"
        case .thinking: return "ellipsis"
        case .executing(_, let name), .result(_, let name):
            return Self.validSymbol(name) ?? "terminal"
        case .error: return "exclamationmark.triangle"
        }
    }

    var isResult: Bool {
        if case .result = self { return true }
        return false
    }

    /// Неверное имя иконки не ломает остров: просто показываем терминал
    private static func validSymbol(_ name: String?) -> String? {
        guard let name, !name.isEmpty,
              NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        else { return nil }
        return name
    }
}

@MainActor
final class FairyModel: ObservableObject {
    @Published var status: FairyStatus = .idle
}
