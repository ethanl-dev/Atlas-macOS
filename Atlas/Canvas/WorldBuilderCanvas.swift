import SwiftUI
import AppKit

//
//  WorldBuilderCanvas —— 创建 / 管理世界的画布（原生 SwiftUI）。
//
//  这是 03 号规格里的 World Canvas，不是"地图编辑器"：
//  · 顶部：世界名 · 保存态 · 投影切换（地图/关系/时间线） · 预览 · 发布
//  · 左侧：组件库（把地点/角色/组织/事件/规则/物件/作品/便签放上画布）
//  · 中央：可平移缩放的大画布，对象按形状+图标（黑白）呈现
//  · 右侧：选中对象的可编辑详情卡
//  · 地图：只是可开关的底盘之一，点“编辑地图底盘”才进入 React 地图编辑器
//

struct WorldBuilderCanvas: View {
    @ObservedObject var model: AtlasAppModel
    @StateObject private var store: WorldBuilderStore
    let canEdit: Bool
    var onExit: () -> Void

    @State private var pan: CGSize = .zero
    @State private var scale: CGFloat = 1
    @State private var viewSize: CGSize = .zero
    @State private var panStart: CGSize = .zero
    @State private var didCenter = false
    @State private var showMapEditor = false
    @State private var placeCount = 0
    @State private var commandText = ""
    @FocusState private var commandFocused: Bool
    @State private var lastHoverCanvas: CGPoint = .zero
    @State private var marqueeStart: CGPoint?
    @State private var marqueeCurrent: CGPoint?
    @State private var zoomAnchor: CGFloat?
    @State private var scrollMonitor: Any?
    @State private var keyMonitor: Any?
    @State private var batchDrafts: [BatchCreateDraft] = []
    @State private var isParsingIntent = false
    @State private var isResearchingInspiration = false
    @State private var inspirationProposal: InspirationResearchProposal?
    @State private var sessionExpanded = true
    @State private var assistantCardExpanded = true
    @State private var sessionEntries: [AgentSessionEntry] = [
        .init(kind: .system, title: "智能体日志", body: "这里会记录你的指令、解析结果和采纳动作。")
    ]
    @State private var showWorldNameEditor = false
    @State private var worldNameDraft = ""
    @FocusState private var worldNameEditorFocused: Bool

    @StateObject private var organizer = CanvasOrganizer()
    @State private var commandMode: CommandMode = .place
    private enum CommandMode { case place, research, organize }
    private struct BatchCreateDraft: Identifiable {
        let id = UUID()
        var kind: BuilderKind
        var name: String
        var summary: String
    }
    private struct AgentSessionEntry: Identifiable {
        enum Kind {
            case system, user, parse, research, verify, adopt

            var title: String {
                switch self {
                case .system: return "系统"
                case .user: return "指令"
                case .parse: return "解析"
                case .research: return "研究"
                case .verify: return "核验"
                case .adopt: return "采纳"
                }
            }

            var symbol: String {
                switch self {
                case .system: return "sparkles"
                case .user: return "text.bubble"
                case .parse: return "wand.and.stars"
                case .research: return "magnifyingglass"
                case .verify: return "checkmark.shield"
                case .adopt: return "checkmark.circle"
                }
            }
        }

        let id = UUID()
        var kind: Kind
        var title: String
        var body: String
        var createdAt = Date()
    }

    init(
        model: AtlasAppModel,
        mode: String = "create",
        worldName: String = "未命名世界",
        canEdit: Bool = true,
        onExit: @escaping () -> Void
    ) {
        _model = ObservedObject(wrappedValue: model)
        self.canEdit = canEdit
        self.onExit = onExit
        _store = StateObject(wrappedValue: WorldBuilderStore(worldName: worldName, seeded: mode == "manage"))
    }

    var body: some View {
        canvasStage
        .overlay(alignment: .trailing) { detailPanel.zIndex(20) }
        .overlay(alignment: .leading) { sessionRail.zIndex(25) }
        .overlay(alignment: .bottom) { commandBar.zIndex(30) }
        .overlay(alignment: .top) { topBar.zIndex(60) }
        .overlay { worldNameEditorOverlay.zIndex(90) }
        .overlay { mapEditorOverlay }
        .background(Color(red: 0.035, green: 0.035, blue: 0.043))
    }

    // MARK: - 画布舞台

    private var canvasStage: some View {
        GeometryReader { proxy in
            let timeline = store.projection == .timeline
                ? TimelineLayout.make(events: store.objects.filter { $0.kind == .event })
                : TimelineLayout()
            ZStack {
                AtlasCanvasBackground()
                    .allowsHitTesting(false)

                // 专门接住空白处点击 → 取消选中（放在卡片下面；点卡片会被卡片先接走）
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { select(nil) }

                if store.projection == .map && store.showMapBase {
                    mapBase
                        .transition(.opacity)
                }

                if store.projection == .relation {
                    relationLayer(in: proxy.size)
                    relationChips(in: proxy.size)
                }

                if store.projection == .timeline {
                    timelineAxis(timeline)
                }

                ForEach(store.objects) { object in
                    let onTimeline = store.projection == .timeline
                    let dimmed = onTimeline && object.kind != .event
                    let world = (onTimeline ? timeline.positions[object.id] : nil) ?? object.position
                    ObjectCard(
                        object: object,
                        scale: scale,
                        selected: store.selectedIDs.contains(object.id),
                        store: store,
                        canEdit: canEdit,
                        onSelect: { select(object.id) },
                        onExpand: { openMapEditor(object.id) },
                        pan: pan,
                        layoutLocked: onTimeline,
                        dimmed: dimmed
                    )
                    .position(worldToScreen(world))
                    .opacity(dimmed ? 0.12 : 1)
                    .allowsHitTesting(!dimmed)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: onTimeline)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }

                if let plan = organizer.plan {
                    organizeGhostLayer(plan)
                }

                if let rect = marqueeScreenRect {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .overlay(Rectangle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }

                if store.objects.isEmpty {
                    TemplateStart(store: store)
                }
            }
            .coordinateSpace(.named("canvas"))
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .named("canvas")) { phase in
                if case .active(let point) = phase { lastHoverCanvas = point }
            }
            .gesture(marqueeGesture)
            .gesture(panGesture)
            .simultaneousGesture(magnifyGesture)
            .contextMenu {
                if canEdit {
                    Text("在此新建卡片")
                    ForEach(BuilderKind.creatable) { kind in
                        Button {
                            createCard(kind, atCanvas: lastHoverCanvas)
                        } label: {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                    }
                }
            }
            .onAppear {
                viewSize = proxy.size
                if !didCenter {
                    centerCanvas(in: proxy.size)
                    didCenter = true
                }
                startScrollMonitor()
                startKeyMonitor()
            }
            .onDisappear { stopScrollMonitor(); stopKeyMonitor() }
            .onChange(of: proxy.size) { _, newValue in viewSize = newValue }
        }
    }

    // 地图底盘（骨架阶段：原生的极淡制图岛形；点“编辑地图”进真编辑器）
    private var mapBase: some View {
        Canvas { context, size in
            guard store.mapMade else { return }
            let rects = [
                CGRect(x: size.width * 0.22, y: size.height * 0.24, width: size.width * 0.34, height: size.height * 0.40),
                CGRect(x: size.width * 0.52, y: size.height * 0.30, width: size.width * 0.30, height: size.height * 0.34)
            ]
            for (i, rect) in rects.enumerated() {
                let path = organicPath(in: rect, phase: CGFloat(i) * 0.8)
                context.fill(path, with: .color(.white.opacity(0.05)))
                context.stroke(path, with: .color(.white.opacity(0.14)), lineWidth: 1)
                for inset in stride(from: CGFloat(16), through: 48, by: 16) {
                    let r = rect.insetBy(dx: inset, dy: inset * 0.6)
                    if r.width > 20 {
                        context.stroke(organicPath(in: r, phase: CGFloat(i) * 0.8 + inset * 0.01),
                                       with: .color(.white.opacity(0.04)), lineWidth: 0.6)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // 关系连线：粗细/亮度随强度；提议中的关系用虚线；选中的关系提亮。
    private func relationLayer(in size: CGSize) -> some View {
        Canvas { context, _ in
            for relation in store.relations {
                guard let a = store.objects.first(where: { $0.id == relation.sourceID }),
                      let b = store.objects.first(where: { $0.id == relation.targetID }) else { continue }
                let selected = store.selectedRelationID == relation.id
                var path = Path()
                path.move(to: worldToScreen(a.position))
                path.addLine(to: worldToScreen(b.position))
                let op = selected ? 0.9 : relation.strength.opacity
                let width = (selected ? relation.strength.lineWidth + 0.8 : relation.strength.lineWidth)
                let style: StrokeStyle = relation.proposed
                    ? .init(lineWidth: relation.strength.lineWidth, dash: [6, 5])
                    : .init(lineWidth: width, lineCap: .round)
                context.stroke(path, with: .color(.white.opacity(op)), style: style)
            }
        }
        .allowsHitTesting(false)
    }

    // 关系中点 chip：可点选进入关系详情卡。有长文叙事的关系带段落图标。
    @ViewBuilder
    private func relationChips(in size: CGSize) -> some View {
        ForEach(store.relations) { relation in
            if let a = store.objects.first(where: { $0.id == relation.sourceID }),
               let b = store.objects.first(where: { $0.id == relation.targetID }) {
                let mid = CGPoint(x: (a.position.x + b.position.x) / 2,
                                  y: (a.position.y + b.position.y) / 2)
                RelationChip(relation: relation,
                             selected: store.selectedRelationID == relation.id) {
                    selectRelation(relation.id)
                }
                .position(worldToScreen(mid))
            }
        }
    }

    // Agent 整理方案的幽灵预览：提议新位置的半透明卡 + 移动轨迹 + 提议关系（虚线）。
    @ViewBuilder
    private func organizeGhostLayer(_ plan: OrganizePlan) -> some View {
        ZStack {
            Canvas { ctx, _ in
                for (id, target) in plan.ghostPositions {
                    guard let obj = store.objects.first(where: { $0.id == id }) else { continue }
                    var p = Path()
                    p.move(to: worldToScreen(obj.position))
                    p.addLine(to: worldToScreen(target))
                    ctx.stroke(p, with: .color(.white.opacity(0.22)),
                               style: .init(lineWidth: 1, dash: [3, 4]))
                }
                for link in plan.proposedLinks {
                    guard let a = ghostPos(link.source, plan), let b = ghostPos(link.target, plan) else { continue }
                    var p = Path()
                    p.move(to: worldToScreen(a)); p.addLine(to: worldToScreen(b))
                    ctx.stroke(p, with: .color(.white.opacity(0.55)),
                               style: .init(lineWidth: 1.6, dash: [6, 5]))
                }
            }
            .allowsHitTesting(false)

            ForEach(Array(plan.ghostPositions.keys), id: \.self) { id in
                if let obj = store.objects.first(where: { $0.id == id }) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.4), style: .init(lineWidth: 1, dash: [5, 4])))
                        .frame(width: obj.size.width * scale, height: obj.size.height * scale)
                        .position(worldToScreen(plan.ghostPositions[id] ?? obj.position))
                        .allowsHitTesting(false)
                }
            }
        }
        .transition(.opacity)
    }

    private func ghostPos(_ id: String, _ plan: OrganizePlan) -> CGPoint? {
        if let g = plan.ghostPositions[id] { return g }
        return store.objects.first(where: { $0.id == id })?.position
    }

    private func timelineAxis(_ layout: TimelineLayout) -> some View {
        Canvas { context, _ in
            guard !layout.isEmpty else { return }
            let cs = TimelineLayout.columnSpacing
            let baseY = layout.baselineY

            // 时间轴基线
            var base = Path()
            base.move(to: worldToScreen(CGPoint(x: layout.minX - cs / 2, y: baseY)))
            base.addLine(to: worldToScreen(CGPoint(x: layout.maxX + cs / 2, y: baseY)))
            context.stroke(base, with: .color(.white.opacity(0.18)), lineWidth: 1)

            // 阶段分隔线 + 阶段标题
            func divider(atWorldX x: CGFloat) {
                var d = Path()
                d.move(to: worldToScreen(CGPoint(x: x, y: baseY - 320)))
                d.addLine(to: worldToScreen(CGPoint(x: x, y: baseY + 320)))
                context.stroke(d, with: .color(.white.opacity(0.06)),
                               style: .init(lineWidth: 1, dash: [3, 7]))
            }
            for band in layout.bands {
                divider(atWorldX: band.xStart)
                let labelPt = worldToScreen(CGPoint(x: band.labelX, y: baseY - 300))
                context.draw(
                    Text(band.phase.title).font(AtlasFont.mono)
                        .foregroundColor(Color.white.opacity(0.32 + 0.5 * band.phase.emphasis)),
                    at: labelPt, anchor: .center
                )
            }
            if let last = layout.bands.last { divider(atWorldX: last.xEnd) }

            // 每列：连接线 + 刻度点 + 日期标签
            for col in layout.columns {
                let tick = worldToScreen(CGPoint(x: col.x, y: baseY))
                for id in col.eventIDs {
                    if let p = layout.positions[id] {
                        var c = Path()
                        c.move(to: tick); c.addLine(to: worldToScreen(p))
                        context.stroke(c, with: .color(.white.opacity(0.12)), lineWidth: 1)
                    }
                }
                let r: CGFloat = 4
                context.fill(
                    Path(ellipseIn: CGRect(x: tick.x - r, y: tick.y - r, width: 2 * r, height: 2 * r)),
                    with: .color(.white.opacity(0.55))
                )
                if !col.dateLabel.isEmpty {
                    context.draw(
                        Text(col.dateLabel).font(AtlasFont.monoSmall)
                            .foregroundColor(Color.white.opacity(0.5)),
                        at: CGPoint(x: tick.x, y: tick.y + 16), anchor: .center
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack(spacing: 0) {
            topBarTitleGroup
                .frame(width: 360, alignment: .leading)

            Spacer(minLength: AtlasSpacing.l)

            projectionSwitch

            Spacer(minLength: AtlasSpacing.l)

            topBarActions
                .frame(width: 360, alignment: .trailing)
        }
        .padding(.vertical, AtlasSpacing.m)
        .padding(.trailing, AtlasSpacing.m)
        // macOS 交通灯（红黄绿）在 .hiddenTitleBar 下仍浮于左上角，给顶栏左侧留出安全区。
        .padding(.leading, Self.trafficLightInset)
        .frame(height: 76)
        .frame(maxWidth: .infinity)
        .background {
            topBarGlassShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.080),
                            Color.white.opacity(0.030),
                            Color.black.opacity(0.030)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial, in: topBarGlassShape)
                .overlay(topBarGlassShape.stroke(Color.white.opacity(0.24), lineWidth: 1))
                .overlay(alignment: .top) {
                    topBarGlassShape
                        .stroke(Color.white.opacity(0.58), lineWidth: 0.8)
                        .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
                }
                .overlay(alignment: .bottom) {
                    topBarGlassShape
                        .stroke(Color.black.opacity(0.20), lineWidth: 0.8)
                        .mask(LinearGradient(colors: [.clear, .white], startPoint: .center, endPoint: .bottom))
                }
                .shadow(color: .black.opacity(0.42), radius: 26, y: 14)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    private var topBarTitleGroup: some View {
        HStack(spacing: AtlasSpacing.m) {
            Button { onExit() } label: {
                Image(systemName: "chevron.left").frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AtlasColor.textPrimary)
            .atlasP1Glass(Circle(), interactive: true)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: AtlasSpacing.s) {
                    Text(store.worldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名世界" : store.worldName)
                        .font(AtlasFont.serifHeading)
                        .foregroundStyle(AtlasColor.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: 210, alignment: .leading)

                    if canEdit {
                        Button { openWorldNameEditor() } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 10.5, weight: .semibold))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .atlasP1Glass(Circle(), interactive: true)
                        .help("编辑企划名称")
                    }
                }

                Text(canEdit ? (store.saved ? "所有更改已保存" : "正在编辑 · 尚未保存") : "只读浏览")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var topBarActions: some View {
        if canEdit {
            HStack(spacing: AtlasSpacing.m) {
                baseLayerMenu

                Button {
                    store.saved = true
                    model.showToast("世界已保存 · \(store.objects.count) 个对象")
                } label: {
                    AtlasButtonLabel(title: "保存", systemImage: "checkmark")
                }
                .buttonStyle(.atlas(.primary))
            }
        }
    }

    private var topBarGlassShape: some Shape {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
    }

    /// macOS 窗口控制按钮（红黄绿）占用的左上安全区宽度。
    static let trafficLightInset: CGFloat = 82

    private var projectionSwitch: some View {
        HStack(spacing: 2) {
            ForEach(BuilderProjection.allCases) { mode in
                Button {
                    withAnimation(.snappy) { store.projection = mode }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.symbol).font(.system(size: 11))
                        Text(mode.rawValue).font(AtlasFont.label)
                    }
                    .foregroundStyle(store.projection == mode ? AtlasColor.inverse : AtlasColor.textSecondary)
                    .padding(.horizontal, AtlasSpacing.l)
                    .padding(.vertical, AtlasSpacing.s)
                    .background {
                        if store.projection == mode {
                            Capsule().fill(Color.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AtlasP1Glass.darkFill, in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle))
        .atlasP1Glass(Capsule())
    }

    @ViewBuilder
    private var worldNameEditorOverlay: some View {
        if showWorldNameEditor {
            ZStack {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { closeWorldNameEditor() }

                VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("编辑企划名称")
                                .font(AtlasFont.heading)
                                .foregroundStyle(AtlasColor.textPrimary)
                            Text("保存后会更新顶部显示名称。")
                                .font(AtlasFont.caption)
                                .foregroundStyle(AtlasColor.textTertiary)
                        }

                        Spacer()

                        HStack(spacing: AtlasSpacing.s) {
                            Button { commitWorldNameEditor() } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AtlasColor.inverse)
                            .background(Color.white, in: Circle())
                            .help("确认")

                            Button { closeWorldNameEditor() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AtlasColor.textSecondary)
                            .atlasP1Glass(Circle(), interactive: true)
                            .help("关闭窗口")
                        }
                    }

                    TextField("未命名世界", text: $worldNameDraft)
                        .textFieldStyle(.plain)
                        .font(AtlasFont.serifTitle)
                        .foregroundStyle(AtlasColor.textPrimary)
                        .focused($worldNameEditorFocused)
                        .onSubmit { commitWorldNameEditor() }
                        .padding(.horizontal, AtlasSpacing.l)
                        .padding(.vertical, AtlasSpacing.m)
                        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
                }
                .padding(AtlasSpacing.xl)
                .frame(width: 420)
                .atlasFrostedPanel(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .onAppear {
                    worldNameEditorFocused = true
                }
            }
            .animation(.snappy(duration: 0.22), value: showWorldNameEditor)
        }
    }

    private func openWorldNameEditor() {
        worldNameDraft = store.worldName
        withAnimation(.snappy(duration: 0.22)) {
            showWorldNameEditor = true
        }
    }

    private func closeWorldNameEditor() {
        withAnimation(.snappy(duration: 0.18)) {
            showWorldNameEditor = false
        }
    }

    private func commitWorldNameEditor() {
        let trimmed = worldNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        store.worldName = trimmed.isEmpty ? "未命名世界" : trimmed
        store.saved = false
        closeWorldNameEditor()
    }

    // MARK: - 底盘菜单（收进顶栏，不占画布）

    private var baseLayerMenu: some View {
        Menu {
            Toggle("显示地图底盘", isOn: $store.showMapBase)
            Button {
                showMapEditor = true
            } label: {
                Label(store.mapMade ? "编辑地图底盘…" : "绘制地图底盘…", systemImage: "map")
            }
        } label: {
            AtlasButtonLabel(title: "底盘", systemImage: "square.3.layers.3d")
                .font(AtlasFont.label)
                .foregroundStyle(AtlasColor.textPrimary)
                .padding(.horizontal, AtlasSpacing.m)
                .padding(.vertical, AtlasSpacing.s)
                .atlasP1Glass(Capsule(), interactive: true)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - 右侧详情卡

    @ViewBuilder
    private var detailPanel: some View {
        if canEdit, let rid = store.selectedRelationID, let rbind = store.relationBinding(for: rid) {
            RelationDetailCard(relation: rbind, store: store) {
                store.removeLink(rid)
            }
            .frame(width: 300)
            .padding(.trailing, AtlasSpacing.l)
            .padding(.top, 102)
            .padding(.bottom, AtlasSpacing.l)
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if let id = store.selectedID, let bind = store.binding(for: id) {
            DetailCard(object: bind, store: store) {
                store.delete(id)
            }
            .frame(width: 300)
            .padding(.trailing, AtlasSpacing.l)
            .padding(.top, 102)
            .padding(.bottom, AtlasSpacing.l)
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    // MARK: - 左侧 Session 记录

    private var sessionRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            assistantFloatingCard
                .padding(.top, 112)

            Spacer(minLength: 0)

            sessionTray
        }
        .padding(.leading, AtlasSpacing.l)
        .padding(.bottom, AtlasSpacing.l)
        .frame(maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var assistantFloatingCard: some View {
        if assistantCardExpanded {
            VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                HStack {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AtlasColor.inverse)
                        .frame(width: 52, height: 22)
                        .background(Color.white, in: Capsule())
                    Spacer()
                    Button {
                        withAnimation(.snappy(duration: 0.24)) { assistantCardExpanded = false }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .help("收起回复卡")
                }

                if let user = latestUserEntry {
                    promptPill(user)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(latestAssistantEntry.title.isEmpty ? latestAssistantEntry.kind.title : latestAssistantEntry.title)
                        .font(AtlasFont.label)
                        .foregroundStyle(AtlasColor.textPrimary)

                    Text(latestAssistantEntry.body)
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(12)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(AtlasSpacing.m)
            .frame(width: 330, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.11),
                        Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.84),
                        Color.black.opacity(0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.13), lineWidth: 1))
            .shadow(color: .black.opacity(0.34), radius: 22, y: 12)
            .transition(.scale(scale: 0.82, anchor: .topLeading).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.snappy(duration: 0.24)) { assistantCardExpanded = true }
            } label: {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 56, height: 36)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .atlasP1Glass(Capsule(), interactive: true)
            }
            .buttonStyle(.plain)
            .help("展开最新回复")
            .transition(.scale(scale: 0.86, anchor: .topLeading).combined(with: .opacity))
        }
    }

    private var sessionTray: some View {
        Group {
            if sessionExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                        ForEach(recentSessionEntries) { entry in
                            sessionChip(entry)
                        }
                    }
                    .padding(.horizontal, AtlasSpacing.m)
                    .padding(.top, AtlasSpacing.m)
                    .padding(.bottom, AtlasSpacing.s)

                    Divider().overlay(AtlasColor.borderSubtle)

                    Button {
                        withAnimation(.snappy(duration: 0.24)) { sessionExpanded = false }
                    } label: {
                        HStack(spacing: AtlasSpacing.s) {
                            Image(systemName: "paperplane")
                            Text("智能体日志").font(AtlasFont.label)
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(AtlasColor.textPrimary)
                        .padding(.horizontal, AtlasSpacing.m)
                        .frame(height: 48)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 330, alignment: .leading)
                .atlasFrostedPanel(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.snappy(duration: 0.24)) { sessionExpanded = true }
                } label: {
                    HStack(spacing: AtlasSpacing.s) {
                        Image(systemName: "paperplane")
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(AtlasColor.textPrimary)
                    .padding(.horizontal, AtlasSpacing.m)
                    .frame(height: 36)
                    .atlasP1Glass(Capsule(), interactive: true)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.86, anchor: .bottomLeading).combined(with: .opacity))
            }
        }
    }

    private var latestUserEntry: AgentSessionEntry? {
        sessionEntries.last { $0.kind == .user }
    }

    private var latestAssistantEntry: AgentSessionEntry {
        sessionEntries.last { $0.kind != .user } ?? sessionEntries[0]
    }

    private var recentSessionEntries: [AgentSessionEntry] {
        Array(sessionEntries.suffix(2))
    }

    private func promptPill(_ entry: AgentSessionEntry) -> some View {
        HStack(spacing: AtlasSpacing.s) {
            Text("E")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(AtlasColor.auroraMint.opacity(0.72), in: Circle())
            Text(entry.body.isEmpty ? entry.title : entry.body)
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.body, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AtlasColor.textTertiary)
        }
        .padding(.horizontal, AtlasSpacing.s)
        .padding(.vertical, AtlasSpacing.s)
        .background(Color.black.opacity(0.18), in: Capsule())
    }

    private func sessionChip(_ entry: AgentSessionEntry) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { assistantCardExpanded = true }
        } label: {
            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: entry.kind == .user ? "checkmark.circle" : entry.kind.symbol)
                    .font(.system(size: 12))
                Text(entry.body.isEmpty ? entry.title : entry.body)
                    .font(AtlasFont.caption)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(AtlasColor.textSecondary)
            .padding(.horizontal, AtlasSpacing.s)
            .frame(height: 30)
            .background(Color.white.opacity(0.055), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func sessionTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func appendSession(_ kind: AgentSessionEntry.Kind, title: String, body: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            sessionEntries.append(.init(kind: kind, title: title, body: body))
            if sessionEntries.count > 30 {
                sessionEntries.removeFirst(sessionEntries.count - 30)
            }
        }
    }

    // MARK: - 命令条（Stitch 式：不选中=描述即落画布；选中=贴着对象追问）

    @ViewBuilder
    private var commandBar: some View {
        if canEdit {
            VStack(spacing: AtlasSpacing.s) {
                // 研究 / 整理 / 批量新建都先给方案；对象快捷 chip 固定在输入框上方。
                if commandMode == .organize {
                    organizePanel
                } else if commandMode == .research {
                    inspirationPanel
                } else if !batchDrafts.isEmpty {
                    batchCreatePanel
                }
                contextChipRow

                HStack(spacing: AtlasSpacing.s) {
                    modeToggle
                    Divider().frame(height: 16).overlay(AtlasColor.borderSubtle)
                    Image(systemName: commandMode == .organize
                          ? "wand.and.stars"
                          : (commandMode == .research ? "magnifyingglass" : (store.selected == nil ? "plus.circle" : "text.cursor")))
                        .font(.system(size: 13))
                        .foregroundStyle(AtlasColor.textTertiary)
                    TextField(commandPlaceholder, text: $commandText)
                        .textFieldStyle(.plain)
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textPrimary)
                        .focused($commandFocused)
                        .onSubmit { runCommand() }
                    Button { runCommand() } label: {
                        Image(systemName: commandMode == .organize ? "wand.and.stars" : "arrow.up")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.atlas(.primary))
                    .disabled(commandText.trimmingCharacters(in: .whitespaces).isEmpty || organizer.isThinking || isParsingIntent || isResearchingInspiration)
                }
                .padding(.horizontal, AtlasSpacing.m)
                .padding(.vertical, AtlasSpacing.s)
                .frame(width: 560)
                .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
            }
            .padding(.bottom, AtlasSpacing.l)
        }
    }

    // 输入框上方的上下文 chip：未选中时是画布级能力；选中时是对象级能力。
    @ViewBuilder
    private var contextChipRow: some View {
        if let object = store.selected {
            quickActionRow(object)
        } else {
            canvasActionRow
        }
    }

    // 递卡通道：选中对象的编号快捷建议（Agent 只递卡，采纳才作数）。
    private func quickActionRow(_ object: BuilderObject) -> some View {
        HStack(spacing: AtlasSpacing.s) {
            HStack(spacing: 5) {
                NodeGlyph(shape: object.kind.shape, symbol: object.kind.symbol, size: 16)
                Text(store.displayName(object)).font(AtlasFont.caption)
            }
            .foregroundStyle(AtlasColor.textSecondary)
            .padding(.horizontal, AtlasSpacing.s).padding(.vertical, 4)
            .background(Color.white.opacity(0.06), in: Capsule())

            ForEach(Array(quickActions(for: object.kind).enumerated()), id: \.offset) { index, action in
                Button {
                    model.showToast("已递卡：\(action)（作者采纳才进设定 · 下一轮接入）")
                } label: {
                    HStack(spacing: 4) {
                        Text(action).font(AtlasFont.caption)
                        Text("\(index + 1)").font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                    .foregroundStyle(AtlasColor.textPrimary)
                    .padding(.horizontal, AtlasSpacing.s).padding(.vertical, 5)
                    .background(AtlasP1Glass.darkFill, in: Capsule())
                    .overlay(Capsule().stroke(AtlasColor.borderSubtle))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 560, alignment: .leading)
    }

    private var canvasActionRow: some View {
        HStack(spacing: AtlasSpacing.s) {
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2").font(.system(size: 11))
                Text("画布").font(AtlasFont.caption)
            }
            .foregroundStyle(AtlasColor.textSecondary)
            .padding(.horizontal, AtlasSpacing.s).padding(.vertical, 4)
            .background(Color.white.opacity(0.06), in: Capsule())

            Button {
                commandMode = .place
                commandText = "地点：\n角色：\n组织：\n事件："
                commandFocused = true
            } label: { commandChip("批量新建", number: 1) }
            .buttonStyle(.plain)

            Button {
                commandMode = .place
                commandFocused = true
            } label: { commandChip("解析新建", number: 2) }
            .buttonStyle(.plain)

            Button {
                commandMode = .organize
                commandText = "按类型归类"
                commandFocused = true
            } label: { commandChip("整理画布", number: 3) }
            .buttonStyle(.plain)

            Button {
                commandMode = .research
                commandText = ""
                commandFocused = true
            } label: { commandChip("寻找灵感", number: 4) }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .frame(width: 560, alignment: .leading)
    }

    private func commandChip(_ title: String, number: Int) -> some View {
        HStack(spacing: 4) {
            Text(title).font(AtlasFont.caption)
            Text("\(number)").font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textTertiary)
        }
        .foregroundStyle(AtlasColor.textPrimary)
        .padding(.horizontal, AtlasSpacing.s).padding(.vertical, 5)
        .background(AtlasP1Glass.darkFill, in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle))
    }

    private var batchCreatePanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up").font(.system(size: 11))
                Text("解析新建方案").font(AtlasFont.label)
                Spacer()
                Text("\(batchDrafts.count) 张草稿卡").font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .foregroundStyle(AtlasColor.textSecondary)

            ForEach(batchDrafts.prefix(5)) { draft in
                HStack(spacing: 6) {
                    Image(systemName: draft.kind.symbol).font(.system(size: 10))
                    Text("\(draft.kind.title) · \(draft.name)").font(AtlasFont.caption).lineLimit(1)
                }
                .foregroundStyle(AtlasColor.textSecondary)
            }
            if batchDrafts.count > 5 {
                Text("…等共 \(batchDrafts.count) 张").font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }

            HStack(spacing: AtlasSpacing.s) {
                Button { adoptBatchDrafts() } label: {
                    AtlasButtonLabel(title: "采纳新建", systemImage: "checkmark")
                }
                .buttonStyle(.atlas(.primary))
                Button { withAnimation(.easeOut(duration: 0.2)) { batchDrafts = [] } } label: {
                    AtlasButtonLabel(title: "撤销", systemImage: "xmark")
                }
                .buttonStyle(.atlas(.glass))
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
        .frame(width: 560, alignment: .leading)
        .padding(.horizontal, AtlasSpacing.m).padding(.vertical, AtlasSpacing.s)
        .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
    }

    // 放置 / AI 整理 模式切换
    private var modeToggle: some View {
        HStack(spacing: 2) {
            modeSeg("放置", .place, "plus")
            modeSeg("灵感", .research, "sparkles")
            modeSeg("整理", .organize, "wand.and.stars")
        }
        .padding(2)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle))
    }

    private func modeSeg(_ title: String, _ mode: CommandMode, _ symbol: String) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { commandMode = mode; commandText = "" }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 9))
                Text(title).font(AtlasFont.caption)
            }
            .foregroundStyle(commandMode == mode ? AtlasColor.inverse : AtlasColor.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background { if commandMode == mode { Capsule().fill(Color.white) } }
        }
        .buttonStyle(.plain)
    }

    // 整理方案预览面板（仅在思考/有方案/有错误时出现）
    @ViewBuilder
    private var organizePanel: some View {
        if organizer.isThinking {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("正在整理画布…").font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
            }
            .frame(width: 560, alignment: .leading)
            .padding(.horizontal, AtlasSpacing.m).padding(.vertical, AtlasSpacing.s)
            .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        } else if let plan = organizer.plan {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars").font(.system(size: 11))
                    Text("整理方案").font(AtlasFont.label)
                    Spacer()
                    Text(planCountLabel(plan)).font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                .foregroundStyle(AtlasColor.textSecondary)

                ForEach(Array(plan.summaries.prefix(4).enumerated()), id: \.offset) { _, s in
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill").font(.system(size: 3))
                        Text(s).font(AtlasFont.caption).lineLimit(1)
                    }
                    .foregroundStyle(AtlasColor.textSecondary)
                }
                if plan.summaries.count > 4 {
                    Text("…等共 \(plan.summaries.count) 项").font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }

                HStack(spacing: AtlasSpacing.s) {
                    Button { adoptOrganizePlan() } label: {
                        AtlasButtonLabel(title: "采纳整理", systemImage: "checkmark")
                    }
                    .buttonStyle(.atlas(.primary))
                    Button {
                        appendSession(.parse, title: "撤销整理", body: "已丢弃当前整理方案。")
                        organizer.discard()
                    } label: {
                        AtlasButtonLabel(title: "撤销", systemImage: "xmark")
                    }
                    .buttonStyle(.atlas(.glass))
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
            .frame(width: 560, alignment: .leading)
            .padding(.horizontal, AtlasSpacing.m).padding(.vertical, AtlasSpacing.s)
            .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        } else if let err = organizer.errorText {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 11))
                Text(err).font(AtlasFont.caption).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AtlasColor.textSecondary)
            .frame(width: 560, alignment: .leading)
            .padding(.horizontal, AtlasSpacing.m).padding(.vertical, AtlasSpacing.s)
            .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        }
    }

    private func planCountLabel(_ plan: OrganizePlan) -> String {
        var parts: [String] = []
        if plan.moveCount > 0 { parts.append("移动 \(plan.moveCount)") }
        if plan.linkCount > 0 { parts.append("连接 \(plan.linkCount)") }
        if plan.unlinkCount > 0 { parts.append("移除 \(plan.unlinkCount)") }
        return parts.joined(separator: " · ")
    }

    private var commandPlaceholder: String {
        if commandMode == .organize {
            return "让我整理画布：如「按类型归类」「把艾琳娜和森林议会连起来」"
        }
        if commandMode == .research {
            return "从真实世界找灵感：如「火山闪电」「一场历史上的粮食危机」"
        }
        if let object = store.selected {
            return "对「\(store.displayName(object))」追问或补充…"
        }
        return "描述一个地点、角色、事件…按回车放上画布"
    }

    private func quickActions(for kind: BuilderKind) -> [String] {
        switch kind {
        case .location:  return ["补进入条件", "查关联角色", "改公开简介"]
        case .character: return ["补角色缺项", "建议可参与事件", "拟审核反馈"]
        case .org:       return ["补势力范围", "查关联角色", "改公开简介"]
        case .event:     return ["补参与条件", "查时间冲突", "补结算字段"]
        case .rule:      return ["改写更清晰", "找冲突规则", "补示例"]
        default:         return ["补设定", "查关联", "改公开语"]
        }
    }

    @ViewBuilder
    private var mapEditorOverlay: some View {
        if showMapEditor {
            WorldMapCanvasView(
                mode: store.mapMade ? "manage" : "create",
                onExit: { withAnimation(.snappy(duration: 0.3)) { showMapEditor = false } },
                onSave: { _, _ in
                    // 就地生成海岸线并留在编辑器里让用户看到结果；返回由用户点“返回”触发
                    store.mapMade = true
                    store.saved = false
                    model.showToast("海岸线已生成 · 点左上返回画布")
                }
            )
            .ignoresSafeArea()
            .transition(.opacity)
            .zIndex(10)
        }
    }

    // MARK: - 交互

    // Stitch 式：一句话即落画布。不选中=新建对象（类型自动推断、随后可改）；
    // 选中=把这句话补进该对象的档案（真正的 AI 追问下一轮接入）。
    private func runCommand() {
        let text = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let sessionTitle: String
        switch commandMode {
        case .organize: sessionTitle = "整理指令"
        case .research: sessionTitle = "灵感方向"
        case .place: sessionTitle = "画布指令"
        }
        appendSession(.user, title: sessionTitle, body: text)

        // 整理通道：交给 Agent 生成待采纳的整理方案（只动布局与关系，不改正文）。
        if commandMode == .organize {
            organizer.propose(instruction: text, store: store)
            appendSession(.parse, title: "正在生成整理方案", body: "模型会被限制为布局与关系工具，不会改写卡片正文。")
            commandText = ""
            return
        }

        if commandMode == .research {
            researchInspiration(text)
            commandText = ""
            return
        }

        if shouldRouteToSelectedObject(text),
           let id = store.selectedID,
           let index = store.objects.firstIndex(where: { $0.id == id }) {
            store.objects[index].summary = store.objects[index].summary.isEmpty
                ? text : store.objects[index].summary + "\n" + text
            store.saved = false
            appendSession(.adopt, title: "写入选中对象", body: "已追加到「\(store.displayName(store.objects[index]))」的档案草稿。")
        } else {
            parseCanvasIntent(text)
        }
        commandText = ""
    }

    private func shouldRouteToSelectedObject(_ text: String) -> Bool {
        guard store.selectedID != nil else { return false }
        let createWords = ["新建", "创建", "新增", "添加", "生成一个", "建一个", "批量"]
        return !createWords.contains { text.contains($0) }
    }

    private func parseCanvasIntent(_ text: String) {
        AgentTelemetry.track("agent_canvas_parse_requested")
        isParsingIntent = true
        appendSession(.parse, title: AgentConfig.isConfigured ? "正在理解画布指令" : "本地规则解析", body: AgentConfig.isConfigured ? "使用建档助手技能：批量新建 / 命名解析 / 类型识别 / 摘要整理。" : "未配置模型 Key，使用本地关键词兜底。")

        Task { @MainActor in
            let drafts: [BatchCreateDraft]
            if AgentConfig.isConfigured {
                do {
                    let reply = try await DeepSeekClient().parseCanvasIntent(
                        instruction: text,
                        snapshot: CanvasOrganizer.snapshot(store)
                    )
                    drafts = reply.drafts.map { BatchCreateDraft(kind: $0.kind, name: $0.name, summary: $0.summary) }
                } catch {
                    appendSession(.parse, title: "模型解析失败，已降级", body: error.localizedDescription)
                    drafts = CanvasIntentParser.parseBatchDrafts(from: text).map { BatchCreateDraft(kind: $0.kind, name: $0.name, summary: $0.summary) }
                }
            } else {
                drafts = CanvasIntentParser.parseBatchDrafts(from: text).map { BatchCreateDraft(kind: $0.kind, name: $0.name, summary: $0.summary) }
            }

            isParsingIntent = false
            guard !drafts.isEmpty else {
                appendSession(.parse, title: "没有识别到可新建对象", body: "可以试试：新建一个地点，命名为雾港。")
                return
            }

            if drafts.count > 1 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                    batchDrafts = drafts
                }
                AgentTelemetry.track("agent_canvas_drafts_proposed", properties: ["count": "\(drafts.count)"])
                appendSession(.parse, title: "解析新建方案", body: batchSummary(drafts))
            } else if let draft = drafts.first {
                createDraftCard(draft)
                AgentTelemetry.track("agent_canvas_draft_created", properties: ["kind": draft.kind.rawValue])
                appendSession(.adopt, title: "新建草稿卡", body: "\(draft.kind.title) · \(draft.name)")
            }
        }
    }

    private func createDraftCard(_ draft: BatchCreateDraft) {
        placeCount += 1
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let angle = Double(placeCount) * 2.399
        let radius = 32.0 * Double(min(placeCount, 8))
        let screen = CGPoint(x: center.x + CGFloat(cos(angle) * radius),
                             y: center.y + CGFloat(sin(angle) * radius))
        let world = screenToWorld(screen)
        withAnimation(.snappy(duration: 0.25)) {
            let newID = store.add(draft.kind, at: world)
            if let i = store.objects.firstIndex(where: { $0.id == newID }) {
                store.objects[i].name = draft.name
                store.objects[i].summary = draft.summary
                store.objects[i].aiAssisted = true
            }
        }
    }

    private func adoptOrganizePlan() {
        guard let plan = organizer.plan else { return }
        appendSession(.adopt, title: "采纳整理方案", body: plan.summaries.prefix(4).joined(separator: "\n"))
        organizer.adopt(into: store)
    }

    private func adoptBatchDrafts() {
        let drafts = batchDrafts
        guard !drafts.isEmpty else { return }
        let cols = max(1, Int(ceil(sqrt(Double(drafts.count)))))
        let center = screenToWorld(CGPoint(x: viewSize.width / 2, y: viewSize.height / 2))
        let cellW: CGFloat = 280
        let cellH: CGFloat = 190
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            for (index, draft) in drafts.enumerated() {
                let row = index / cols
                let col = index % cols
                let x = center.x + CGFloat(col) * cellW - CGFloat(cols - 1) * cellW / 2
                let y = center.y + CGFloat(row) * cellH
                let newID = store.add(draft.kind, at: CGPoint(x: x, y: y))
                if let i = store.objects.firstIndex(where: { $0.id == newID }) {
                    store.objects[i].name = draft.name
                    store.objects[i].summary = draft.summary
                    store.objects[i].aiAssisted = true
                }
            }
            store.selectedIDs = Set(store.objects.suffix(drafts.count).map(\.id))
            batchDrafts = []
        }
        appendSession(.adopt, title: "采纳批量新建", body: batchSummary(drafts))
        AgentTelemetry.track("agent_canvas_drafts_adopted", properties: ["count": "\(drafts.count)"])
    }

    private func batchSummary(_ drafts: [BatchCreateDraft]) -> String {
        drafts.prefix(6)
            .map { "\($0.kind.title) · \($0.name)" }
            .joined(separator: "\n")
    }

    // MARK: - 真实灵感研究：检索、核验、转译三步均会留下可见日志。

    @ViewBuilder
    private var inspirationPanel: some View {
        if isResearchingInspiration {
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text("正在检索公开资料并核验来源…").font(AtlasFont.caption)
            }
            .foregroundStyle(AtlasColor.textSecondary)
            .frame(width: 560, alignment: .leading)
            .padding(.horizontal, AtlasSpacing.m).padding(.vertical, AtlasSpacing.s)
            .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        } else if let proposal = inspirationProposal {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield").font(.system(size: 11))
                    Text("已核验的\(proposal.domain.title)灵感").font(AtlasFont.label)
                    Spacer()
                    Text("\(String(format: "%.1f", proposal.duration))s").font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                .foregroundStyle(AtlasColor.textSecondary)

                ForEach(proposal.cards) { card in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.title).font(AtlasFont.caption).foregroundStyle(AtlasColor.textPrimary).lineLimit(1)
                        Text(card.fact).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textSecondary).lineLimit(2)
                        Text(card.creativeAngle).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary).lineLimit(2)
                        Link(card.source.provider, destination: card.source.url)
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.auroraMint)
                    }
                    .padding(.vertical, 3)
                }

                HStack(spacing: AtlasSpacing.s) {
                    Button { adoptInspirationProposal() } label: {
                        AtlasButtonLabel(title: "采纳为便签", systemImage: "checkmark")
                    }
                    .buttonStyle(.atlas(.primary))
                    Button { dismissInspirationProposal() } label: {
                        AtlasButtonLabel(title: "丢弃", systemImage: "xmark")
                    }
                    .buttonStyle(.atlas(.glass))
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
            .frame(width: 560, alignment: .leading)
            .padding(.horizontal, AtlasSpacing.m).padding(.vertical, AtlasSpacing.s)
            .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        }
    }

    private func researchInspiration(_ text: String) {
        isResearchingInspiration = true
        inspirationProposal = nil
        AgentTelemetry.track("agent_inspiration_requested")
        appendSession(.research, title: "选择资料源", body: "正在判断这是自然、历史还是文化方向。")

        Task { @MainActor in
            do {
                let proposal = try await InspirationResearchService().research(query: text)
                appendSession(.research, title: "已找到公开资料", body: "从 \(Set(proposal.cards.map { $0.source.provider }).joined(separator: "、")) 找到 \(proposal.cards.count) 条可用资料。")
                AgentTelemetry.track("agent_inspiration_sources_loaded", properties: ["domain": proposal.domain.rawValue, "count": "\(proposal.cards.count)"])
                appendSession(.verify, title: "来源核验完成", body: "每条灵感都绑定了可打开的原始资料链接。")
                AgentTelemetry.track("agent_inspiration_sources_verified", properties: ["domain": proposal.domain.rawValue, "count": "\(proposal.cards.count)"])
                withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) { inspirationProposal = proposal }
                AgentTelemetry.track("agent_inspiration_proposed", properties: ["domain": proposal.domain.rawValue, "count": "\(proposal.cards.count)"])
            } catch {
                appendSession(.research, title: "研究没有完成", body: error.localizedDescription)
                AgentTelemetry.track("agent_inspiration_failed", properties: ["reason": "source_unavailable"])
            }
            isResearchingInspiration = false
        }
    }

    private func adoptInspirationProposal() {
        guard let proposal = inspirationProposal else { return }
        let center = screenToWorld(CGPoint(x: viewSize.width / 2, y: viewSize.height / 2))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
            for (index, card) in proposal.cards.enumerated() {
                let id = store.add(.note, at: CGPoint(x: center.x + CGFloat(index) * 230, y: center.y))
                if let objectIndex = store.objects.firstIndex(where: { $0.id == id }) {
                    store.objects[objectIndex].name = card.title
                    store.objects[objectIndex].summary = "事实资料：\(card.fact)\n\n创作转译：\(card.creativeAngle)\n\n来源：\(card.source.provider)\n\(card.source.url.absoluteString)"
                    store.objects[objectIndex].aiAssisted = true
                }
            }
            inspirationProposal = nil
        }
        appendSession(.adopt, title: "采纳灵感便签", body: "已写入 \(proposal.cards.count) 张带来源的便签草稿。")
        AgentTelemetry.track("agent_inspiration_adopted", properties: ["domain": proposal.domain.rawValue, "count": "\(proposal.cards.count)"])
    }

    private func dismissInspirationProposal() {
        guard let proposal = inspirationProposal else { return }
        withAnimation(.easeOut(duration: 0.2)) { inspirationProposal = nil }
        appendSession(.parse, title: "丢弃灵感方案", body: "未写入画布，资料来源仍保留在本次智能体日志中。")
        AgentTelemetry.track("agent_inspiration_dismissed", properties: ["domain": proposal.domain.rawValue])
    }

    private func select(_ id: String?) {
        guard let id else {
            withAnimation(.snappy(duration: 0.22)) { store.clearSelection() }
            return
        }
        // 按住 ⇧ 或 ⌘ 点选 → 加入/移出多选；否则单选。
        let mods = NSEvent.modifierFlags
        withAnimation(.snappy(duration: 0.22)) {
            if mods.contains(.command) || mods.contains(.shift) {
                store.toggle(id)
            } else {
                store.selectedID = id
            }
        }
    }

    private func selectRelation(_ id: String) {
        withAnimation(.snappy(duration: 0.2)) { store.selectRelation(id) }
    }

    // Delete / Backspace 删除全部选中对象（编辑文本时不拦截）。
    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if showMapEditor { return event }
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSText || responder is NSTextView { return event }
            guard event.keyCode == 51 || event.keyCode == 117 else { return event }   // 51=Backspace 117=Delete
            if !store.selectedIDs.isEmpty {
                let ids = store.selectedIDs
                withAnimation(.snappy(duration: 0.22)) { ids.forEach { store.delete($0) } }
                return nil
            }
            if let rel = store.selectedRelationID {
                withAnimation(.snappy(duration: 0.22)) { store.removeLink(rel) }
                return nil
            }
            return event
        }
    }

    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // 右键在指针处新建卡片
    private func createCard(_ kind: BuilderKind, atCanvas point: CGPoint) {
        let world = screenToWorld(point == .zero
                                  ? CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                                  : point)
        withAnimation(.snappy(duration: 0.25)) {
            _ = store.add(kind, at: world)
        }
    }

    private func openMapEditor(_ id: String) {
        store.selectedID = id
        withAnimation(.snappy(duration: 0.3)) { showMapEditor = true }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard marqueeStart == nil else { return }   // 框选进行中不平移
                pan = CGSize(width: panStart.width + value.translation.width,
                             height: panStart.height + value.translation.height)
            }
            .onEnded { _ in panStart = pan }
    }

    // 长按（约 0.28s）后拖动 → 框选。快速拖动则长按失败，落回平移。
    private var marqueeGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.28)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas")))
            .onChanged { value in
                if case .second(true, let drag?) = value {
                    if marqueeStart == nil { marqueeStart = drag.startLocation }
                    marqueeCurrent = drag.location
                    if let rect = marqueeScreenRect {
                        store.selectInRect(screenRectToWorld(rect), additive: false)
                    }
                }
            }
            .onEnded { _ in marqueeStart = nil; marqueeCurrent = nil }
    }

    private var marqueeScreenRect: CGRect? {
        guard let a = marqueeStart, let b = marqueeCurrent else { return nil }
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                      width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func screenRectToWorld(_ rect: CGRect) -> CGRect {
        let origin = screenToWorld(rect.origin)
        return CGRect(x: origin.x, y: origin.y,
                      width: rect.width / scale, height: rect.height / scale)
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = zoomAnchor ?? scale
                if zoomAnchor == nil { zoomAnchor = scale }
                zoom(to: min(2.2, max(0.4, base * value.magnification)), around: canvasScreenCenter)
            }
            .onEnded { _ in zoomAnchor = nil; panStart = pan }
    }

    // 触摸板双指滑动 → 平移；⌘ + 滑动 → 缩放。macOS 原生滚轮事件。
    private func startScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            if showMapEditor { return event }          // 地图编辑器打开时交给它
            if event.modifierFlags.contains(.command) {
                let factor = 1 - event.scrollingDeltaY * 0.004
                zoom(to: min(2.2, max(0.4, scale * factor)), around: canvasScreenCenter)
            } else {
                pan.width += event.scrollingDeltaX
                pan.height += event.scrollingDeltaY
                panStart = pan
            }
            return nil
        }
    }

    private var canvasScreenCenter: CGPoint {
        CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
    }

    private func centerCanvas(in size: CGSize) {
        let center = contentWorldCenter
        pan = CGSize(width: size.width / 2 - center.x * scale,
                     height: size.height / 2 - center.y * scale)
        panStart = pan
    }

    private var contentWorldCenter: CGPoint {
        guard !store.objects.isEmpty else { return CGPoint(x: 600, y: 400) }
        let rects = store.objects.map { object in
            CGRect(
                x: object.position.x - object.size.width / 2,
                y: object.position.y - object.size.height / 2,
                width: object.size.width,
                height: object.size.height
            )
        }
        let bounds = rects.dropFirst().reduce(rects[0]) { $0.union($1) }
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    private func zoom(to newScale: CGFloat, around screenPoint: CGPoint) {
        guard newScale != scale else { return }
        let worldAnchor = screenToWorld(screenPoint)
        scale = newScale
        pan = CGSize(width: screenPoint.x - worldAnchor.x * newScale,
                     height: screenPoint.y - worldAnchor.y * newScale)
        panStart = pan
    }

    private func stopScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    // MARK: - 坐标变换

    private func worldToScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * scale + pan.width, y: p.y * scale + pan.height)
    }

    private func screenToWorld(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - pan.width) / scale, y: (p.y - pan.height) / scale)
    }

    private func organicPath(in rect: CGRect, phase: CGFloat) -> Path {
        var path = Path()
        let samples = 40
        for index in 0...samples {
            let angle = CGFloat(index) / CGFloat(samples) * .pi * 2
            let variation = 1 + 0.08 * sin(angle * 3 + phase) + 0.05 * cos(angle * 5 - phase)
            let point = CGPoint(
                x: rect.midX + cos(angle) * rect.width * 0.5 * variation,
                y: rect.midY + sin(angle) * rect.height * 0.5 * variation
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 画布上的卡片（每类卡片有自己的设计；可拉角改尺寸）

private struct ObjectCard: View {
    var object: BuilderObject
    var scale: CGFloat
    var selected: Bool
    @ObservedObject var store: WorldBuilderStore
    var canEdit: Bool
    var onSelect: () -> Void
    var onExpand: () -> Void

    @State private var hoverLocal: CGPoint?
    @State private var moveStart: CGPoint?
    @State private var resizeStart: (center: CGPoint, size: CGSize)?
    @State private var activeCorner: Int?          // 当前贴近的角（0左上 1右上 2左下 3右下）

    var pan: CGSize
    /// 布局锁定（时间线投影：位置由算法接管，禁用拖动/改尺寸，仅可选中）。
    var layoutLocked: Bool = false
    /// 淡化（时间线里非事件卡）。
    var dimmed: Bool = false

    private let radius: CGFloat = 16
    private let arcMargin: CGFloat = 22            // 弧线画布向外扩，好让弧落在圆角外面
    private let cornerThreshold: CGFloat = 42      // 弧显示 与 触发改尺寸 用同一判定，保证一致

    private var screenW: CGFloat { object.size.width * scale }
    private var screenH: CGFloat { object.size.height * scale }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }

    private func worldToScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * scale + pan.width, y: p.y * scale + pan.height)
    }

    var body: some View {
        content
            .frame(width: screenW, height: screenH)
            .clipShape(shape)
            .atlasP1Glass(shape)                       // Apple 液态玻璃（星图同款 P1 玻璃）
            .overlay(shape.stroke(selected ? Color.white.opacity(0.6) : Color.clear,
                                  lineWidth: 1.5))
            .overlay { cornerArcs }
            .contentShape(shape)
            .onContinuousHover { phase in
                switch phase {
                case .active(let p):
                    hoverLocal = p
                    activeCorner = (layoutLocked || !canEdit) ? nil : nearestResizeCorner(p)
                case .ended:
                    hoverLocal = nil
                    activeCorner = nil
                }
            }
            .gesture(unifiedDrag)
            .onTapGesture { onSelect() }
            .contextMenu {
                if canEdit {
                    if object.kind == .map {
                        Button { onExpand() } label: { Label("展开编辑地图", systemImage: "arrow.up.left.and.arrow.down.right") }
                    }
                    Button { onSelect() } label: { Label("编辑详情", systemImage: "pencil") }
                    Button { store.bringToFront(object.id) } label: { Label("置于顶层", systemImage: "square.3.layers.3d.top.filled") }
                    Divider()
                    Button(role: .destructive) { store.delete(object.id) } label: { Label("删除卡片", systemImage: "trash") }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if object.kind == .map {
            MapCardBody(name: store.displayName(object), onExpand: onExpand)
        } else {
            InfoCardBody(object: object, displayName: store.displayName(object))
        }
    }

    // 鼠标靠近角 → 角外渐显与圆角同曲率的小弧。每个角一条弧，进入/离开角区时淡入淡出。
    private var cornerArcs: some View {
        let m = arcMargin
        let centers: [CGPoint] = [
            CGPoint(x: m + radius, y: m + radius),
            CGPoint(x: m + screenW - radius, y: m + radius),
            CGPoint(x: m + radius, y: m + screenH - radius),
            CGPoint(x: m + screenW - radius, y: m + screenH - radius)
        ]
        let startDeg: [Double] = [180, 270, 90, 0]
        return ZStack {
            ForEach(0..<4, id: \.self) { i in
                CornerArcShape(center: centers[i], radius: radius + 7, startDeg: startDeg[i])
                    .stroke(Color.white.opacity(0.95),
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    .opacity(activeCorner == i ? 1 : 0)
                    .animation(.easeOut(duration: 0.22), value: activeCorner)
            }
        }
        .frame(width: screenW + 2 * m, height: screenH + 2 * m)
        .allowsHitTesting(false)
    }

    /// 到最近角的距离小于阈值 → 返回角序号，否则 nil。弧显示与改尺寸共用同一判定。
    private func nearestResizeCorner(_ p: CGPoint) -> Int? {
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: screenW, y: 0),
                       CGPoint(x: 0, y: screenH), CGPoint(x: screenW, y: screenH)]
        var best: Int?
        var bestDist = cornerThreshold
        for i in 0..<4 {
            let d = hypot(p.x - corners[i].x, p.y - corners[i].y)
            if d < bestDist { bestDist = d; best = i }
        }
        return best
    }

    private func cornerSign(_ index: Int) -> (CGFloat, CGFloat) {
        switch index {
        case 0: return (-1, -1)
        case 1: return (1, -1)
        case 2: return (-1, 1)
        default: return (1, 1)
        }
    }

    // 单一手势：按落点判断——落在角附近=改尺寸，否则=移动。避免子手势与移动手势抢优先级。
    private enum DragKind { case move; case resize(CGFloat, CGFloat) }
    @State private var dragMode: DragKind?

    private var unifiedDrag: some Gesture {
        // 用稳定的 canvas 坐标系（不随卡片移动），否则 .local 空间会随卡片位移形成反馈环 → 抖动。
        DragGesture(minimumDistance: 3, coordinateSpace: .named("canvas"))
            .onChanged { value in
                if !canEdit { return }
                if layoutLocked { return }        // 时间线：位置由算法接管，禁拖动
                if dragMode == nil {
                    // 把起点换算成卡片本地坐标，判断是否落在角上
                    let centerScreen = worldToScreen(object.position)
                    let localStart = CGPoint(x: value.startLocation.x - (centerScreen.x - screenW / 2),
                                             y: value.startLocation.y - (centerScreen.y - screenH / 2))
                    if let idx = nearestResizeCorner(localStart) {
                        dragMode = .resize(cornerSign(idx).0, cornerSign(idx).1)
                        resizeStart = (object.position, object.size)
                        activeCorner = idx          // 拖动期间保持这条弧亮着
                    } else {
                        dragMode = .move
                        moveStart = object.position
                        if selected && store.selectedIDs.count > 1 { store.beginGroupDrag() }
                    }
                    store.bringToFront(object.id)
                    if !selected { store.selectOnly(object.id) }
                }
                switch dragMode {
                case .resize(let sx, let sy)?: applyResize(sx: sx, sy: sy, translation: value.translation)
                case .move?: applyMove(translation: value.translation)
                case nil: break
                }
            }
            .onEnded { _ in
                dragMode = nil; moveStart = nil; resizeStart = nil
                activeCorner = nil
                store.endGroupDrag()
            }
    }

    private func applyMove(translation: CGSize) {
        let dx = translation.width / scale, dy = translation.height / scale
        if selected && store.selectedIDs.count > 1 {
            store.groupDrag(by: CGSize(width: dx, height: dy))
        } else if let start = moveStart {
            store.move(object.id, to: CGPoint(x: start.x + dx, y: start.y + dy))
        }
    }

    private func applyResize(sx: CGFloat, sy: CGFloat, translation: CGSize) {
        guard let start = resizeStart else { return }
        let dW = translation.width / scale, dH = translation.height / scale
        let opposite = CGPoint(x: start.center.x - sx * start.size.width / 2,
                               y: start.center.y - sy * start.size.height / 2)
        let draggedX = start.center.x + sx * start.size.width / 2 + dW
        let draggedY = start.center.y + sy * start.size.height / 2 + dH
        let minS = object.kind.minSize
        let newW = max(minS.width, (draggedX - opposite.x) * sx)
        let newH = max(minS.height, (draggedY - opposite.y) * sy)
        let cornerX = opposite.x + sx * newW
        let cornerY = opposite.y + sy * newH
        store.resize(object.id,
                     size: CGSize(width: newW, height: newH),
                     center: CGPoint(x: (opposite.x + cornerX) / 2, y: (opposite.y + cornerY) / 2))
    }
}

// 角上的四分之一圆弧（与卡片圆角同曲率，落在圆角外侧一点）
private struct CornerArcShape: Shape {
    var center: CGPoint
    var radius: CGFloat
    var startDeg: Double
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(startDeg), endAngle: .degrees(startDeg + 90),
                    clockwise: false)
        return path
    }
}

// MARK: - 地图卡：地图底盘的预览 + 展开入口

private struct MapCardBody: View {
    var name: String
    var onExpand: () -> Void

    var body: some View {
        ZStack {
            // 极淡制图预览
            Canvas { ctx, size in
                let rects = [
                    CGRect(x: size.width * 0.16, y: size.height * 0.26, width: size.width * 0.40, height: size.height * 0.44),
                    CGRect(x: size.width * 0.50, y: size.height * 0.34, width: size.width * 0.34, height: size.height * 0.40)
                ]
                for (i, rect) in rects.enumerated() {
                    let path = islandPath(in: rect, phase: CGFloat(i) * 0.8)
                    ctx.fill(path, with: .color(.white.opacity(0.06)))
                    ctx.stroke(path, with: .color(.white.opacity(0.20)), lineWidth: 1)
                    for inset in stride(from: CGFloat(10), through: 34, by: 12) {
                        let r = rect.insetBy(dx: inset, dy: inset * 0.6)
                        if r.width > 14 {
                            ctx.stroke(islandPath(in: r, phase: CGFloat(i) * 0.8 + inset * 0.02),
                                       with: .color(.white.opacity(0.05)), lineWidth: 0.6)
                        }
                    }
                }
            }

            VStack {
                HStack(spacing: AtlasSpacing.s) {
                    KindIcon(symbol: "map.fill")
                    Text(name).font(AtlasFont.monoSmall).tracking(1)
                        .foregroundStyle(AtlasColor.textSecondary)
                    Spacer()
                    Button(action: onExpand) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .foregroundStyle(AtlasColor.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .atlasP1Glass(Circle(), interactive: true)
                    .help("展开编辑地图")
                }
                Spacer()
            }
            .padding(AtlasSpacing.s)
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onExpand() })
    }

    private func islandPath(in rect: CGRect, phase: CGFloat) -> Path {
        var path = Path()
        let samples = 36
        for index in 0...samples {
            let angle = CGFloat(index) / CGFloat(samples) * .pi * 2
            let variation = 1 + 0.09 * sin(angle * 3 + phase) + 0.05 * cos(angle * 5 - phase)
            let point = CGPoint(x: rect.midX + cos(angle) * rect.width * 0.5 * variation,
                                y: rect.midY + sin(angle) * rect.height * 0.5 * variation)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 普通对象卡：随类型微调设计

private struct InfoCardBody: View {
    var object: BuilderObject
    var displayName: String

    private enum Tier { case compact, regular, large }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let tier: Tier = (w < 176 || h < 116) ? .compact : (w < 300 ? .regular : .large)
            layout(tier)
                .padding(pad(tier))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func layout(_ tier: Tier) -> some View {
        // 内容始终聚在左上角成组，底部用 Spacer 兜住，避免极端长宽比时被撑到两端。
        switch tier {
        case .compact:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    KindIcon(symbol: object.kind.symbol, size: 20)
                    Spacer(minLength: 0)
                    if object.aiAssisted {
                        Image(systemName: "sparkle").font(.system(size: 8))
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                }
                Text(displayName)
                    .font(nameFont(tier))
                    .foregroundStyle(AtlasColor.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: tier == .large ? AtlasSpacing.s : 6) {
                HStack(spacing: AtlasSpacing.s) {
                    KindIcon(symbol: object.kind.symbol, size: tier == .large ? 26 : 24)
                    Text(object.kind.title)
                        .font(AtlasFont.monoSmall).tracking(1)
                        .foregroundStyle(AtlasColor.textTertiary)
                    Spacer(minLength: 0)
                    if object.aiAssisted {
                        Image(systemName: "sparkle").font(.system(size: 8))
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                }

                Text(displayName)
                    .font(nameFont(tier))
                    .foregroundStyle(AtlasColor.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                if object.kind == .event, let time = object.time {
                    TimeChip(time: time)
                }

                if object.summary.isEmpty {
                    Text(object.kind.hint)
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                        .lineLimit(tier == .large ? 2 : 1)
                } else {
                    Text(object.summary)
                        .font(tier == .large ? AtlasFont.body : AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(tier == .large ? 5 : 2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func pad(_ tier: Tier) -> CGFloat {
        switch tier {
        case .compact: return 11
        case .regular: return AtlasSpacing.m
        case .large:   return AtlasSpacing.l
        }
    }

    private func nameFont(_ tier: Tier) -> Font {
        if object.kind == .note {
            switch tier {
            case .compact: return AtlasFont.body
            case .regular: return .system(size: 16)
            case .large:   return .system(size: 19)
            }
        }
        switch tier {
        case .compact: return AtlasFont.serif(15, weight: .medium)
        case .regular: return AtlasFont.serif(20, weight: .medium)
        case .large:   return AtlasFont.serif(26, weight: .medium)
        }
    }
}

// MARK: - 统一的类型图标容器
// 所有卡片类型共用同一个图标外壳（固定圆角方形），只有里面的 SF Symbol 不同。

struct KindIcon: View {
    var symbol: String
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(AtlasColor.textPrimary)
            .frame(width: size, height: size)
            .background(Color.white.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(AtlasColor.borderSubtle))
    }
}

// MARK: - 类型字形（形状 + 图标，黑白）

struct NodeGlyph: View {
    var shape: BuilderShape
    var symbol: String
    var size: CGFloat
    var emphasized: Bool = false

    var body: some View {
        ZStack {
            glyphShape
                .fill(emphasized ? Color.white : Color(white: 0.42))
            glyphShape
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(emphasized ? AtlasColor.inverse : AtlasColor.textPrimary)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
    }

    private var glyphShape: AnyShape {
        switch shape {
        case .pin, .circle: return AnyShape(Circle())
        case .square: return AnyShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        case .note: return AnyShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        case .hexagon: return AnyShape(PolygonShape(sides: 6, rotation: .degrees(90)))
        case .diamond: return AnyShape(PolygonShape(sides: 4, rotation: .degrees(45)))
        }
    }
}

struct PolygonShape: Shape {
    var sides: Int
    var rotation: Angle = .zero
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for i in 0..<sides {
            let angle = rotation.radians + Double(i) / Double(sides) * 2 * .pi
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                y: center.y + CGFloat(sin(angle)) * radius)
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 详情卡（点击对象后可编辑）

private struct DetailCard: View {
    @Binding var object: BuilderObject
    @ObservedObject var store: WorldBuilderStore
    var onDelete: () -> Void

    /// 事件时间的非可选绑定（object.time 为 nil 时给一个默认阶段）。
    private var eventTimeBinding: Binding<EventTime> {
        Binding(
            get: { object.time ?? EventTime(phase: .rising) },
            set: { object.time = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            HStack {
                Menu {
                    ForEach(BuilderKind.allCases) { kind in
                        Button { object.kind = kind } label: {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                    }
                } label: {
                    HStack(spacing: AtlasSpacing.s) {
                        NodeGlyph(shape: object.kind.shape, symbol: object.kind.symbol, size: 22)
                        Text(object.kind.title).font(AtlasFont.caption)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(AtlasColor.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                Button { store.selectedID = nil } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AtlasColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text("名称").font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                TextField("未命名\(object.kind.title)", text: $object.name)
                    .textFieldStyle(.plain)
                    .font(AtlasFont.serifHeading)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .padding(AtlasSpacing.s)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                    if object.kind == .event {
                        EventTimeSection(time: eventTimeBinding)
                        Divider().overlay(AtlasColor.borderSubtle)
                    }

                    VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                        Text("档案内容").font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                        BuilderMentionEditor(object: $object, store: store)
                    }

                    // 关联区：结构性 / 关系性 link（地图/规则/便签无关联字段，不显示）
                    if !BuilderLinkRules.fields(for: object.kind).isEmpty {
                        Divider().overlay(AtlasColor.borderSubtle)
                        BuilderLinkSection(object: object, store: store)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Spacer(minLength: AtlasSpacing.s)

            Button(role: .destructive) { onDelete() } label: {
                AtlasButtonLabel(title: "从画布移除", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.atlas(.glass))
        }
        .padding(AtlasSpacing.l)
        .frame(maxHeight: .infinity, alignment: .top)
        .atlasFrostedPanel(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
    }
}
