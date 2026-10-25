//
//  FairyMode.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
// состояния ассистента, один источник правды
import SwiftUI
import SwiftUI
import Combine
enum FairyStatus: Equatable {
    case idle
    case listening
    case thinking
    case executing(String)
    case error(String)
    case sleeping

    var text: String {
        switch self {
        case .idle: return ""
        case .listening: return "Слушаю…"
        case .thinking: return "Думаю…"
        case .executing(let cmd): return cmd
        case .error(let msg): return msg
        case .sleeping: return "Zzz..."
        }
    }

    var icon: String {
        switch self {
        case .idle: return "sparkle"
        case .listening: return "waveform"
        case .thinking: return "ellipsis"
        case .executing: return "terminal"
        case .error: return "exclamationmark.triangle"
        case .sleeping: return "moon.zzz"
        }
    }
}

@MainActor
final class FairyModel: ObservableObject {
    @Published var status: FairyStatus = .idle
}
