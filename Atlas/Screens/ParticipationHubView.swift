import SwiftUI

struct ParticipationHubView: View {
    enum Section: String, CaseIterable, Identifiable {
        case board = "任务布告栏"
        case forum = "企划论坛"
        case characters = "OC 互动"

        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .board: "pin"
            case .forum: "bubble.left.and.bubble.right"
            case .characters: "person.2.crop.square.stack"
            }
        }
        var subtitle: String {
            switch self {
            case .board: "接受企主发布的任务"
            case .forum: "进入不同板块发帖与交流"
            case .characters: "浏览其他人的 OC 并发起创作"
            }
        }
    }

    @ObservedObject var model: AtlasAppModel
    @State private var section: Section = .board
    @State private var showsContributionDetail = false
    @Namespace private var sectionSelection

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ProjectBreadcrumb(model: model, pageName: AtlasDestination.tasks.rawValue)

                HStack(spacing: AtlasSpacing.s) {
                ForEach(Section.allCases) { item in
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            section = item
                        }
                    } label: {
                        HStack(spacing: AtlasSpacing.s) {
                            Image(systemName: item.symbol)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.rawValue).font(AtlasFont.label)
                                Text(item.subtitle).font(AtlasFont.monoSmall)
                            }
                        }
                        .foregroundStyle(section == item ? AtlasColor.inverse : AtlasColor.textSecondary)
                        .padding(.horizontal, AtlasSpacing.m)
                        .padding(.vertical, 9)
                        .background {
                            if section == item {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white)
                                    .matchedGeometryEffect(id: "section-selection", in: sectionSelection)
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        showsContributionDetail = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("您在本企划中的贡献度")
                            .foregroundStyle(AtlasColor.textTertiary)
                        Text(contributionText(model.activeContributionScore))
                            .foregroundStyle(AtlasColor.textPrimary)
                    }
                    .font(AtlasFont.monoSmall)
                    .padding(.horizontal, AtlasSpacing.m)
                    .frame(height: 32)
                    .atlasP1Glass(Capsule(), interactive: true)
                }
                .buttonStyle(.plain)
                .padding(.trailing, AtlasSpacing.l)

                Text(model.isActiveWorldArchived
                     ? "已结企 · 封存浏览"
                     : (model.activeRole == .visitor ? "游客 · 只读" : model.activeRole.rawValue))
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
                }
                .padding(.horizontal, AtlasSpacing.xl)
                .padding(.vertical, AtlasSpacing.m)
                .background(Color.black.opacity(0.46))

                Divider().overlay(AtlasColor.borderSubtle)

                ZStack {
                    switch section {
                    case .board:
                        TaskNoticeBoardView(model: model)
                            .transition(.opacity.combined(with: .scale(scale: 0.995)))
                    case .forum:
                        ProjectForumView(model: model)
                            .transition(.opacity.combined(with: .scale(scale: 0.995)))
                    case .characters:
                        OCInteractionView(model: model)
                            .transition(.opacity.combined(with: .scale(scale: 0.995)))
                    }
                }
                .animation(.easeInOut(duration: 0.24), value: section)
            }

            if showsContributionDetail {
                contributionDetailLightbox
                    .zIndex(100)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .background(AtlasCanvasBackground(animated: true))
    }

    private func contributionText(_ score: Double) -> String {
        score.rounded() == score ? "\(Int(score))" : String(format: "%.1f", score)
    }

    private var contributionDetailLightbox: some View {
        let contributor = model.contributors(in: model.activeWorldID)
            .first(where: { $0.id == model.currentUserID })
        let moduleScores = contributor?.moduleScores
            .sorted(by: { $0.key.rawValue < $1.key.rawValue }) ?? []

        return ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showsContributionDetail = false
                    }
                }

            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("您在本企划中的贡献度")
                            .font(AtlasFont.title)
                        Text(model.activeWorld.name)
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                    Spacer()
                    Text(contributionText(model.activeContributionScore))
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                }

                Divider().overlay(AtlasColor.borderSubtle)

                if moduleScores.isEmpty {
                    Text("还没有可计分的互动创作。完成一次符合规则的投稿后，明细会显示在这里。")
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textSecondary)
                } else {
                    ForEach(moduleScores, id: \.key) { module, score in
                        HStack {
                            Text(module.rawValue).font(AtlasFont.label)
                            Spacer()
                            Text(contributionText(score))
                                .font(AtlasFont.mono)
                                .foregroundStyle(AtlasColor.textSecondary)
                        }
                    }
                }

                Text("分数仅在当前企划内累计，并按同一对象的连续投稿次数应用递减系数。")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .padding(AtlasSpacing.xl)
            .frame(width: 470)
            .atlasFloatingGlass(
                RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous)
            )
            .onTapGesture { }
        }
    }
}

/// Persistent project context for pages that can be opened from cross-project surfaces.
struct ProjectBreadcrumb: View {
    @ObservedObject var model: AtlasAppModel
    let pageName: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: model.activeWorld.symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AtlasColor.textSecondary)
            Text("《\(model.activeWorld.name)》")
                .font(AtlasFont.label)
                .foregroundStyle(AtlasColor.textPrimary)
            Text("·")
                .foregroundStyle(AtlasColor.textTertiary)
            Text(pageName)
                .font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AtlasSpacing.xl)
        .padding(.vertical, AtlasSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.32))
        .overlay(alignment: .bottom) {
            Rectangle().fill(AtlasColor.borderSubtle).frame(height: 0.5)
        }
    }
}

private struct TaskNoticeBoardView: View {
    @ObservedObject var model: AtlasAppModel

    private var boardHeight: CGFloat {
        let rowCount = max(1, Int(ceil(Double(availableTasks.count) / 4.0)))
        return 440 + CGFloat(rowCount - 1) * 266
    }

    private var availableTasks: [AtlasTask] {
        model.tasks.filter { $0.state == .open && !model.joinedTaskIDs.contains($0.id) }
    }

    private var acceptedTasks: [AtlasTask] {
        model.tasks.filter { model.joinedTaskIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("企划任务布告栏").font(AtlasFont.title)
                        Text((model.activeRole == .participant || model.activeRole == .owner) &&
                             model.canWriteActiveWorld
                             ? "点击便利贴，把布告揭下来，即表示接受任务。"
                             : "企主与参企者都可以揭下任务；已结企后布告栏仅供浏览。")
                            .font(AtlasFont.body)
                            .foregroundStyle(AtlasColor.textSecondary)
                    }
                    Spacer()
                    if model.activeRole == .owner && model.canWriteActiveWorld {
                        Button {
                            model.activeSheet = .newTask
                        } label: {
                            AtlasButtonLabel(title: "贴一张新布告", systemImage: "pin")
                        }
                        .buttonStyle(.atlas(.primary))
                    }
                }

                ZStack {
                    if availableTasks.isEmpty {
                        VStack(spacing: AtlasSpacing.m) {
                            Image(systemName: "pin.slash")
                                .font(.system(size: 30, weight: .light))
                            Text("布告都已经被揭下").font(AtlasFont.heading)
                            Text("已承接任务在布告栏下方。")
                                .font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                        }
                    } else {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(minimum: 200), spacing: 30),
                                count: 4
                            ),
                            spacing: 36
                        ) {
                            ForEach(Array(availableTasks.enumerated()), id: \.element.id) { index, task in
                                TaskStickyNote(
                                    task: task,
                                    index: index,
                                    canAccept: (model.activeRole == .participant || model.activeRole == .owner) &&
                                        model.canWriteActiveWorld
                                ) {
                                    withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                                        model.joinTask(task)
                                    }
                                }
                            }
                        }
                        .padding(42)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: boardHeight)
                .animation(.spring(response: 0.44, dampingFraction: 0.86), value: boardHeight)
                .background {
                    AtlasCanvasBackground(animated: true)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .atlasFloatingGlass(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                )

                VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                    HStack {
                        Label("已承接的任务", systemImage: "tray.full")
                            .font(AtlasFont.heading)
                        Text("\(acceptedTasks.count)")
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                    }

                    if acceptedTasks.isEmpty {
                        Text("从上方揭下一张任务布告后，会在这里形成可持续追踪的任务卡。")
                            .font(AtlasFont.body)
                            .foregroundStyle(AtlasColor.textTertiary)
                            .padding(AtlasSpacing.xl)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.card))
                    } else {
                        ForEach(acceptedTasks) { task in
                            HStack(alignment: .top, spacing: AtlasSpacing.l) {
                                Image(systemName: "pin.fill")
                                    .foregroundStyle(AtlasColor.auroraAmber)
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(task.title).font(AtlasFont.heading)
                                        Text("已承接")
                                            .font(AtlasFont.monoSmall)
                                            .foregroundStyle(AtlasColor.auroraMint)
                                    }
                                    Text(task.summary)
                                        .font(AtlasFont.body)
                                        .foregroundStyle(AtlasColor.textSecondary)
                                    Text("关联对象：\(task.objectIDs.joined(separator: " · "))")
                                        .font(AtlasFont.monoSmall)
                                        .foregroundStyle(AtlasColor.textTertiary)
                                }
                                Spacer()
                                if model.canWriteActiveWorld {
                                    Button {
                                        model.selectedTaskID = task.id
                                        model.activeSheet = .submitWork
                                    } label: {
                                        AtlasButtonLabel(title: "提交作品", systemImage: "square.and.arrow.up")
                                    }
                                    .buttonStyle(.atlas(.primary))
                                } else {
                                    Label("企划已封存", systemImage: "lock")
                                        .font(AtlasFont.caption)
                                        .foregroundStyle(AtlasColor.textTertiary)
                                }
                            }
                            .padding(AtlasSpacing.l)
                            .atlasChromaticGlass(
                                RoundedRectangle(cornerRadius: AtlasRadius.card),
                                tint: AtlasColor.auroraAmber
                            )
                        }
                    }
                }
            }
            .padding(AtlasSpacing.xxl)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct TaskStickyNote: View {
    let task: AtlasTask
    let index: Int
    let canAccept: Bool
    let accept: () -> Void
    @State private var hovering = false
    @State private var tearing = false

    private var noteColor: Color {
        [Color(red: 0.96, green: 0.78, blue: 0.38),
         Color(red: 0.57, green: 0.87, blue: 0.72),
         Color(red: 0.94, green: 0.62, blue: 0.70)][index % 3]
    }

    var body: some View {
        Button {
            guard canAccept else { return }
            tearing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: accept)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(task.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(task.summary)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .lineLimit(4)
                Spacer()
                HStack {
                    Text(task.capacity.map { "\(task.participants)/\($0) 人" } ?? "\(task.participants) 人参与")
                    Spacer()
                    Text(canAccept ? "点击揭下" : "参企者可承接")
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.black.opacity(0.76))
            .padding(18)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
            .background(noteColor)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 66, height: 18)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -5 : 6))
                    .offset(y: -10)
            }
            .shadow(color: .black.opacity(hovering ? 0.50 : 0.30), radius: hovering ? 18 : 8, y: hovering ? 14 : 7)
            .rotationEffect(.degrees(tearing ? 8 : (index.isMultiple(of: 2) ? -2.4 : 2.1)))
            .scaleEffect(tearing ? 0.84 : (hovering && canAccept ? 1.035 : 1))
            .offset(y: tearing ? 90 : 0)
            .opacity(tearing ? 0 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: hovering)
        .animation(.easeIn(duration: 0.28), value: tearing)
    }
}

private struct ProjectForumView: View {
    enum SidePanel: String, CaseIterable, Identifiable {
        case feed = "互动视图"
        case npc = "NPC 信息"
        case timeline = "世界线发展进度"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .feed: "waveform.path.ecg"
            case .npc: "person.crop.rectangle.stack"
            case .timeline: "point.bottomleft.forward.to.point.topright.scurvepath"
            }
        }
    }

    @ObservedObject var model: AtlasAppModel
    @State private var selectedVenueID: String?
    @State private var selectedPostID: String?
    @State private var sidePanel: SidePanel = .feed
    @State private var sort = "热门"
    @State private var replies = ForumReply.samples
    @State private var replyText = ""
    @Namespace private var sideTabNamespace

    private var selectedVenue: InteractionVenue? {
        InteractionVenue.samples.first { $0.id == selectedVenueID }
    }
    private var venuePosts: [VenuePost] {
        guard let selectedVenueID else { return [] }
        let result = VenuePost.samples.filter { $0.venueID == selectedVenueID }
        return sort == "精华" ? result.filter(\.featured) : result
    }
    private var selectedPost: VenuePost? {
        VenuePost.samples.first { $0.id == selectedPostID }
    }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 980 {
                HStack(spacing: 0) {
                    forumMain
                        .frame(minWidth: 560, maxWidth: .infinity)
                    Divider().overlay(AtlasColor.borderSubtle)
                    sideRail
                        .frame(width: min(390, proxy.size.width * 0.34))
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        forumMain.frame(minHeight: 680)
                        Divider().overlay(AtlasColor.borderSubtle)
                        sideRail.frame(minHeight: 520)
                    }
                }
            }
        }
    }

    private var forumMain: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedVenue == nil ? "互动广场" : selectedVenue!.name)
                        .font(AtlasFont.title)
                    Text(selectedVenue?.hook ?? "每个板块都是一个独立交流区；进入后查看帖子、阅读正文并回复。")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                if selectedVenue != nil {
                    Button {
                        withAnimation(.snappy) {
                            selectedVenueID = nil
                            selectedPostID = nil
                        }
                    } label: {
                        Label("返回板块", systemImage: "chevron.left")
                    }
                    .buttonStyle(.atlas(.glass))
                }
            }
            .padding(AtlasSpacing.xl)

            Divider().overlay(AtlasColor.borderSubtle)

            if selectedVenue == nil {
                venueDirectory
            } else if let selectedPost {
                postDetail(selectedPost)
            } else {
                postList
            }
        }
    }

    private var venueDirectory: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: AtlasSpacing.m)], spacing: AtlasSpacing.m) {
                ForEach(InteractionVenue.samples) { venue in
                    Button {
                        withAnimation(.snappy) { selectedVenueID = venue.id }
                    } label: {
                        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                            HStack {
                                Image(systemName: venue.symbol)
                                    .font(.system(size: 22))
                                    .foregroundStyle(AtlasColor.auroraMint)
                                Text(venue.name).font(AtlasFont.heading)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AtlasColor.textTertiary)
                            }
                            Text(venue.subtitle)
                                .font(AtlasFont.caption)
                                .foregroundStyle(AtlasColor.textSecondary)
                            Text("“\(venue.hook)”")
                                .font(AtlasFont.body)
                                .foregroundStyle(AtlasColor.textPrimary)
                                .lineLimit(3)
                            HStack {
                                Label("\(venue.activeCount) 在线", systemImage: "circle.fill")
                                Spacer()
                                Text("\(VenuePost.samples.filter { $0.venueID == venue.id }.count) 个主题")
                            }
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
                        .padding(AtlasSpacing.l)
                        .atlasChromaticGlass(RoundedRectangle(cornerRadius: AtlasRadius.card), tint: AtlasColor.auroraViolet)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AtlasSpacing.xl)
        }
    }

    private var postList: some View {
        VStack(spacing: 0) {
            HStack {
                if let venue = selectedVenue {
                    Label(venue.rule, systemImage: "checkmark.shield")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                ForEach(["热门", "最新", "精华"], id: \.self) { item in
                    Button(item) { sort = item }
                        .buttonStyle(.plain)
                        .font(AtlasFont.caption)
                        .foregroundStyle(sort == item ? AtlasColor.textPrimary : AtlasColor.textTertiary)
                        .padding(6)
                }
            }
            .padding(.horizontal, AtlasSpacing.xl)
            .padding(.vertical, AtlasSpacing.m)
            Divider().overlay(AtlasColor.borderSubtle)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(venuePosts) { post in
                        Button {
                            withAnimation(.snappy) { selectedPostID = post.id }
                        } label: {
                            HStack(alignment: .top, spacing: AtlasSpacing.l) {
                                VStack(spacing: 2) {
                                    Image(systemName: "arrowtriangle.up.fill")
                                    Text("\(12 + post.replies)").font(AtlasFont.mono)
                                    Image(systemName: "arrowtriangle.down")
                                }
                                .font(.system(size: 9))
                                .foregroundStyle(AtlasColor.textTertiary)
                                .frame(width: 34)

                                VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                                    HStack {
                                        if post.featured {
                                            Text("预设").font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.auroraAmber)
                                        }
                                        Text("由 \(post.author) 发布")
                                            .font(AtlasFont.monoSmall)
                                            .foregroundStyle(AtlasColor.textTertiary)
                                    }
                                    Text(post.title).font(AtlasFont.heading)
                                    Text(post.body)
                                        .font(AtlasFont.caption)
                                        .foregroundStyle(AtlasColor.textSecondary)
                                        .lineLimit(2)
                                    Label("\(replies.filter { $0.postID == post.id }.count + post.replies) 回复", systemImage: "bubble.left")
                                        .font(AtlasFont.monoSmall)
                                        .foregroundStyle(AtlasColor.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AtlasColor.textTertiary)
                            }
                            .padding(AtlasSpacing.l)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(AtlasColor.borderSubtle)
                    }
                }
            }
        }
    }

    private func postDetail(_ post: VenuePost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                Button {
                    withAnimation(.snappy) { selectedPostID = nil }
                } label: {
                    Label("返回帖子列表", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .font(AtlasFont.caption)

                HStack {
                    if post.featured {
                        Text("企主预设").font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.auroraAmber)
                    }
                    Text("由 \(post.author) 发布")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                Text(post.title).font(AtlasFont.title)
                Text(post.body)
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .lineSpacing(6)
                Label(post.hook, systemImage: "arrowshape.turn.up.right")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.auroraViolet)
                    .padding(AtlasSpacing.m)
                    .atlasChromaticGlass(RoundedRectangle(cornerRadius: AtlasRadius.control), tint: AtlasColor.auroraViolet)

                Divider().overlay(AtlasColor.borderSubtle)
                Text("回复").font(AtlasFont.heading)
                ForEach(replies.filter { $0.postID == post.id }) { reply in
                    HStack(alignment: .top, spacing: AtlasSpacing.m) {
                        Circle()
                            .fill(AtlasColor.auroraViolet.opacity(0.35))
                            .frame(width: 38, height: 38)
                            .overlay(Text(String(reply.author.prefix(1))).font(AtlasFont.label))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(reply.author).font(AtlasFont.label)
                                Text(reply.time).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                            }
                            Text(reply.body).font(AtlasFont.body).foregroundStyle(AtlasColor.textSecondary)
                        }
                    }
                    .padding(AtlasSpacing.m)
                    .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.control))
                }

                if model.activeRole != .visitor && model.canWriteActiveWorld {
                    HStack {
                        TextField("[角色名] @ 地点：行动 + 可回应点", text: $replyText)
                            .textFieldStyle(.plain)
                            .padding(AtlasSpacing.m)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                        Button {
                            replies.append(.init(
                                id: UUID().uuidString,
                                postID: post.id,
                                author: "岑",
                                characterID: "char-cen",
                                body: replyText,
                                time: "刚刚"
                            ))
                            replyText = ""
                            model.showToast("回复已发布")
                        } label: {
                            AtlasButtonLabel(title: "回复", systemImage: "arrow.up")
                        }
                        .buttonStyle(.atlas(.primary))
                        .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(AtlasSpacing.xl)
        }
    }

    private var sideRail: some View {
        VStack(spacing: 0) {
            HStack(spacing: AtlasSpacing.xs) {
                ForEach(SidePanel.allCases) { item in
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                            sidePanel = item
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.symbol)
                            Text(item.rawValue).font(AtlasFont.monoSmall)
                        }
                        .foregroundStyle(sidePanel == item ? AtlasColor.textPrimary : AtlasColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AtlasSpacing.m)
                        .background {
                            if sidePanel == item {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .matchedGeometryEffect(id: "forum-side-tab", in: sideTabNamespace)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            Divider().overlay(AtlasColor.borderSubtle)
            ScrollView {
                Group {
                    switch sidePanel {
                    case .feed: feedPanel
                    case .npc: npcPanel
                    case .timeline: timelinePanel
                    }
                }
                .id(sidePanel)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
            }
            .animation(.spring(response: 0.44, dampingFraction: 0.86), value: sidePanel)
        }
        .background(AtlasColor.canvas.opacity(0.54))
    }

    private var feedPanel: some View {
        LazyVStack(alignment: .leading, spacing: AtlasSpacing.m) {
            railHeading("互动视图 · 全站动态")
            feedItem("岑", "在潮声酒馆发布回复", "把一封没有落款的信推到了吧台上。", "10 分钟前")
            feedItem("伊莱", "在失声海岸留下情报", "旧航图上的岛在退潮后出现了轮廓。", "28 分钟前")
            feedItem("林语", "在瞭望塔提交分析", "稳定元素浓度沿古代河道递减。", "1 小时前")
            feedItem("酒保 NPC", "更新了今日特调", "第一杯免费，第二杯用故事交换。", "3 小时前")
        }
        .padding(AtlasSpacing.l)
    }

    private var npcPanel: some View {
        LazyVStack(alignment: .leading, spacing: AtlasSpacing.m) {
            railHeading("NPC 信息")
            npcCard("舰长 · 艾德温", "夜航舰队总指挥", "性格沉稳，对失声海域的再次开放持审慎态度。", "舰桥", true)
            npcCard("首席研究员 · 林曦", "潮汐阵列负责人", "白塔异常的第一发现者，认为探索应优先于保守。", "瞭望塔", true)
            npcCard("酒保 · 老烟", "情报贩子", "掌握每一位夜航者忘在酒馆里的故事。", "酒馆后巷", true)
            npcCard("？？？ · 牧羊人", "未知势力", "多次在旧航线报告中以模糊身影出现。", "未知", false)
        }
        .padding(AtlasSpacing.l)
    }

    private var timelinePanel: some View {
        LazyVStack(alignment: .leading, spacing: AtlasSpacing.l) {
            railHeading("世界线发展进度")
            timelineNode("第一章", "启程：重启旧航线", "首批夜航者抵达第七码头。", 1, true)
            timelineNode("第一章", "第一接触：失声协议", "白塔与夜航守望建立临时协定。", 0.6, true)
            timelineNode("第二章", "深入：不存在的岛", "探索点将在当前任务结算后开放。", 0.1, false)
            timelineNode("第三章", "？？？", "待主线推进后揭晓。", 0, false)
        }
        .padding(AtlasSpacing.l)
    }

    private func railHeading(_ title: String) -> some View {
        Text(title).font(AtlasFont.heading).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feedItem(_ author: String, _ action: String, _ content: String, _ time: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                Text(author).font(AtlasFont.label)
                Text(action).font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
            }
            Text(content).font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
            Text(time).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
        }
        .padding(AtlasSpacing.m)
        .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.control))
    }

    private func npcCard(_ name: String, _ role: String, _ description: String, _ location: String, _ unlocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(AtlasFont.label)
            Text(role).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.auroraMint)
            Text(description).font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
            Label(location, systemImage: unlocked ? "mappin" : "lock")
                .font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
        }
        .opacity(unlocked ? 1 : 0.48)
        .padding(AtlasSpacing.m)
        .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.control))
    }

    private func timelineNode(_ phase: String, _ title: String, _ detail: String, _ progress: Double, _ active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(phase).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
            Text(title).font(AtlasFont.label)
            Text(detail).font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
            ProgressView(value: progress).tint(active ? AtlasColor.auroraMint : AtlasColor.textTertiary)
        }
    }
}

private struct OCCharacterComment: Identifiable {
    let id = UUID()
    let characterID: String
    let author: String
    let body: String
}

private struct OCInteractionView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var selectedID = AtlasCharacterProfile.samples[0].id
    @State private var comment = ""
    @State private var comments: [OCCharacterComment] = [
        .init(
            characterID: AtlasCharacterProfile.samples[0].id,
            author: "白昼",
            body: "如果想把伊莱放进长线剧情，可以先把关键转折发给我确认。"
        )
    ]

    private var selected: AtlasCharacterProfile {
        AtlasCharacterProfile.samples.first { $0.id == selectedID } ?? AtlasCharacterProfile.samples[0]
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                        Text("企划角色").font(AtlasFont.heading)
                        Text("选择一位其他参与者的 OC，阅读创作规范后发起互动。")
                            .font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
                        ForEach(AtlasCharacterProfile.samples) { character in
                            Button { selectedID = character.id } label: {
                                HStack {
                                    Circle()
                                        .fill(AtlasColor.auroraViolet.opacity(0.28))
                                        .frame(width: 42, height: 42)
                                        .overlay(Text(String(character.name.prefix(1))))
                                    VStack(alignment: .leading) {
                                        Text(character.name).font(AtlasFont.label)
                                        Text("\(character.owner) · \(character.role)")
                                            .font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                                    }
                                    Spacer()
                                }
                                .padding(AtlasSpacing.m)
                                .background(selectedID == character.id ? Color.white.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(AtlasSpacing.l)
                }
                .frame(width: proxy.size.width < 900 ? 220 : 300)

                Divider().overlay(AtlasColor.borderSubtle)

                ScrollView {
                    VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                        CharacterPortraitBanner(
                            character: selected
                        )

                        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                            Text(selected.name).font(AtlasFont.display)
                            Text("\(selected.owner) · \(selected.role)")
                                .font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                            Text(selected.summary).font(AtlasFont.body).foregroundStyle(AtlasColor.textSecondary)
                            Label(selected.location, systemImage: "mappin").font(AtlasFont.caption)
                            if model.activeRole == .participant &&
                                model.canWriteActiveWorld &&
                                selected.id != "char-cen" {
                                Button {
                                    model.selectedCharacterID = selected.id
                                    model.activeSheet = .interactionInvite
                                } label: {
                                    AtlasButtonLabel(title: "为这个 OC 发起互动创作", systemImage: "sparkles")
                                }
                                .buttonStyle(.atlas(.primary))
                            }
                        }

                        CharacterCustomFields(
                            character: selected,
                            canEditFields: selected.id == "char-cen"
                        )

                        CharacterInteractionDisclosureGroup(character: selected)

                        Divider().overlay(AtlasColor.borderSubtle)
                        Text("角色留言").font(AtlasFont.heading)
                        ForEach(comments.filter { $0.characterID == selected.id }) { message in
                            HStack(alignment: .firstTextBaseline, spacing: AtlasSpacing.s) {
                                Text("\(message.author)：")
                                    .font(AtlasFont.label)
                                Text(message.body)
                                    .font(AtlasFont.body)
                                    .foregroundStyle(AtlasColor.textSecondary)
                            }
                        }
                        if model.activeRole != .visitor && model.canWriteActiveWorld {
                            HStack {
                                TextField("询问设定、提出互动想法……", text: $comment)
                                    .textFieldStyle(.plain)
                                    .padding(AtlasSpacing.m)
                                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                                Button("发布") {
                                    let body = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !body.isEmpty else { return }
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        comments.append(
                                            .init(
                                                characterID: selected.id,
                                                author: "岑",
                                                body: body
                                            )
                                        )
                                    }
                                    model.showToast("留言已发布")
                                    comment = ""
                                }
                                .buttonStyle(.atlas(.primary))
                                .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                    .padding(AtlasSpacing.xxl)
                    .frame(maxWidth: 880, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

}
