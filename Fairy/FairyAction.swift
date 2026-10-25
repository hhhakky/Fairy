//
//  FairyAction.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
//
import Foundation

enum FairyAction: Equatable {
    case openApp(String)
    case quitApp(String)
    case setVolume(Int)
    case mute(Bool)

    /// Что показываем на острове
    var display: String {
        switch self {
        case .openApp(let n): return "open -a \(n)"
        case .quitApp(let n): return "quit \(n)"
        case .setVolume(let v): return "volume \(v)%"
        case .mute(let m): return m ? "mute" : "unmute"
        }
    }
}
