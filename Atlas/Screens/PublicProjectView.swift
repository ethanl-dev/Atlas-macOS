import SwiftUI

struct PublicProjectView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var tab = PublicTab.detail

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                pageLayout
            }
        }
        .background(AtlasCanvasBackground())
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            PublicWorldArtwork()
                .frame(height: 500)

            heroDock
                .padding(.horizontal, 32)
                .padding(.bottom, 22)
        }
        .frame(height: 500)
        .clipped()
    }

    private var heroDock: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 8) {
                heroIdentity
                    .frame(width: 300, height: 138, alignment: .bottomLeading)
                heroMetrics
                    .frame(minWidth: 360, maxWidth: .infinity, minHeight: 76, maxHeight: 76)
                heroActions
                    .frame(width: 390, height: 82)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    heroIdentity.frame(maxWidth: .infinity, minHeight: 116)
                    heroActions.frame(width: 330, height: 82)
                }
                heroMetrics.frame(height: 70)
            }
        }
    }

    private var heroIdentity: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: AtlasSpacing.s) {
                Label(model.activeWorld.status, systemImage: "circle.fill")
                Text("第二幕 · 潮汐历 742 年")
            }
            .font(AtlasFont.monoSmall)
            .foregroundStyle(AtlasColor.textSecondary)

            Text(model.activeWorld.name)
                .font(.system(size: 34, weight: .semibold))

            Text(model.activeWorld.hook)
                .font(.system(size: 15))
                .foregroundStyle(AtlasColor.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private var heroMetrics: some View {
        HStack(spacing: 0) {
            heroMetric("活跃角色", value: "24")
            heroMetric("开放任务", value: "07")
            heroMetric("Wiki 变更", value: "36", showsDivider: false)
        }
    }

    private var heroActions: some View {
        AtlasGlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    model.navigate(to: .canvas)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("进入企划")
                                .font(.system(size: 17, weight: .semibold))
                            Text("打开 World Canvas")
                                .font(AtlasFont.monoSmall)
                                .foregroundStyle(AtlasColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(AtlasColor.textPrimary)
                    .padding(.horizontal, AtlasSpacing.l)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .atlasP1Glass(
                        RoundedRectangle(cornerRadius: 16, style: .continuous),
                        interactive: true
                    )
                }
                .buttonStyle(.plain)

                if model.activeRole == .owner && model.canWriteActiveWorld {
                    auxiliaryHeroButton(symbol: "pencil", help: "编辑企划首页") {
                        model.activeSheet = .publicPageEditor
                    }
                } else if model.activeRole == .visitor && model.canWriteActiveWorld {
                    auxiliaryHeroButton(symbol: "person.badge.plus", help: "申请加入企划") {
                        model.activeSheet = .application
                    }
                }
            }
        }
        .padding(8)
    }

    private func auxiliaryHeroButton(
        symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AtlasColor.textPrimary)
                .frame(width: 58, height: 58)
                .atlasP1Glass(Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(PublicTab.allCases) { item in
                Button {
                    withAnimation(.snappy) { tab = item }
                } label: {
                    VStack(spacing: AtlasSpacing.s) {
                        Text(item.rawValue)
                            .font(AtlasFont.label)
                        Rectangle()
                            .fill(tab == item ? Color.white : Color.white.opacity(0.12))
                            .frame(height: 2)
                    }
                    .frame(width: 112)
                    .foregroundStyle(tab == item ? AtlasColor.textPrimary : AtlasColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, AtlasSpacing.xxl)
        .padding(.top, AtlasSpacing.l)
        .background(.ultraThinMaterial.opacity(0.28))
    }

    private var pageLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                tabBar
                selectedPage
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Divider().overlay(AtlasColor.borderSubtle)

            persistentInfoRail
                .frame(width: 320)
        }
        .background {
            GeometryReader { proxy in
                ZStack {
                    Image("PixabayBanner")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1.06)
                        .blur(radius: 16)

                    Color.black.opacity(0.18)

                    AtlasCanvasBackground()
                        .opacity(0.34)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
        }
        .clipped()
    }

    @ViewBuilder
    private var selectedPage: some View {
        switch tab {
        case .detail: publicDetail
        case .characters: characterGallery
        case .works: workGallery
        }
    }

    private var publicDetail: some View {
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
        .padding(AtlasSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var persistentInfoRail: some View {
        VStack(spacing: AtlasSpacing.m) {
            infoCard("AI 使用边界", symbol: "checkmark.shield", tint: AtlasColor.auroraMint) {
                policyRow("允许", detail: "灵感发散、资料整理、文本校对")
                policyRow("需标注", detail: "包含 AI 辅助的公开文本")
                policyRow("关闭", detail: "图片生成、改图、画风模仿")
            }

            infoCard("运营脉冲", symbol: "waveform.path.ecg", tint: AtlasColor.auroraAmber) {
                pulseRow("正在推进", detail: "潮汐回响 · 第二阶段")
                pulseRow("活动状态", detail: model.isActiveWorldArchived ? "已封存" : "持续进行")
                pulseRow("本周互动", detail: "42 次角色回应")
            }

            infoCard("最近变化", symbol: "clock.arrow.circlepath", tint: AtlasColor.auroraViolet) {
                changeRow("白塔封锁进入事件结算", time: "18 分钟前")
                changeRow("新增关系：第七码头临时同盟", time: "1 小时前")
                changeRow("AI 使用边界已确认", time: "今天 08:12")
            }
        }
        .padding(AtlasSpacing.l)
        .frame(maxHeight: .infinity, alignment: .top)
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

            HStack(alignment: .top, spacing: AtlasSpacing.l) {
                ForEach(0..<2, id: \.self) { column in
                    LazyVStack(alignment: .leading, spacing: AtlasSpacing.l) {
                        ForEach(
                            Array(AtlasAssetPreview.samples.enumerated())
                                .filter { $0.offset % 2 == column },
                            id: \.element.id
                        ) { _, work in
                            workCard(work)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .padding(AtlasSpacing.xxl)
    }

    private func workCard(_ work: AtlasAssetPreview) -> some View {
        Button {
            model.showToast("已打开作品「\(work.title)」")
        } label: {
            VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                AssetArtworkPreview(seed: work.seed, symbol: work.symbol)
                    .frame(height: work.featured ? 260 : 166)
                Text(work.title)
                    .font(AtlasFont.heading)
                Text("\(work.author) · \(work.type)")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func heroMetric(
        _ title: String,
        value: String,
        showsDivider: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AtlasColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .overlay(alignment: .trailing) {
            if showsDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.19))
                    .frame(width: 1)
                    .padding(.vertical, 14)
            }
        }
    }

    private func infoCard<Content: View>(
        _ title: String,
        symbol: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            Label(title, systemImage: symbol)
                .font(AtlasFont.heading)
                .foregroundStyle(tint)
            Divider().overlay(AtlasColor.borderSubtle)
            content()
        }
        .padding(AtlasSpacing.l)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .atlasP1Glass(
            RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous)
        )
    }

    private func pulseRow(_ label: String, detail: String) -> some View {
        HStack {
            Text(label).font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
            Spacer()
            Text(detail).font(AtlasFont.label)
        }
    }

    private func changeRow(_ title: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(AtlasFont.caption)
            Text(time).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
        }
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
            Image("PixabayBanner")
                .resizable()
                .scaledToFill()
            LinearGradient(
                colors: [.black.opacity(0.04), .black.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 9) {
                ForEach(0..<9, id: \.self) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color(red: 0.58, green: 0.72, blue: 0.61)
                                        .opacity(0.30 - Double(index) * 0.025),
                                    Color(red: 0.60, green: 0.42, blue: 0.55)
                                        .opacity(0.25 - Double(index) * 0.021),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.7)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .mask(
                LinearGradient(
                    colors: [.clear, .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .clipped()
    }
}

private struct MiniWorldStrip: View {
    @ObservedObject var model: AtlasAppModel

    var body: some View {
        HStack(spacing: AtlasSpacing.m) {
            ForEach(WorldObject.samples.prefix(4)) { object in
                Button {
                    model.selectedObjectID = object.id
                    model.navigate(to: .canvas)
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
                    .atlasP1Glass(
                        RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous),
                        interactive: true
                    )
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
        PixabayLandscape(seed: seed)
            .overlay(alignment: .bottomLeading) {
                Text(initials)
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundStyle(.white)
                    .padding(AtlasSpacing.m)
                    .shadow(color: .black.opacity(0.8), radius: 8)
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
        PixabayLandscape(seed: seed + 2)
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(AtlasSpacing.m)
                    .shadow(color: .black.opacity(0.7), radius: 7)
            }
        .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.card).stroke(AtlasColor.borderSubtle))
    }
}

private struct PixabayLandscape: View {
    let seed: Int

    private var imageName: String {
        let names = [
            "PixabayBanner",
            "PixabayLandscape2",
            "PixabayLandscape3",
            "PixabayLandscape4",
            "PixabayLandscape5",
            "PixabayLandscape6"
        ]
        return names[abs(seed) % names.count]
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .clipped()
    }
}
