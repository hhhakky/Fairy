//
//  IslandPanel.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
// окно поверх всего, пропускает клики
import SwiftUI
import AppKit

final class IslandPanel: NSPanel {
    private let size = NSSize(width: 480, height: 60)

    init(model: FairyModel) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = NSHostingView(rootView: IslandView(model: model))
    }

    func show() {
        guard let screen = NSScreen.main else { return }
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.maxY - size.height - 10
        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        orderFrontRegardless()
    }
}
