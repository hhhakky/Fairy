//
//  IslandView.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
// сам остров
import SwiftUI

struct IslandView: View {
    @ObservedObject var model: FairyModel

    var body: some View {
        VStack {
            if model.status != .idle {
                HStack(spacing: 8) {
                    Image(systemName: model.status.icon)
                        .symbolEffect(.pulse)
                    Text(model.status.text)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(.black))
                .padding(.top, 14)
                .transition(.scale(scale: 0.5, anchor: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//        .animation(.spring(duration: 0.35), value: model.status) - дефолтная анимка
//        .animation(.easeInOut(duration: 0.2), value: model.status) - более спокойная
        .animation(.spring(duration: 0.35, bounce: 0.3), value: model.status)
    }
}
