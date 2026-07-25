import SwiftUI

struct PublicProjectView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var tab = PublicTab.detail
    @State private var selectedWork: AtlasAssetPreview?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    pageLayout
                }
            }
            .background(AtlasCanvasBackground())

            if let selectedWork {
                workLightbox(selectedWork)
                    .zIndex(200)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: selectedWork?.id)
        .ignoresSafeArea(.container, edges: .top)
        .background(AtlasCanvasBackground())
        .overlay(alignment: .topLeading) {
            exitButton
                .padding(.top, 24)
                .padding(.leading, 24)
        }
    }

    private var exitButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.32)) {
                model.navigate(to: .discover)
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AtlasColor.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .atlasP1Glass(Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .help("退出企划详情")
    }

    private var hero: some View {
        ZStack {
            PublicWorldArtwork()
                .frame(height: 500)
                .allowsHitTesting(false)
                .zIndex(0)

            heroBottomFade
                .frame(height: 500)
                .allowsHitTesting(false)
                .zIndex(1)
        }
        .frame(height: 500)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            heroDock
                .padding(.horizontal, 32)
                .padding(.bottom, 22)
                .contentShape(Rectangle())
        }
        .zIndex(20)
    }

    /// 渐变以可见 Hero 的底边（即下方内容区顶部）为终点，
    /// 不跟随 scaledToFill 后超出裁剪区的图片尺寸。
    private var heroBottomFade: some View {
        Color.black.opacity(0.90)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .clear, location: 0.40),
                        .init(color: .white.opacity(0.04), location: 0.45),
                        .init(color: .white.opacity(0.16), location: 0.52),
                        .init(color: .white.opacity(0.36), location: 0.62),
                        .init(color: .white.opacity(0.62), location: 0.74),
                        .init(color: .white.opacity(0.84), location: 0.87),
                        .init(color: .white, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
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
                    model.enterCanvas()
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
                    .contentShape(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

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
                .zIndex(10)
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
                .zIndex(10)
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

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 236),
                        spacing: AtlasSpacing.xl,
                        alignment: .top
                    )
                ],
                alignment: .leading,
                spacing: AtlasSpacing.l
            ) {
                ForEach(PublicCharacter.samples) { character in
                    Button {
                        model.showToast("已打开 \(character.name) 的角色档案")
                    } label: {
                        PublicCharacterPortrait(
                            seed: character.seed,
                            role: character.role,
                            name: character.name
                        )
                        .frame(width: 236, height: 320)
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

            HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                ForEach(0..<3, id: \.self) { column in
                    LazyVStack(alignment: .leading, spacing: AtlasSpacing.l) {
                        ForEach(
                            Array(AtlasAssetPreview.samples.enumerated())
                                .filter { $0.offset % 3 == column },
                            id: \.element.id
                        ) { _, work in
                            LibraryWorkCard(work: work) {
                                selectedWork = work
                            }
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .padding(AtlasSpacing.xxl)
    }

    private func workLightbox(_ work: AtlasAssetPreview) -> some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .onTapGesture { selectedWork = nil }

            VStack(spacing: AtlasSpacing.l) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(work.title)
                            .font(AtlasFont.title)
                        Text("@\(work.author) · \(work.type)")
                            .font(AtlasFont.caption)
                            .foregroundStyle(AtlasColor.textSecondary)
                    }
                    Spacer()
                    Button {
                        selectedWork = nil
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 42, height: 42)
                            .atlasP1Glass(Circle(), interactive: true)
                    }
                    .buttonStyle(.plain)
                }

                if work.kind == .text {
                    ScrollView {
                        Text(work.body)
                            .font(.system(size: 17))
                            .lineSpacing(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    AssetArtworkPreview(seed: work.seed, symbol: work.symbol)
                        .aspectRatio(16 / 10, contentMode: .fit)
                }
            }
            .padding(AtlasSpacing.xl)
            .frame(maxWidth: 920, maxHeight: 680)
            .atlasFloatingGlass(
                RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous)
            )
            .padding(48)
        }
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
        .atlasFloatingGlass(
            RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous)
        )
    }

    private func pulseRow(_ label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textTertiary)
            Text(detail)
                .font(AtlasFont.label)
                .foregroundStyle(AtlasColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .atlasFloatingGlass(
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
    let seed: Int

    static let samples = [
        PublicCharacter(id: 1, name: "岑", role: "档案修复师", location: "雾港", seed: 1),
        PublicCharacter(id: 2, name: "伊莱", role: "领航员", location: "白塔", seed: 2),
        PublicCharacter(id: 3, name: "白昼", role: "外来调查者", location: "第七码头", seed: 3),
        PublicCharacter(id: 4, name: "阿芙拉", role: "雾海信使", location: "北岸", seed: 4)
    ]
}

private struct PublicCharacterPortrait: View {
    var seed: Int
    var role: String
    var name: String
    @State private var hovering = false

    var body: some View {
        GeometryReader { proxy in
            PixabayLandscape(seed: seed)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay {
                    Color.black.opacity(0.90)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.00),
                                    .init(color: .clear, location: 0.42),
                                    .init(color: .white.opacity(0.08), location: 0.50),
                                    .init(color: .white.opacity(0.28), location: 0.62),
                                    .init(color: .white.opacity(0.58), location: 0.76),
                                    .init(color: .white.opacity(0.84), location: 0.90),
                                    .init(color: .white, location: 1.00)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(role)
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(Color.white.opacity(0.68))
                        Text(name)
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(AtlasSpacing.l)
                    .shadow(color: .black.opacity(0.75), radius: 8, y: 2)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous)
                .stroke(
                    Color.white.opacity(hovering ? 0.42 : 0.20),
                    lineWidth: hovering ? 1.2 : 1
                )
        }
        .shadow(
            color: .black.opacity(hovering ? 0.46 : 0.22),
            radius: hovering ? 24 : 12,
            y: hovering ? 14 : 7
        )
        .scaleEffect(hovering ? 1.025 : 1)
        .offset(y: hovering ? -6 : 0)
        .contentShape(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
        .onHover { hovering = $0 }
        .animation(
            .spring(response: 0.38, dampingFraction: 0.78),
            value: hovering
        )
    }
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
    enum Kind: Equatable {
        case titledMedia
        case pureMedia
        case portraitMedia
        case text
        case untitledVideo
    }

    let id: Int
    let title: String
    let author: String
    let type: String
    let seed: Int
    let symbol: String
    let featured: Bool
    let kind: Kind
    let body: String

    static let samples = [
        AtlasAssetPreview(id: 1, title: "第七码头的灯", author: "白雀", type: "插画", seed: 1, symbol: "light.beacon.max", featured: true, kind: .titledMedia, body: "灯火沿着退潮后的石阶依次亮起，像一封迟到许多年的回信。"),
        AtlasAssetPreview(id: 2, title: "雾中信使", author: "秋庭", type: "纯图", seed: 2, symbol: "figure.walk", featured: false, kind: .pureMedia, body: ""),
        AtlasAssetPreview(id: 3, title: "潮汐以前 · 序章", author: "林雾", type: "短篇", seed: 3, symbol: "doc.text", featured: false, kind: .text, body: "潮汐尚未来临以前，白塔每天在同一时刻熄灯。没有人知道守塔人去了哪里，只剩下写到一半的航海日志。第一页反复提到一座不存在于星图上的岛，以及一封尚未寄出的信。"),
        AtlasAssetPreview(id: 4, title: "远岸以北", author: "岛屿", type: "无标题影像", seed: 4, symbol: "play.fill", featured: false, kind: .untitledVideo, body: ""),
        AtlasAssetPreview(id: 5, title: "潮生处", author: "迟屿", type: "竖幅纯图", seed: 5, symbol: "photo", featured: false, kind: .portraitMedia, body: "")
    ]
}

private struct LibraryWorkCard: View {
    let work: AtlasAssetPreview
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous)

        Button(action: action) {
            Group {
                if work.kind == .text {
                    VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                        Text(work.title)
                            .font(.system(size: 25, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 1)
                        Text(work.body)
                            .font(AtlasFont.body)
                            .foregroundStyle(AtlasColor.textSecondary)
                            .lineSpacing(6)
                            .lineLimit(4, reservesSpace: true)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        Text("@\(work.author)")
                            .font(AtlasFont.caption)
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                    .padding(AtlasSpacing.l)
                    .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
                    .atlasFloatingGlass(
                        cardShape,
                        interactive: true
                    )
                } else {
                    GeometryReader { proxy in
                        ZStack {
                            Image(PixabayLandscape.imageName(for: work.seed + 2))
                                .resizable()
                                .scaledToFit()
                                .frame(width: proxy.size.width, height: proxy.size.height)

                            if work.kind == .titledMedia {
                                Color.black.opacity(0.90)
                                    .mask {
                                        LinearGradient(
                                            stops: [
                                                .init(color: .clear, location: 0.38),
                                                .init(color: .white.opacity(0.10), location: 0.48),
                                                .init(color: .white.opacity(0.48), location: 0.72),
                                                .init(color: .white, location: 1.00)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    }
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }

                            if work.kind == .titledMedia {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(work.type)
                                        .font(AtlasFont.monoSmall)
                                        .foregroundStyle(Color.white.opacity(0.68))
                                    Text(work.title)
                                        .font(AtlasFont.heading)
                                        .foregroundStyle(.white)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("@\(work.author)")
                                        .font(AtlasFont.caption)
                                        .foregroundStyle(Color.white.opacity(0.72))
                                }
                                .padding(AtlasSpacing.l)
                                .frame(
                                    width: proxy.size.width,
                                    height: proxy.size.height,
                                    alignment: .bottomLeading
                                )
                            }

                            if work.kind == .untitledVideo {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 54, height: 54)
                                    .atlasP1Glass(Circle())
                            }

                            if work.kind != .titledMedia {
                                Text("@\(work.author)")
                                    .font(AtlasFont.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .shadow(color: .black, radius: 7, y: 2)
                                    .padding(AtlasSpacing.s)
                                    .frame(
                                        width: proxy.size.width,
                                        height: proxy.size.height,
                                        alignment: .bottomLeading
                                    )
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    .aspectRatio(
                        PixabayLandscape.aspectRatio(for: work.seed + 2),
                        contentMode: .fit
                    )
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .clipShape(cardShape)
            .overlay {
                cardShape
                    .stroke(Color.white.opacity(hovering ? 0.34 : 0.16), lineWidth: 1)
            }
            .contentShape(cardShape)
            .scaleEffect(hovering ? 1.006 : 1)
            .offset(y: hovering ? -5 : 0)
            .shadow(color: .black.opacity(hovering ? 0.46 : 0.20), radius: hovering ? 24 : 12, y: hovering ? 13 : 6)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 0, maxWidth: .infinity)
        .zIndex(hovering ? 2 : 0)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.38, dampingFraction: 0.80), value: hovering)
    }
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

    private static let images: [(name: String, ratio: CGFloat)] = [
        ("PixabayBanner", 1280 / 720),
        ("PixabayLandscape2", 1280 / 797),
        ("PixabayLandscape3", 1280 / 873),
        ("PixabayLandscape4", 1280 / 720),
        ("PixabayLandscape5", 1280 / 853),
        ("PixabayLandscape6", 1280 / 854)
    ]

    static func imageName(for seed: Int) -> String {
        images[abs(seed) % images.count].name
    }

    static func aspectRatio(for seed: Int) -> CGFloat {
        images[abs(seed) % images.count].ratio
    }

    private var imageName: String {
        Self.imageName(for: seed)
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .clipped()
    }
}
