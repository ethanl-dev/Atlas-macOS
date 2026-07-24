import SwiftUI

struct PublicProjectView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var tab = PublicTab.detail

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    tabBar
                    content
                }
            }

            if model.accessMode == .publicPreview {
                previewBar
                    .padding(AtlasSpacing.l)
            }
        }
        .background(AtlasCanvasBackground())
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            PublicWorldArtwork()
                .frame(height: 390)

            LinearGradient(
                colors: [.clear, AtlasColor.canvas.opacity(0.90)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                HStack(spacing: AtlasSpacing.s) {
                    Label("持续招募中", systemImage: "circle.fill")
                    Text("第二幕 · 潮汐历 742 年")
                }
                .font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textSecondary)

                Text(model.activeWorld.name)
                    .font(.system(size: 44, weight: .semibold))

                Text(model.activeWorld.hook)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AtlasColor.textSecondary)

                HStack(spacing: AtlasSpacing.s) {
                    if model.accessMode == .publicPreview {
                        Button {
                            model.activeSheet = .publish
                        } label: {
                            AtlasButtonLabel(title: "发布招募页", systemImage: "paperplane")
                        }
                        .buttonStyle(.atlas(.primary))
                    } else {
                        Button {
                            model.activeSheet = .application
                        } label: {
                            AtlasButtonLabel(title: "申请加入", systemImage: "person.badge.plus")
                        }
                        .buttonStyle(.atlas(.primary))

                        Button {
                            model.accessMode = .participate
                            model.destination = .overview
                        } label: {
                            AtlasButtonLabel(title: "进入企划", systemImage: "arrow.right")
                        }
                        .buttonStyle(.atlas(.glass))
                    }
                }
            }
            .padding(AtlasSpacing.xxl)
        }
        .frame(minHeight: 390)
    }

    private var tabBar: some View {
        HStack(spacing: AtlasSpacing.xxl) {
            ForEach(PublicTab.allCases) { item in
                Button {
                    withAnimation(.snappy) { tab = item }
                } label: {
                    VStack(spacing: AtlasSpacing.s) {
                        Label(item.rawValue, systemImage: item.symbol)
                            .font(AtlasFont.label)
                        Rectangle()
                            .fill(tab == item ? Color.white : Color.clear)
                            .frame(height: 2)
                    }
                    .foregroundStyle(tab == item ? AtlasColor.textPrimary : AtlasColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("\(model.activeWorld.members) 位成员")
                .font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textTertiary)
        }
        .padding(.horizontal, AtlasSpacing.xxl)
        .padding(.top, AtlasSpacing.l)
        .background(AtlasColor.canvas)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .detail: publicDetail
        case .characters: characterGallery
        case .works: workGallery
        }
    }

    private var publicDetail: some View {
        HStack(alignment: .top, spacing: AtlasSpacing.xxxl) {
            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                Text("来自未来的信，正在退潮后的白沙滩上等待收件人。")
                    .font(.system(size: 26, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)

                Text("雾潮纪元第四十二年，北方海域的旧航线再度开放。沿海居民发现，海雾中偶尔会出现无法被星图记录的岛屿，而从岛上寄出的信件，落款日期都在三十年以后。")
                    .font(.system(size: 16))
                    .foregroundStyle(AtlasColor.textSecondary)
                    .lineSpacing(7)

                Divider().overlay(AtlasColor.borderSubtle)

                HStack(spacing: AtlasSpacing.xxl) {
                    publicMetric("当前章节", value: "第二幕")
                    publicMetric("企划周期", value: "长期")
                    publicMetric("参与方式", value: "审核制")
                }

                Text("世界节选")
                    .font(AtlasFont.heading)

                MiniWorldStrip(model: model)
            }
            .frame(maxWidth: 720, alignment: .leading)

            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                Label("AI 使用边界", systemImage: "checkmark.shield")
                    .font(AtlasFont.heading)
                policyRow("允许", detail: "灵感发散、资料整理、文本校对")
                policyRow("需标注", detail: "包含 AI 辅助的公开文本")
                policyRow("关闭", detail: "图片生成、改图、画风模仿")
                Divider().overlay(AtlasColor.borderSubtle)
                Text("申请前，参与者需要确认完整的 AI 与授权声明。")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .padding(AtlasSpacing.l)
            .frame(width: 300)
            .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        }
        .padding(AtlasSpacing.xxl)
        .frame(maxWidth: 1120, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private var characterGallery: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            Text("已进入世界的角色")
                .font(AtlasFont.title)
            Text("角色不是展示卡，而是拥有位置、目标、关系和事件经历的世界对象。")
                .font(AtlasFont.body)
                .foregroundStyle(AtlasColor.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: AtlasSpacing.l)], spacing: AtlasSpacing.l) {
                ForEach(PublicCharacter.samples) { character in
                    Button {
                        model.showToast("已打开 \(character.name) 的角色档案")
                    } label: {
                        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                            CharacterPortrait(seed: character.seed, initials: character.initials)
                                .frame(height: 210)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(character.role)
                                    .font(AtlasFont.monoSmall)
                                    .foregroundStyle(AtlasColor.textTertiary)
                                Text(character.name)
                                    .font(AtlasFont.heading)
                                Label(character.location, systemImage: "mappin")
                                    .font(AtlasFont.caption)
                                    .foregroundStyle(AtlasColor.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AtlasSpacing.xxl)
    }

    private var workGallery: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            Text("世界留下的作品")
                .font(AtlasFont.title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: AtlasSpacing.l)], spacing: AtlasSpacing.l) {
                ForEach(AtlasAssetPreview.samples) { work in
                    Button {
                        model.showToast("已打开作品「\(work.title)」")
                    } label: {
                        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                            AssetArtworkPreview(seed: work.seed, symbol: work.symbol)
                                .frame(height: work.featured ? 240 : 170)
                            Text(work.title)
                                .font(AtlasFont.heading)
                            Text("\(work.author) · \(work.type)")
                                .font(AtlasFont.caption)
                                .foregroundStyle(AtlasColor.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AtlasSpacing.xxl)
    }

    private var previewBar: some View {
        HStack {
            Label("公开页预览", systemImage: "eye")
                .font(AtlasFont.label)
            Text("访客将看到这个版本")
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textTertiary)
            Spacer()
            Button {
                model.switchMode(.manage)
            } label: {
                AtlasButtonLabel(title: "返回管理", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.atlas(.glass))
        }
        .padding(.horizontal, AtlasSpacing.m)
        .padding(.vertical, AtlasSpacing.s)
        .atlasGlass(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AtlasColor.borderSubtle))
    }

    private func publicMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textTertiary)
            Text(value)
                .font(AtlasFont.heading)
        }
    }

    private func policyRow(_ label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textTertiary)
            Text(detail)
                .font(AtlasFont.caption)
        }
    }
}

private enum PublicTab: String, CaseIterable, Identifiable {
    case detail = "企划详情"
    case characters = "参企角色"
    case works = "作品 Library"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .detail: return "doc.text"
        case .characters: return "person.2"
        case .works: return "photo.on.rectangle.angled"
        }
    }
}

private struct PublicWorldArtwork: View {
    var body: some View {
        ZStack {
            Color(white: 0.055)
            Canvas { context, size in
                let horizon = size.height * 0.58
                for index in 0..<12 {
                    let y = horizon + CGFloat(index) * 13
                    var wave = Path()
                    wave.move(to: CGPoint(x: 0, y: y))
                    for sample in 0...80 {
                        let x = CGFloat(sample) / 80 * size.width
                        let dy = sin(CGFloat(sample) * 0.35 + CGFloat(index)) * CGFloat(2 + index / 3)
                        wave.addLine(to: CGPoint(x: x, y: y + dy))
                    }
                    context.stroke(wave, with: .color(.white.opacity(0.025 + Double(index) * 0.006)), lineWidth: 1)
                }

                let towers = [
                    CGRect(x: size.width * 0.18, y: horizon - 90, width: 18, height: 90),
                    CGRect(x: size.width * 0.48, y: horizon - 140, width: 24, height: 140),
                    CGRect(x: size.width * 0.78, y: horizon - 72, width: 16, height: 72)
                ]
                for tower in towers {
                    context.fill(Path(roundedRect: tower, cornerRadius: 5), with: .color(.white.opacity(0.16)))
                    let light = CGRect(x: tower.midX - 4, y: tower.minY - 5, width: 8, height: 8)
                    context.fill(Path(ellipseIn: light), with: .color(.white.opacity(0.95)))
                }
            }
            .blur(radius: 0.2)

            RadialGradient(
                colors: [.white.opacity(0.10), .clear],
                center: UnitPoint(x: 0.50, y: 0.38),
                startRadius: 0,
                endRadius: 310
            )
        }
    }
}

private struct MiniWorldStrip: View {
    @ObservedObject var model: AtlasAppModel

    var body: some View {
        HStack(spacing: AtlasSpacing.m) {
            ForEach(WorldObject.samples.prefix(4)) { object in
                Button {
                    model.selectedObjectID = object.id
                    model.destination = .canvas
                } label: {
                    VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                        Image(systemName: object.type.symbol)
                            .font(.system(size: 17, weight: .light))
                        Text(object.name)
                            .font(AtlasFont.label)
                            .lineLimit(1)
                        Text(object.type.rawValue)
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AtlasSpacing.m)
                    .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: AtlasRadius.card))
                    .overlay(RoundedRectangle(cornerRadius: AtlasRadius.card).stroke(AtlasColor.borderSubtle))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PublicCharacter: Identifiable {
    let id: Int
    let name: String
    let role: String
    let location: String
    let initials: String
    let seed: Int

    static let samples = [
        PublicCharacter(id: 1, name: "岑", role: "档案修复师", location: "雾港", initials: "C", seed: 1),
        PublicCharacter(id: 2, name: "伊莱", role: "领航员", location: "白塔", initials: "E", seed: 2),
        PublicCharacter(id: 3, name: "白昼", role: "外来调查者", location: "第七码头", initials: "B", seed: 3),
        PublicCharacter(id: 4, name: "阿芙拉", role: "雾海信使", location: "北岸", initials: "A", seed: 4)
    ]
}

struct CharacterPortrait: View {
    var seed: Int
    var initials: String

    var body: some View {
        ZStack {
            Color(white: 0.07 + Double(seed % 3) * 0.02)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.46)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 38, y: center.y - 58, width: 76, height: 76)),
                    with: .color(.white.opacity(0.10))
                )
                var body = Path()
                body.move(to: CGPoint(x: center.x - 82, y: size.height))
                body.addQuadCurve(
                    to: CGPoint(x: center.x + 82, y: size.height),
                    control: CGPoint(x: center.x, y: center.y + 8)
                )
                context.fill(body, with: .color(.white.opacity(0.08)))
            }
            Text(initials)
                .font(.system(size: 34, weight: .ultraLight, design: .serif))
                .foregroundStyle(Color.white.opacity(0.6))
        }
        .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.card).stroke(AtlasColor.borderSubtle))
    }
}

private struct AtlasAssetPreview: Identifiable {
    let id: Int
    let title: String
    let author: String
    let type: String
    let seed: Int
    let symbol: String
    let featured: Bool

    static let samples = [
        AtlasAssetPreview(id: 1, title: "第七码头的灯", author: "白雀", type: "插画", seed: 1, symbol: "light.beacon.max", featured: true),
        AtlasAssetPreview(id: 2, title: "雾中信使", author: "秋庭", type: "插画", seed: 2, symbol: "figure.walk", featured: false),
        AtlasAssetPreview(id: 3, title: "潮汐以前 · 序章", author: "林雾", type: "短篇", seed: 3, symbol: "doc.text", featured: false),
        AtlasAssetPreview(id: 4, title: "远岸以北", author: "岛屿", type: "地图", seed: 4, symbol: "map", featured: false)
    ]
}

private struct AssetArtworkPreview: View {
    var seed: Int
    var symbol: String

    var body: some View {
        ZStack {
            Color(white: 0.07 + Double(seed % 3) * 0.018)
            Canvas { context, size in
                for index in 0..<10 {
                    let y = CGFloat(index) / 10 * size.height
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: y + 10),
                        control1: CGPoint(x: size.width * 0.3, y: y + CGFloat(seed * 7)),
                        control2: CGPoint(x: size.width * 0.7, y: y - CGFloat(seed * 5))
                    )
                    context.stroke(path, with: .color(.white.opacity(0.035 + Double(index) * 0.009)), lineWidth: 1)
                }
            }
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.68))
        }
        .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.card).stroke(AtlasColor.borderSubtle))
    }
}
