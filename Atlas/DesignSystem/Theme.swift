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

    // 创作型语义色：低饱和、可叠加在深色玻璃上，用于建立信息层级。
    static let auroraBlue   = Color(red: 0.34, green: 0.56, blue: 1.00)
    static let auroraViolet = Color(red: 0.72, green: 0.39, blue: 0.94)
    static let auroraMint   = Color(red: 0.31, green: 0.88, blue: 0.74)
    static let auroraAmber  = Color(red: 1.00, green: 0.68, blue: 0.32)
    static let auroraRose   = Color(red: 1.00, green: 0.42, blue: 0.58)
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
// 近黑 + Lightfall 光雨。给液态玻璃提供可折射的高对比动态纹理。

struct AtlasCanvasBackground: View {
    var animated: Bool = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // 与首页星图一致的彩色深空光晕；内容层仍保持高对比黑底。
            GeometryReader { proxy in
                let size = proxy.size
                if animated {
                    AtlasLightfallBackground(size: size)
                } else {
                    AtlasStaticAuroraBackground(size: size)
                }
            }
            .ignoresSafeArea()
            .blendMode(.plusLighter)

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.30)],
                center: .center,
                startRadius: 40,
                endRadius: 900
            )
            .ignoresSafeArea()

            // 制图网格
            Canvas { context, size in
                // 稀疏星点，管理界面也保留“世界漂浮在星图中”的感觉。
                for index in 0..<72 {
                    let x = CGFloat((index * 83) % 997) / 997 * size.width
                    let y = CGFloat((index * 47 + 19) % 991) / 991 * size.height
                    let radius: CGFloat = index.isMultiple(of: 9) ? 1.5 : 0.7
                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(index.isMultiple(of: 9) ? 0.42 : 0.18)))
                }

                let step: CGFloat = 44
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step }
                var y: CGFloat = 0
                while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                context.stroke(path, with: .color(.white.opacity(0.018)), lineWidth: 0.5)
            }
            .ignoresSafeArea()
            .blendMode(.plusLighter)
        }
        .background(AtlasColor.canvas)
    }
}

private struct AtlasStaticAuroraBackground: View {
    let size: CGSize

    var body: some View {
        ZStack {
            Color(red: 0.015, green: 0.014, blue: 0.025)

            Ellipse()
                .fill(Color(red: 0.24, green: 0.11, blue: 0.64).opacity(0.18))
                .frame(width: size.width * 0.72, height: size.height * 0.58)
                .blur(radius: 135)
                .offset(x: size.width * 0.46, y: -size.height * 0.18)

            Ellipse()
                .fill(Color(red: 0.08, green: 0.34, blue: 0.29).opacity(0.13))
                .frame(width: size.width * 0.58, height: size.height * 0.48)
                .blur(radius: 125)
                .offset(x: -size.width * 0.32, y: size.height * 0.22)
        }
        .saturation(1.12)
        .drawingGroup()
    }
}

private struct AtlasLightfallBackground: View {
    let size: CGSize

    var body: some View {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * 1.22
            ZStack {
                Color(red: 0.015, green: 0.014, blue: 0.025)

                ambientGlow(time: t)
                auroraVeils(time: t)
            }
            .saturation(1.24)
            .drawingGroup()
        }
    }

    private func auroraVeils(time: TimeInterval) -> some View {
        ZStack {
            auroraOrb(
                colors: [
                    Color(red: 0.12, green: 0.88, blue: 0.72).opacity(0.22),
                    Color(red: 0.18, green: 0.46, blue: 1.0).opacity(0.09),
                    .clear
                ],
                width: 0.62,
                height: 0.42,
                x: reflectedMotion(time * 0.17 + 0.2) * size.width * 0.27,
                y: reflectedMotion(time * 0.11 + 1.4) * size.height * 0.24,
                scale: 0.94 + 0.12 * CGFloat((sin(time * 0.46) + 1) / 2),
                rotation: -12 + 9 * sin(time * 0.16)
            )

            auroraOrb(
                colors: [
                    Color(red: 0.68, green: 0.20, blue: 1.0).opacity(0.17),
                    Color(red: 1.0, green: 0.22, blue: 0.58).opacity(0.07),
                    .clear
                ],
                width: 0.54,
                height: 0.38,
                x: reflectedMotion(time * 0.13 + 2.5) * size.width * 0.30,
                y: reflectedMotion(time * 0.19 + 0.8) * size.height * 0.27,
                scale: 0.92 + 0.14 * CGFloat((cos(time * 0.39) + 1) / 2),
                rotation: 15 - 11 * cos(time * 0.13)
            )

            auroraOrb(
                colors: [
                    Color(red: 0.10, green: 0.72, blue: 1.0).opacity(0.14),
                    Color(red: 0.45, green: 1.0, blue: 0.72).opacity(0.055),
                    .clear
                ],
                width: 0.46,
                height: 0.34,
                x: reflectedMotion(time * 0.21 + 3.1) * size.width * 0.32,
                y: reflectedMotion(time * 0.09 + 2.0) * size.height * 0.29,
                scale: 0.96 + 0.10 * CGFloat((sin(time * 0.51 + 1.2) + 1) / 2),
                rotation: -4 + 13 * sin(time * 0.11)
            )

            auroraRibbon(
                colors: [
                    Color(red: 0.16, green: 0.92, blue: 0.72),
                    Color(red: 0.12, green: 0.55, blue: 0.96),
                    Color.clear
                ],
                width: 1.26,
                height: 0.22,
                rotation: -12 + sin(time * 0.10) * 8,
                x: sin(time * 0.075) * size.width * 0.15,
                y: -size.height * 0.20 + cos(time * 0.09) * size.height * 0.10
            )

            auroraRibbon(
                colors: [
                    Color.clear,
                    Color(red: 0.54, green: 0.18, blue: 0.96),
                    Color(red: 0.92, green: 0.22, blue: 0.70)
                ],
                width: 1.12,
                height: 0.28,
                rotation: 18 + cos(time * 0.085) * 10,
                x: size.width * 0.18 + cos(time * 0.06) * size.width * 0.13,
                y: size.height * 0.10 + sin(time * 0.07) * size.height * 0.13
            )

            auroraRibbon(
                colors: [
                    Color(red: 0.18, green: 0.46, blue: 0.98),
                    Color(red: 0.36, green: 0.96, blue: 0.72),
                    Color.clear
                ],
                width: 0.92,
                height: 0.16,
                rotation: -32 + sin(time * 0.12) * 12,
                x: -size.width * 0.22 + sin(time * 0.055) * size.width * 0.12,
                y: size.height * 0.30 + cos(time * 0.08) * size.height * 0.10
            )
        }
        .blendMode(.plusLighter)
    }

    private func auroraOrb(
        colors: [Color],
        width: CGFloat,
        height: CGFloat,
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat,
        rotation: Double
    ) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: colors,
                    center: .center,
                    startRadius: 0,
                    endRadius: max(size.width * width, size.height * height) * 0.5
                )
            )
            .frame(width: size.width * width, height: size.height * height)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .blur(radius: 72)
            .offset(x: x, y: y)
    }

    private func reflectedMotion(_ value: Double) -> CGFloat {
        let wrapped = value.truncatingRemainder(dividingBy: 4)
        let phase = wrapped >= 0 ? wrapped : wrapped + 4
        return CGFloat(phase < 2 ? phase - 1 : 3 - phase)
    }

    private func auroraRibbon(
        colors: [Color],
        width: CGFloat,
        height: CGFloat,
        rotation: Double,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.width * width, height: size.height * height)
            .blur(radius: 72)
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: y)
            .opacity(0.21)
    }

    private func ambientGlow(time: TimeInterval) -> some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.24, green: 0.11, blue: 0.64).opacity(0.15))
                .frame(width: size.width * 0.70, height: size.height * 0.55)
                .blur(radius: 130)
                .offset(x: size.width * 0.56 + sin(time * 0.07) * 70,
                        y: -size.height * 0.18 + cos(time * 0.05) * 40)

            Ellipse()
                .fill(Color(red: 0.12, green: 0.17, blue: 0.52).opacity(0.12))
                .frame(width: size.width * 0.62, height: size.height * 0.48)
                .blur(radius: 120)
                .offset(x: -size.width * 0.28 + cos(time * 0.06) * 64,
                        y: size.height * 0.16 + sin(time * 0.055) * 38)
        }
    }

    private func tunnelGuides(time: TimeInterval) -> some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width * 0.50, y: canvasSize.height * -0.36)
            for index in 0..<18 {
                let offset = CGFloat(index - 9) * canvasSize.width * 0.075
                var path = Path()
                path.move(to: CGPoint(x: center.x + offset * 0.22, y: -80))
                path.addCurve(
                    to: CGPoint(x: center.x + offset * 2.9, y: canvasSize.height + 180),
                    control1: CGPoint(x: center.x + offset * 0.75, y: canvasSize.height * 0.22),
                    control2: CGPoint(x: center.x + offset * 1.8, y: canvasSize.height * 0.76)
                )
                let opacity = index.isMultiple(of: 3) ? 0.18 : 0.08
                context.stroke(path, with: .color(Color(red: 0.34, green: 0.12, blue: 0.92).opacity(opacity)), lineWidth: 0.7)
            }
        }
        .blendMode(.plusLighter)
    }

    private func lightStreaks(time: TimeInterval) -> some View {
        Canvas { context, canvasSize in
            let palette = [
                Color(red: 0.80, green: 0.70, blue: 1.00),
                Color(red: 0.48, green: 0.18, blue: 0.92),
                Color(red: 0.68, green: 0.50, blue: 1.00),
                Color(red: 0.95, green: 0.91, blue: 1.00)
            ]
            let height = canvasSize.height
            let width = canvasSize.width
            let cycle = height + 620

            for index in 0..<42 {
                let seed = Double(index)
                let xSeed = fract(sin(seed * 12.9898) * 43758.5453)
                let speed = 165.0 + fract(sin(seed * 24.73) * 9351.17) * 250.0
                let progress = CGFloat((time * speed + seed * 137.0).truncatingRemainder(dividingBy: Double(cycle)))
                let yHead = progress - 360
                let tail = CGFloat(190 + fract(sin(seed * 52.1) * 7182.2) * 260)
                let xBase = CGFloat(xSeed) * (width * 1.18) - width * 0.09
                let side = (xBase - width * 0.5) / max(width * 0.5, 1)
                let curve = CGFloat(70 + fract(sin(seed * 9.8) * 2451.8) * 130) * side
                let yTail = yHead - tail
                let alpha = 0.42 + fract(sin(seed * 81.2) * 1917.3) * 0.42

                var path = Path()
                path.move(to: CGPoint(x: xBase + curve * 0.05, y: yTail))
                path.addCurve(
                    to: CGPoint(x: xBase + curve, y: yHead),
                    control1: CGPoint(x: xBase + curve * 0.24, y: yTail + tail * 0.32),
                    control2: CGPoint(x: xBase + curve * 0.82, y: yTail + tail * 0.76)
                )

                let color = palette[index % palette.count]
                let gradient = Gradient(colors: [
                    color.opacity(0),
                    color.opacity(alpha * 0.34),
                    Color.white.opacity(alpha),
                ])
                context.stroke(path, with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: xBase, y: yTail),
                    endPoint: CGPoint(x: xBase + curve, y: yHead)
                ), style: StrokeStyle(lineWidth: index.isMultiple(of: 5) ? 1.45 : 0.92, lineCap: .round))

                let tipRect = CGRect(x: xBase + curve - 1.7, y: yHead - 1.7, width: 3.4, height: 3.4)
                context.fill(Path(ellipseIn: tipRect), with: .color(Color.white.opacity(alpha)))
            }
        }
        .blendMode(.plusLighter)
    }

    private func fract(_ value: Double) -> Double {
        value - floor(value)
    }
}
