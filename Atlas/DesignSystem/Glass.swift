//
//  Glass.swift
//  液态玻璃封装 —— 统一 Atlas 全局玻璃质感，并对 < macOS 26 做降级。
//
//  为什么要封装：
//  - 全站玻璃只从这里出，改质感只改一处。
//  - 系统原生 .glassEffect() 只存在于 macOS 26 SDK；用 #available 包住，
//    低版本运行时降级到 .ultraThinMaterial，保证"能跑"而非"崩"。
//  （需 Xcode 26 才能编译 —— .glassEffect / Glass / GlassEffectContainer 均为 26 SDK 符号。）
//

import SwiftUI

enum AtlasP1Glass {
    static let controlSize: CGFloat = 50
    static let compactControlSize: CGFloat = 42
    static let controlIconSize: CGFloat = 18
    static let prominentIconSize: CGFloat = 21
    static let darkFill = Color.black.opacity(0.18)
    static let edge = Color.white.opacity(0.24)
    static let topHighlight = Color.white.opacity(0.32)
    static let bottomShade = Color.white.opacity(0.08)
}

// MARK: - 玻璃表面修饰器

struct AtlasGlassSurface<S: Shape>: ViewModifier {
    var shape: S
    /// clear：全透纯折射，用于覆盖在丰富内容上的小面积元素；
    /// 默认 regular：常规磨砂，用于面板/卡片/导航。
    var clear: Bool = false
    /// interactive：hover/按压时的缩放与高光反馈（按钮类用）。
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(
                glassVariant,
                in: shape
            )
        } else {
            // 降级：材质 + 边缘高光，尽量贴近玻璃观感
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(AtlasColor.borderDefault, lineWidth: 1))
        }
    }

    @available(macOS 26.0, *)
    private var glassVariant: Glass {
        var g: Glass = clear ? .clear : .regular
        if interactive { g = g.interactive() }
        return g
    }
}

extension View {
    /// 常规玻璃表面（面板 / 卡片 / 导航底板）
    func atlasGlass<S: Shape>(
        _ shape: S = RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous),
        clear: Bool = false,
        interactive: Bool = false
    ) -> some View {
        modifier(AtlasGlassSurface(shape: shape, clear: clear, interactive: interactive))
    }

    /// 星图 P1 玻璃：深色透明芯、清晰上缘和原生实时折射。
    func atlasP1Glass<S: Shape>(
        _ shape: S = Capsule(),
        interactive: Bool = false
    ) -> some View {
        background(AtlasP1Glass.darkFill, in: shape)
            .atlasGlass(shape, clear: true, interactive: interactive)
            .overlay(shape.stroke(AtlasP1Glass.edge, lineWidth: 1))
            .overlay(alignment: .top) {
                shape.stroke(AtlasP1Glass.topHighlight, lineWidth: 0.7)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
            .shadow(color: .black.opacity(0.38), radius: 15, y: 8)
    }

    /// 左下角头像品牌 Dock 同款玻璃。保持原生玻璃层独立，避免 compositingGroup
    /// 将动态折射预先栅格化成静态磨砂。
    func atlasFloatingGlass<S: Shape>(
        _ shape: S = RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous),
        interactive: Bool = false
    ) -> some View {
        atlasGlass(shape, interactive: interactive)
            .overlay(shape.stroke(Color.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
    }

    /// 带语义色的流动玻璃。色彩只做局部光源，文字仍保持高对比。
    func atlasChromaticGlass<S: Shape>(
        _ shape: S = RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous),
        tint: Color,
        interactive: Bool = false
    ) -> some View {
        background(
            LinearGradient(
                colors: [tint.opacity(0.22), tint.opacity(0.05), Color.black.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: shape
        )
        .atlasGlass(shape, clear: true, interactive: interactive)
        .overlay(shape.stroke(tint.opacity(0.30), lineWidth: 1))
        .overlay(alignment: .top) {
            shape.stroke(tint.opacity(0.48), lineWidth: 0.7)
                .mask(
                    LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: .center)
                )
        }
        .shadow(color: tint.opacity(0.13), radius: 22, y: 8)
    }

}

// MARK: - 玻璃容器
// GlassEffectContainer 让相邻玻璃形状融合、共享光照并可形变；多个玻璃元素相邻时务必包一层。
// 低版本降级为普通布局容器。

struct AtlasGlassGroup<Content: View>: View {
    var spacing: CGFloat
    var content: Content

    init(spacing: CGFloat = AtlasSpacing.m, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
