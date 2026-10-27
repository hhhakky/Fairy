//
//  Theme.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import SwiftUI
import AppKit

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var value: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&value) else {
            self = Color(red: 0.49, green: 0.98, blue: 1.0)
            return
        }
        self = Color(red: Double((value >> 16) & 0xFF) / 255,
                     green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255)
    }

    func toHex() -> String {
        let c = NSColor(self).usingColorSpace(.sRGB)
            ?? NSColor(red: 0.49, green: 0.98, blue: 1, alpha: 1)
        return String(format: "#%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}

enum UI {
    static let bg = Color(red: 0.04, green: 0.045, blue: 0.065)
    static let panel = Color.white.opacity(0.04)
    static let stroke = Color.white.opacity(0.08)
    static let text = Color.white.opacity(0.92)
    static let dim = Color.white.opacity(0.5)
}

extension View {
    func fieldStyle() -> some View {
        self.textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(UI.stroke))
    }
}

struct PageTitle: View {
    let title: String
    let subtitle: String
    init(_ title: String, _ subtitle: String) { self.title = title; self.subtitle = subtitle }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 24, weight: .semibold, design: .rounded))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(UI.dim)
        }
        .padding(.bottom, 4)
    }
}

struct Card<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(UI.dim)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(UI.panel))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(UI.stroke, lineWidth: 1))
    }
}

struct Row<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(UI.dim)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

struct SwitchRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        Row(title, subtitle: subtitle) {
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: String = "%.0f"

    var body: some View {
        Row(title) {
            HStack(spacing: 10) {
                Slider(value: $value, in: range).frame(width: 160)
                Text(String(format: format, value))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(UI.dim)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let destructive: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.07)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(destructive ? Color.red.opacity(0.5) : UI.stroke))
                .foregroundStyle(destructive ? Color.red : UI.text)
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    init(_ symbol: String, _ help: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 30, height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
