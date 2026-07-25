//
//  GlassButton.swift
//  Atlas 按钮 —— 白色单色按钮系统。
//  主按钮与常规按钮都使用白色底，依靠文字灰度与透明度区分层级。
//

import SwiftUI

enum AtlasButtonKind {
    case primary   // 白色实心，深灰文字
    case glass     // 白色柔和底，灰色文字
    case ghost     // 无底，仅文字（低强调）
}

struct AtlasButtonStyle: ButtonStyle {
    var kind: AtlasButtonKind = .glass

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous)

        return configuration.label
            .font(AtlasFont.label)
            .foregroundStyle(foreground)
            .padding(.horizontal, AtlasSpacing.l)
            .padding(.vertical, AtlasSpacing.s + 1)
            .background { background(shape: shape, pressed: configuration.isPressed) }
            .overlay {
                if kind == .primary {
                    shape.stroke(Color.white.opacity(0.0), lineWidth: 0)
                } else if kind == .ghost {
                    shape.stroke(AtlasColor.borderSubtle, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Color(white: 0.20)
        case .glass:   return Color(white: 0.36)
        case .ghost:   return AtlasColor.textSecondary
        }
    }

    @ViewBuilder
    private func background(shape: RoundedRectangle, pressed: Bool) -> some View {
        switch kind {
        case .primary:
            shape.fill(Color.white.opacity(pressed ? 0.86 : 0.98))
                .shadow(color: .black.opacity(pressed ? 0.12 : 0.20), radius: 10, y: 4)
        case .glass:
            shape.fill(Color.white.opacity(pressed ? 0.78 : 0.92))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        case .ghost:
            Color.clear
        }
    }
}

extension ButtonStyle where Self == AtlasButtonStyle {
    static func atlas(_ kind: AtlasButtonKind) -> AtlasButtonStyle { AtlasButtonStyle(kind: kind) }
}

/// 便捷：带 SF Symbol 的按钮标签
struct AtlasButtonLabel: View {
    var title: String
    var systemImage: String?
    var body: some View {
        HStack(spacing: AtlasSpacing.xs + 2) {
            if let systemImage { Image(systemName: systemImage).imageScale(.small) }
            Text(title)
        }
    }
}
