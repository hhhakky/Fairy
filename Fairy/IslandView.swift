//
//  IslandView.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
// сам остров
import SwiftUI

/// Сама пилюля. Её же показываем в предпросмотре настроек
struct IslandPill: View {
    let status: FairyStatus

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

    private var accent: Color { Color(hex: accentHex) }

    private var tint: Color {
        guard stateColors else { return accent }
        switch status {
        case .thinking: return .yellow
        case .error: return .red
        default: return accent
        }
    }

    private var design: Font.Design {
        switch fontDesign {
        case "default": return .default
        case "mono": return .monospaced
        default: return .rounded
        }
    }

    @ViewBuilder private var fill: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch style {
        case "glass":
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.black.opacity(0.25)))
        case "graphite":
            shape.fill(Color(red: 0.11, green: 0.12, blue: 0.15))
        case "tinted":
            ZStack {
                shape.fill(Color.black)
                shape.fill(LinearGradient(colors: [accent.opacity(0.35), Color.clear],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        default:
            shape.fill(Color.black)
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if showIcon {
                Image(systemName: status.icon)
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse, isActive: !status.isResult)
            }
            Text(status.text)
                .font(.system(size: fontSize, weight: .medium, design: design))
                .lineLimit(status.isResult ? 3 : 1)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(maxWidth: maxWidth)
        .background(fill)
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(tint.opacity(borderAlpha), lineWidth: 1))
        .shadow(color: tint.opacity(glow * 0.7), radius: 4 + 10 * glow)
        .opacity(alpha)
    }
}

struct IslandView: View {
    @ObservedObject var model: FairyModel
    @AppStorage(Prefs.animSpeed) private var speed = Prefs.Default.animSpeed
    @AppStorage(Prefs.animBounce) private var bounce = Prefs.Default.bounce

    var body: some View {
        VStack {
            if model.status != .idle {
                IslandPill(status: model.status)
                    .transition(.scale(scale: 0.5, anchor: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(duration: max(0.1, speed), bounce: bounce), value: model.status)
    }
}
// OLD
//        .animation(.spring(duration: 0.35), value: model.status) - дефолтная анимка
//        .animation(.easeInOut(duration: 0.2), value: model.status) - более спокойная
//        .animation(.spring(duration: 0.35, bounce: 0.3), value: model.status)
 
