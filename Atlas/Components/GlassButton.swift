//
//  GlassButton.swift
//  Atlas 按钮 —— 两档：primary（白色实心，最高强调）/ glass（液态玻璃，常规）。
//  黑白系统里"主按钮"用纯白实心制造唯一强调，其余一律玻璃。
//

import SwiftUI

enum AtlasButtonKind {
    case primary   // 白色实心，反色文字
    case glass     // 液态玻璃
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
        case .primary: return .white
        case .glass:   return AtlasColor.textPrimary
        case .ghost:   return AtlasColor.textSecondary
        }
    }

    @ViewBuilder
    private func background(shape: RoundedRectangle, pressed: Bool) -> some View {
        switch kind {
        case .primary:
            shape.fill(
                LinearGradient(
                    colors: [
                        AtlasColor.auroraBlue.opacity(pressed ? 0.76 : 0.96),
                        AtlasColor.auroraViolet.opacity(pressed ? 0.72 : 0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: AtlasColor.auroraBlue.opacity(0.22), radius: 12, y: 5)
        case .glass:
            Color.clear.atlasChromaticGlass(shape, tint: AtlasColor.auroraBlue.opacity(0.36), interactive: true)
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
