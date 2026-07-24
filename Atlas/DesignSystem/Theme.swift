//
//  Theme.swift
//  Atlas 设计 token —— 黑白单色系统（无主题色）
//
//  原则：
//  1. 不引入任何品牌强调色。层次 = 单色灰阶 + 玻璃质感 + 排版权重。
//  2. 玻璃需要底层内容才能折射，所以画布是近黑而非纯黑，
//     并叠一层极淡的制图网格（cartographic 底纹），呼应"世界地图"气质。
//  3. 组件只消费语义 token（AtlasColor / AtlasSpacing / AtlasRadius / AtlasFont），
//     不直接写死颜色 —— 未来若要引入单一强调色，只改这一处。
//

import SwiftUI

// MARK: - 语义色板（单色）

enum AtlasColor {
    // 背景层级（近黑 → 略亮，用于分层 surface）
    static let canvas      = Color(white: 0.045)   // 最底：应用画布
    static let subtle      = Color(white: 0.085)   // 次级背景
    static let surface     = Color(white: 0.12)    // 卡片/面板非玻璃兜底
    static let elevated    = Color(white: 0.16)    // 抬升表面

    // 文字（白 → 灰，纯白仅用于最高强调）
    static let textPrimary   = Color(white: 0.97)
    static let textSecondary = Color(white: 0.68)
    static let textTertiary  = Color(white: 0.46)
    static let textDisabled  = Color(white: 0.30)

    // 描边（玻璃边缘高光 / 分隔线）
    static let borderSubtle  = Color.white.opacity(0.08)
    static let borderDefault = Color.white.opacity(0.14)
    static let borderStrong  = Color.white.opacity(0.24)

    // 反色（用于白色实心按钮上的文字）
    static let inverse = Color(white: 0.06)

    // 状态：黑白系统里不靠色相区分，用亮度 + 图标 + 文案。
    // 仅保留极低饱和的信号色作为"最后手段"，默认不用。
    static let signal = Color(white: 0.90)
}

// MARK: - 间距（4pt 基准）

enum AtlasSpacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let s:   CGFloat = 8
    static let m:   CGFloat = 12
    static let l:   CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - 圆角

enum AtlasRadius {
    static let control: CGFloat = 8    // 按钮/输入
    static let card:    CGFloat = 12   // 内容卡
    static let panel:   CGFloat = 18   // 面板/对话框
    // 头像与状态点用 .capsule / .circle
}

// MARK: - 排版
// 产品 UI 用系统无衬线（SF Pro）；ID / 坐标 / 版本 / 时间戳用等宽（SF Mono）。

enum AtlasFont {
    static let display = Font.system(size: 34, weight: .semibold, design: .default)
    static let title   = Font.system(size: 22, weight: .semibold, design: .default)
    static let heading = Font.system(size: 17, weight: .semibold, design: .default)
    static let body    = Font.system(size: 14, weight: .regular,  design: .default)
    /// 长文写作/阅读正文（详情卡档案内容等）——比 chrome 用的 body 大 2pt，读写更舒适。
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let label   = Font.system(size: 13, weight: .medium,   design: .default)
    static let caption = Font.system(size: 11, weight: .regular,  design: .default)
    /// 技术元数据：ID、坐标、版本、时间戳
    static let mono    = Font.system(size: 12, weight: .regular,  design: .monospaced)
    static let monoSmall = Font.system(size: 10.5, weight: .regular, design: .monospaced)

    // 衬线（宋体）——仅用于"世界"级别的名字与意象，呼应星图里世界名的气质。
    // 产品功能 UI 仍用无衬线；衬线是留给"作品"的，不是留给"界面"的。
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Songti SC", size: size).weight(weight)
    }
    static let serifDisplay = serif(40, weight: .semibold)
    static let serifTitle   = serif(28, weight: .medium)
    static let serifHeading = serif(20, weight: .medium)
    static let serifBody    = serif(16)
}

// MARK: - 应用画布背景
// 近黑 + 极淡制图网格。给玻璃提供可折射的底层纹理，同时立住"世界/地图"气质。

struct AtlasCanvasBackground: View {
    var body: some View {
        ZStack {
            // 底色：从中心略亮到边缘更暗的单色渐变
            RadialGradient(
                colors: [Color(white: 0.10), AtlasColor.canvas],
                center: .center,
                startRadius: 40,
                endRadius: 900
            )
            .ignoresSafeArea()

            // 制图网格
            Canvas { context, size in
                let step: CGFloat = 44
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step }
                var y: CGFloat = 0
                while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                context.stroke(path, with: .color(.white.opacity(0.022)), lineWidth: 0.5)
            }
            .ignoresSafeArea()
            .blendMode(.plusLighter)
        }
        .background(AtlasColor.canvas)
    }
}
