import CryptoKit
import SwiftUI

private enum ProfileWorldStatusFilter: String, CaseIterable, Identifiable {
    case all = "全部状态"
    case warmup = "预热"
    case recruiting = "招募中"
    case ongoing = "进行中"
    case ended = "已结企"

    var id: String { rawValue }
}

struct ProfileView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var editing = false
    @State private var displayName = "岑"
    @State private var bio = "在尚未命名的海岸线上，替故事留下可以被找到的坐标。"
    @State private var selectedWork: ProfileWork?
    @State private var worldMintStates: [String: AtlasNFTMintState] = [:]
    @State private var statusFilter: ProfileWorldStatusFilter = .all

    private var isOwnProfile: Bool {
        model.selectedProfileUserID == model.currentUserID
    }

    private var viewedIdentity: (name: String, avatarSeed: Int) {
        model.profileIdentity(for: model.selectedProfileUserID)
    }

    private var managedWorlds: [AtlasWorld] {
        model.worlds.filter { model.role(in: $0.id) == .owner }
    }

    private var joinedWorlds: [AtlasWorld] {
        model.worlds.filter { model.role(in: $0.id) == .participant }
    }

    var body: some View {
        ZStack {
            AtlasCanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 42) {
                    profileHero
                    introduction
                    collections
                    worldFootprints
                }
                .frame(maxWidth: 1180)
                .padding(.horizontal, 54)
                .padding(.top, 34)
                .padding(.bottom, 140)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $selectedWork) { work in
            ProfileWorkSheet(model: model, work: work)
        }
    }

    private var profileHero: some View {
        ZStack(alignment: .bottomLeading) {
            Image(profileImageName(for: 4))
                .resizable()
                .scaledToFill()
                .frame(height: 380)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.18),
                    .init(color: .black.opacity(0.22), location: 0.48),
                    .init(color: .black.opacity(0.72), location: 0.74),
                    .init(color: .black.opacity(0.94), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                HStack(alignment: .bottom, spacing: AtlasSpacing.l) {
                    avatar
                    VStack(alignment: .leading, spacing: 5) {
                        if editing {
                            TextField("显示名称", text: $displayName)
                                .textFieldStyle(.plain)
                                .font(AtlasFont.display)
                                .frame(maxWidth: 280)
                        } else {
                            Text(isOwnProfile ? displayName : viewedIdentity.name)
                                .font(AtlasFont.display)
                        }
                        Text(isOwnProfile ? "@cen" : "@\(model.selectedProfileUserID.replacingOccurrences(of: "user-", with: ""))")
                            .font(AtlasFont.mono)
                            .foregroundStyle(Color.white.opacity(0.60))
                    }
                    Spacer()
                    if isOwnProfile {
                        modeButton
                    }
                }

                HStack(spacing: 0) {
                    profileMetric("管理世界", "\(managedWorlds.count)")
                    profileMetric("加入世界", "\(joinedWorlds.count)")
                    profileMetric("公开作品", "18")
                    profileMetric("共同创作", "06")
                }
            }
            .padding(AtlasSpacing.xl)
        }
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .atlasP1Glass(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AtlasColor.auroraRose, AtlasColor.auroraViolet],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(String((isOwnProfile ? displayName : viewedIdentity.name).prefix(1)))
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 82, height: 82)
        .overlay(Circle().stroke(Color.white.opacity(0.66), lineWidth: 1))
        .shadow(color: AtlasColor.auroraViolet.opacity(0.32), radius: 22, y: 8)
    }

    private var modeButton: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                editing.toggle()
            }
        } label: {
            Label(editing ? "完成编辑" : "编辑主页", systemImage: editing ? "checkmark" : "pencil")
                .font(AtlasFont.label)
                .padding(.horizontal, AtlasSpacing.l)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
        .atlasP1Glass(Capsule(), interactive: true)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            HStack(spacing: AtlasSpacing.s) {
                profileTag("世界观创作者")
                profileTag("角色与叙事设计")
                profileTag("长期企划")
            }

            if editing {
                TextField("写一句个人介绍", text: $bio, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AtlasFont.serifBody)
            } else {
                Text(bio)
                    .font(AtlasFont.serifBody)
                    .foregroundStyle(AtlasColor.textPrimary.opacity(0.90))
                    .lineSpacing(7)
            }

            Text("我偏爱缓慢生长的共同世界、带有地理质感的叙事，以及允许每位参与者留下痕迹的创作关系。这里收藏着我参与过的企划和仍在持续发生的作品。")
                .font(AtlasFont.body)
                .foregroundStyle(AtlasColor.textSecondary)
                .lineSpacing(6)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: 860, alignment: .leading)
    }

    private var collections: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            sectionHeading("作品收藏夹", subtitle: "2 个收藏夹 · 6 个作品")

            collectionRow(
                title: "企划记录",
                subtitle: "正在维护与参与的共同世界",
                worlds: Array((managedWorlds + joinedWorlds).prefix(3)),
                seeds: [1, 5, 3]
            )

            workCollectionRow
        }
    }

    private var worldFootprints: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeading("企划足迹", subtitle: "作为企主或参企者留下的公开记录")
                statusFilterMenu
            }

            if !certifiedWorlds.isEmpty {
                certifiedWorldSection
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 250), spacing: AtlasSpacing.m)],
                spacing: AtlasSpacing.m
            ) {
                ForEach(Array(filteredFootprintWorlds.enumerated()), id: \.element.id) { index, world in
                    footprintCardContent(world: world, index: index)
                    .padding(AtlasSpacing.l)
                    .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
                    .atlasChromaticGlass(
                        RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous),
                        tint: index.isMultiple(of: 2) ? AtlasColor.auroraViolet : AtlasColor.auroraMint
                    )
                    .contentShape(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
                    .onTapGesture { model.openWorld(world) }
                }
            }
        }
    }

    private var certifiedWorlds: [AtlasWorld] {
        managedWorlds.filter { model.certifiedWorldHashes[$0.id] != nil }
    }

    private var regularFootprintWorlds: [AtlasWorld] {
        (managedWorlds + joinedWorlds).filter { world in
            !certifiedWorlds.contains(where: { $0.id == world.id })
        }
    }

    private var filteredFootprintWorlds: [AtlasWorld] {
        regularFootprintWorlds
            .filter { statusFilter == .all || $0.status == statusFilter.rawValue }
            .sorted {
                let lhs = statusRank($0.status)
                let rhs = statusRank($1.status)
                return lhs == rhs ? $0.name.localizedCompare($1.name) == .orderedAscending : lhs < rhs
            }
    }

    private var statusFilterMenu: some View {
        Menu {
            ForEach(ProfileWorldStatusFilter.allCases) { filter in
                Button {
                    statusFilter = filter
                } label: {
                    if statusFilter == filter {
                        Label(filter.rawValue, systemImage: "checkmark")
                    } else {
                        Text(filter.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(statusFilter.rawValue)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(AtlasFont.monoSmall)
            .padding(.horizontal, AtlasSpacing.m)
            .frame(height: 34)
            .atlasP1Glass(Capsule(), interactive: true)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var certifiedWorldSection: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            Label("已归档认证企划", systemImage: "checkmark.seal")
                .font(AtlasFont.heading)
                .foregroundStyle(AtlasColor.auroraMint)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 250), spacing: AtlasSpacing.m)],
                spacing: AtlasSpacing.m
            ) {
                ForEach(certifiedWorlds) { world in
                    Button { model.openWorld(world) } label: {
                        ZStack {
                            VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                                HStack {
                                    Text("企主发起 · 已结企").font(AtlasFont.monoSmall)
                                    Spacer()
                                }
                                Text(world.name).font(AtlasFont.display)
                                Text(world.hook)
                                    .font(AtlasFont.caption)
                                    .foregroundStyle(AtlasColor.textSecondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if let hash = model.certifiedWorldHashes[world.id] {
                                CertifiedHashWatermark(hash: hash)
                            }
                        }
                        .padding(AtlasSpacing.l)
                        .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
                        .atlasChromaticGlass(
                            RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous),
                            tint: AtlasColor.auroraMint,
                            interactive: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func footprintCardContent(world: AtlasWorld, index: Int) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            HStack {
                Text(model.role(in: world.id) == .owner ? "企主" : "参企者")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textSecondary)
                Spacer()
                Text(world.status)
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
                if isCertifiable(world) {
                    certificationAction(for: world)
                }
            }
            Text(world.name).font(AtlasFont.heading)
            HStack(spacing: 0) {
                footprintMetric("共同创作者", "\(5 + index * 2)")
                footprintMetric("参与者", "\(world.members)")
                footprintMetric("状态", world.status)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func certificationAction(for world: AtlasWorld) -> some View {
        switch worldMintStates[world.id] ?? .idle {
        case .preparing:
            certificationProgress("正在封存企划档案…")
        case .submitting:
            certificationProgress("正在认证企划…")
        case .confirmed:
            EmptyView()
        case .idle, .failed:
            Button {
                Task { await certify(world) }
            } label: {
                Text("归档认证")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 9)
                    .frame(height: 25)
            }
            .buttonStyle(.plain)
            .atlasP1Glass(Capsule(), interactive: true)
        }
    }

    private func certificationProgress(_ title: String) -> some View {
        HStack(spacing: AtlasSpacing.s) {
            ProgressView().controlSize(.small)
            Text(title).font(AtlasFont.caption)
        }
        .foregroundStyle(AtlasColor.textSecondary)
        .padding(.horizontal, 9)
        .frame(height: 25)
        .atlasP1Glass(Capsule())
    }

    private func isCertifiable(_ world: AtlasWorld) -> Bool {
        isOwnProfile &&
            model.role(in: world.id) == .owner &&
            world.status == "已结企" &&
            model.certifiedWorldHashes[world.id] == nil
    }

    private func statusRank(_ status: String) -> Int {
        switch status {
        case "预热": 0
        case "招募中": 1
        case "进行中": 2
        case "已结企": 3
        default: 4
        }
    }

    @MainActor
    private func certify(_ world: AtlasWorld) async {
        guard isCertifiable(world) else { return }
        worldMintStates[world.id] = .preparing
        try? await Task.sleep(for: .milliseconds(520))
        worldMintStates[world.id] = .submitting

        do {
            let manifest = "\(world.id)|\(world.name)|\(world.hook)|\(world.status)|\(world.members)"
            let digest = SHA256.hash(data: Data(manifest.utf8))
            let contentHash = digest.map { String(format: "%02x", $0) }.joined()
            let receipt = try await AtlasNFTMintService.shared.mint(
                workID: "atlas-project-\(world.id)",
                projectID: stableProjectID(world.name),
                creatorAddress: "0x0A87426C3E3c7B79F1fD4E2e8B3e0D9a2f5c7B01",
                contentHash: contentHash
            )
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                worldMintStates[world.id] = .confirmed(receipt)
                model.certifyWorld(world.id, transactionHash: receipt.transactionHash)
            }
        } catch {
            worldMintStates[world.id] = .failed(error.localizedDescription)
        }
    }

    private func stableProjectID(_ name: String) -> Int {
        abs(name.unicodeScalars.reduce(17) { ($0 &* 31) &+ Int($1.value) }) % 10_000 + 1
    }

    private func collectionRow(
        title: String,
        subtitle: String,
        worlds: [AtlasWorld],
        seeds: [Int]
    ) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(AtlasFont.heading)
                    Text(subtitle).font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer()
                Button("查看全部") {
                    model.showWorldCollection(title == "企划记录" ? .managed : .joined)
                }
                .buttonStyle(.plain)
                .font(AtlasFont.label)
                .foregroundStyle(AtlasColor.textSecondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AtlasSpacing.m), count: 3), spacing: AtlasSpacing.m) {
                ForEach(Array(worlds.enumerated()), id: \.element.id) { index, world in
                    Button { model.openWorld(world) } label: {
                        ZStack(alignment: .bottomLeading) {
                            Image(profileImageName(for: seeds[index % seeds.count]))
                                .resizable()
                                .scaledToFill()
                                .frame(height: 182)
                                .clipped()
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.92)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(world.name).font(AtlasFont.heading)
                                Text(world.status)
                                    .font(AtlasFont.monoSmall)
                                    .foregroundStyle(Color.white.opacity(0.62))
                            }
                            .padding(AtlasSpacing.l)
                        }
                        .frame(height: 182)
                        .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
                        .atlasGlass(
                            RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous),
                            clear: true,
                            interactive: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AtlasSpacing.xl)
        .atlasP1Glass(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var workCollectionRow: some View {
        let works = ProfileWork.samples
        return VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("角色与短篇").font(AtlasFont.heading)
                    Text("角色档案、插画与叙事实验")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer()
                Text("\(works.count) 个作品")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AtlasSpacing.m), count: 3),
                spacing: AtlasSpacing.m
            ) {
                ForEach(works) { work in
                    Button { selectedWork = work } label: {
                        ProfileWorkCard(work: work)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AtlasSpacing.xl)
        .atlasP1Glass(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(AtlasFont.display)
            Spacer()
            Text(subtitle).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
        }
    }

    private func profileTag(_ text: String) -> some View {
        Text("# \(text)")
            .font(AtlasFont.caption)
            .foregroundStyle(AtlasColor.textSecondary)
            .padding(.horizontal, AtlasSpacing.m)
            .frame(height: 34)
            .atlasGlass(Capsule(), clear: true)
    }

    private func profileMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 20, weight: .semibold, design: .monospaced))
            Text(title).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func footprintMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(AtlasFont.label)
            Text(title).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileImageName(for seed: Int) -> String {
        let images = [
            "PixabayBanner",
            "PixabayLandscape2",
            "PixabayLandscape3",
            "PixabayLandscape4",
            "PixabayLandscape5",
            "PixabayLandscape6"
        ]
        return images[abs(seed) % images.count]
    }
}

private struct ProfileWork: Identifiable {
    enum Kind: Equatable { case image, text, character }

    let id: Int
    let title: String
    let author: String
    let body: String
    let seed: Int
    let kind: Kind
    let worldName: String?

    static let samples: [ProfileWork] = [
        .init(
            id: 1,
            title: "白昼 · 外来调查者",
            author: "@daylight",
            body: "沿着退潮后显露的石阶追查一批从未抵达收件人的旧信。",
            seed: 4,
            kind: .character,
            worldName: "雾海来信"
        ),
        .init(
            id: 2,
            title: "第七码头的灯",
            author: "@cen",
            body: "灯火沿着退潮后的石阶依次亮起，像一封迟到许多年的回信。",
            seed: 1,
            kind: .image,
            worldName: "雾海来信"
        ),
        .init(
            id: 3,
            title: "潮汐以前 · 序章",
            author: "@cen",
            body: "潮汐尚未来临以前，白塔每天在同一时刻熄灯。没有人知道守塔人去了哪里，只剩下写到一半的航海日志。第一页反复提到一座不存在于星图上的岛，以及一封尚未寄出的信。",
            seed: 3,
            kind: .text,
            worldName: nil
        )
    ]
}

private struct ProfileWorkCard: View {
    let work: ProfileWork

    var body: some View {
        Group {
            if work.kind == .text {
                VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                    Text("纯文本")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                    Text(work.title).font(AtlasFont.heading)
                    Text(work.body)
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(4)
                    Spacer(minLength: 0)
                    Text(work.author).font(AtlasFont.monoSmall)
                }
                .padding(AtlasSpacing.l)
                .frame(maxWidth: .infinity, minHeight: 182, maxHeight: 182, alignment: .leading)
                .atlasGlass(
                    RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous),
                    clear: true,
                    interactive: true
                )
            } else {
                ZStack(alignment: .bottomLeading) {
                    Image(profileWorkImageName(for: work.seed))
                        .resizable()
                        .scaledToFill()
                        .frame(height: 182)
                        .clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(work.title).font(AtlasFont.heading)
                        Text(work.author).font(AtlasFont.monoSmall)
                    }
                    .padding(AtlasSpacing.l)
                }
                .frame(height: 182)
                .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
                .atlasGlass(
                    RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous),
                    clear: true,
                    interactive: true
                )
            }
        }
    }

    private func profileWorkImageName(for seed: Int) -> String {
        ["PixabayBanner", "PixabayLandscape2", "PixabayLandscape3", "PixabayLandscape4", "PixabayLandscape5", "PixabayLandscape6"][abs(seed) % 6]
    }
}

private struct ProfileWorkSheet: View {
    @ObservedObject var model: AtlasAppModel
    let work: ProfileWork
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(work.title).font(AtlasFont.display)
                    Text(work.author).font(AtlasFont.mono).foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.atlas(.glass))
            }

            if work.kind == .text {
                Text(work.body)
                    .font(AtlasFont.serifBody)
                    .foregroundStyle(AtlasColor.textPrimary.opacity(0.90))
                    .lineSpacing(8)
                    .frame(maxWidth: 720, alignment: .leading)
            } else {
                Image(["PixabayBanner", "PixabayLandscape2", "PixabayLandscape3", "PixabayLandscape4", "PixabayLandscape5", "PixabayLandscape6"][abs(work.seed) % 6])
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
            }

            if let worldName = work.worldName {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("隶属企划").font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                        Text(worldName).font(AtlasFont.label)
                    }
                    Spacer()
                    Button {
                        if let world = model.worlds.first(where: { $0.name == worldName }) {
                            dismiss()
                            model.openWorld(world)
                        } else {
                            model.showToast("对应企划暂未载入")
                        }
                    } label: {
                        AtlasButtonLabel(title: "前往企划", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(.atlas(.glass))
                }
                .padding(AtlasSpacing.l)
                .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
            }

        }
        .padding(AtlasSpacing.xxl)
        .frame(minWidth: 720, minHeight: 560)
        .background(AtlasCanvasBackground())
    }

}

private struct CertifiedHashWatermark: View {
    let hash: String

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                watermarkLine
                    .offset(x: -18, y: -24)
                watermarkLine
                    .offset(x: 12, y: 34)
                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .medium))
                    .opacity(0.10)
                    .position(x: proxy.size.width - 24, y: 24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
    }

    private var watermarkLine: some View {
        Text(hash + "  " + hash)
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.12))
            .lineLimit(1)
            .fixedSize()
            .rotationEffect(.degrees(11))
    }
}
