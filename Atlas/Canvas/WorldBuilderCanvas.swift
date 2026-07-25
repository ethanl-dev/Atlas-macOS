import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var showCommandFileImporter = false
    @State private var importedCommandFileName: String?
    @State private var selectedFixedSkill: FixedCanvasSkill?
    @State private var showCanvasImagePicker = false
    @State private var attachedCanvasImageIDs: [String] = []
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
    @State private var organizeDetailsExpanded = false
    @State private var thinkingGlowExpanded = false
    @State private var thinkingBorderRotation = 0.0
    @State private var agentBuildCursor: AgentBuildCursor?
    @State private var isAgentBuilding = false
    @State private var sessionEntries: [AgentSessionEntry] = [
        .init(kind: .system, title: "智能体日志", body: "这里会记录你的指令、解析结果和采纳动作。")
    ]
    @State private var showWorldNameEditor = false
    @State private var worldNameDraft = ""
    @FocusState private var worldNameEditorFocused: Bool

    @StateObject private var organizer = CanvasOrganizer()
    @State private var commandMode: CommandMode = .place
    private enum CommandMode { case place, research, organize }
    private enum FixedCanvasSkill: String, CaseIterable, Identifiable {
        case cardBuilder
        case sourceResearch
        case relationshipOrganizer

        var id: String { rawValue }
        var title: String {
            switch self {
            case .cardBuilder: return "结构化建档"
            case .sourceResearch: return "真实资料灵感"
            case .relationshipOrganizer: return "关系与布局整理"
            }
        }
        var symbol: String {
            switch self {
            case .cardBuilder: return "rectangle.stack.badge.plus"
            case .sourceResearch: return "doc.text.magnifyingglass"
            case .relationshipOrganizer: return "point.3.connected.trianglepath.dotted"
            }
        }
        var mode: CommandMode {
            switch self {
            case .cardBuilder: return .place
            case .sourceResearch: return .research
            case .relationshipOrganizer: return .organize
            }
        }
    }
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

    private struct AgentBuildCursor {
        var position: CGPoint
        var label: String
        var targetCenter: CGPoint?
        var targetSize: CGSize?
        var progress: Double
    }

    private struct CanvasImageAttachment: Identifiable {
        var id: String { objectID }
        var objectID: String
        var title: String
        var source: String
        var kind: BuilderKind
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
        .fileImporter(
            isPresented: $showCommandFileImporter,
            allowedContentTypes: commandFileTypes
        ) { result in
            handleCommandFileImport(result)
        }
    }

    // MARK: - 画布舞台

    private var canvasStage: some View {
        GeometryReader { proxy in
            let timeline = store.projection == .timeline
                ? TimelineLayout.make(events: store.objects.filter { $0.kind == .event })
                : TimelineLayout()
            ZStack {
                AtlasCanvasBackground(animated: true)
                    .allowsHitTesting(false)

                // 专门接住空白处点击 → 取消选中（放在卡片下面；点卡片会被卡片先接走）
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { select(nil) }

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
                    let world = (onTimeline ? timeline.positions[object.id] : nil) ?? organizePreviewPosition(for: object)
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
                    .animation(.spring(response: 0.55, dampingFraction: 0.84), value: onTimeline)
                    .animation(.spring(response: 0.58, dampingFraction: 0.82), value: organizeDetailsExpanded)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }

                organizePreviewLinkLayer
                agentBuildOverlay

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

    // 关系连线：拟物「悬挂缆绳」。缆绳从卡片边缘接出，在重力方向自然下垂（悬链线）；
    // 强度 → 线宽/亮度；提议中的关系用虚线；选中提亮。同一对卡片的多条关系呈扇形错开，避免重叠。
    private func relationLayer(in size: CGSize) -> some View {
        Canvas { context, _ in
            for item in cableItems() {
                let r = item.relation
                let path = item.geometry.path
                let op = item.selected ? 0.92 : r.strength.opacity
                let w = item.selected ? r.strength.lineWidth + 0.8 : r.strength.lineWidth

                if r.proposed {
                    context.stroke(path, with: .color(.white.opacity(max(op, 0.4))),
                                   style: .init(lineWidth: r.strength.lineWidth, lineCap: .round, dash: [6, 5]))
                } else {
                    // 外发光 → 缆身 → 高光芯，模拟有体积的圆缆绳
                    context.stroke(path, with: .color(.white.opacity(op * 0.14)),
                                   style: .init(lineWidth: w + 3, lineCap: .round))
                    context.stroke(path, with: .color(.white.opacity(op)),
                                   style: .init(lineWidth: w, lineCap: .round))
                    context.stroke(path, with: .color(.white.opacity(min(op * 0.9 + 0.12, 1))),
                                   style: .init(lineWidth: max(w * 0.4, 0.6), lineCap: .round))
                }

                // 两端「接口」小铆点，坐实缆绳插在卡片上
                for pt in [item.geometry.p0, item.geometry.p1] {
                    let nub = max(w * 0.85, 1.8)
                    context.fill(Path(ellipseIn: CGRect(x: pt.x - nub, y: pt.y - nub,
                                                        width: nub * 2, height: nub * 2)),
                                 with: .color(.white.opacity(min(op + 0.14, 0.8))))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // 关系 chip：挂在各自缆绳的最低点（下垂点）。多条关系的最低点天然错开，chip 不再叠在一起。
    @ViewBuilder
    private func relationChips(in size: CGSize) -> some View {
        ForEach(cableItems(), id: \.relation.id) { item in
            RelationChip(relation: item.relation, selected: item.selected) {
                selectRelation(item.relation.id)
            }
            .position(item.geometry.bottom)
        }
    }

    // MARK: - 缆绳几何

    private struct CableGeometry {
        var p0: CGPoint      // 卡片 A 边缘接点（屏幕坐标）
        var p1: CGPoint      // 卡片 B 边缘接点
        var bottom: CGPoint  // 缆绳最低点（chip 悬挂处）
        var path: Path
    }

    private struct CableItem {
        var relation: BuilderRelation
        var selected: Bool
        var geometry: CableGeometry
    }

    /// 无序对 key，用于把同一对卡片之间的多条关系聚在一起做扇形错开。
    private func pairKey(_ a: String, _ b: String) -> String {
        a < b ? a + "|" + b : b + "|" + a
    }

    /// 组装所有关系的缆绳几何：先按卡片对分组编号，再逐条算下垂曲线。
    private func cableItems() -> [CableItem] {
        var total: [String: Int] = [:]
        var index: [String: Int] = [:]
        for r in store.relations {
            let k = pairKey(r.sourceID, r.targetID)
            let i = total[k, default: 0]
            index[r.id] = i
            total[k] = i + 1
        }

        let rects = cardRectsScreen()   // chip 需要避开的所有卡片矩形（屏幕坐标）

        var items: [CableItem] = []
        for r in store.relations {
            guard let a = store.objects.first(where: { $0.id == r.sourceID }),
                  let b = store.objects.first(where: { $0.id == r.targetID }) else { continue }
            let k = pairKey(r.sourceID, r.targetID)
            let geo = cableGeometry(a: a, b: b,
                                    index: index[r.id] ?? 0,
                                    total: total[k] ?? 1,
                                    avoiding: rects)
            items.append(.init(relation: r,
                               selected: store.selectedRelationID == r.id,
                               geometry: geo))
        }
        return items
    }

    /// 单条缆绳：卡片边缘接点 + 重力下垂的二次贝塞尔；同对多条按序错开扇形。
    private func cableGeometry(a: BuilderObject, b: BuilderObject, index: Int, total: Int, avoiding rects: [CGRect]) -> CableGeometry {
        let aPosition = organizePreviewPosition(for: a)
        let bPosition = organizePreviewPosition(for: b)
        let anchorA = edgeAnchor(center: aPosition, size: a.size, toward: bPosition)
        let anchorB = edgeAnchor(center: bPosition, size: b.size, toward: aPosition)
        let p0 = worldToScreen(anchorA)
        let p1 = worldToScreen(anchorB)

        let dx = p1.x - p0.x, dy = p1.y - p0.y
        let len = max(hypot(dx, dy), 1)
        let nx = -dy / len                       // 单位法线（用于侧向轻微弓起 + 扇形铺开）
        let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)

        // 扇形偏移：同对第 index 条相对中心的错位量（… -1,0,1 …）
        let spread = total > 1 ? CGFloat(index) - CGFloat(total - 1) / 2 : 0
        // 下垂量随跨度增长并夹在合理区间；每条依次垂得更低，形成层叠缆绳。
        let drop = min(max(len * 0.15, 26 * scale), 150 * scale)
                 + CGFloat(index) * 24 * scale
        // 控制点：竖直方向 2*drop（二次贝塞尔中点挠度 = drop）+ 轻微侧向弓起与扇形位移。
        let lateral = nx * (drop * 0.2 + spread * 34 * scale)
        let control = CGPoint(x: mid.x + lateral, y: mid.y + 2 * drop)

        var path = Path()
        path.move(to: p0)
        path.addQuadCurve(to: p1, control: control)

        return CableGeometry(p0: p0, p1: p1,
                             bottom: chipAnchor(p0: p0, control: control, p1: p1, avoiding: rects),
                             path: path)
    }

    /// 从卡片中心沿指向对方的方向，求与卡片矩形边框的交点（缆绳接口）。
    private func edgeAnchor(center: CGPoint, size: CGSize, toward other: CGPoint) -> CGPoint {
        let dx = other.x - center.x, dy = other.y - center.y
        if dx == 0 && dy == 0 { return center }
        let sx = dx == 0 ? CGFloat.infinity : (size.width / 2) / abs(dx)
        let sy = dy == 0 ? CGFloat.infinity : (size.height / 2) / abs(dy)
        let s = min(sx, sy)
        return CGPoint(x: center.x + dx * s, y: center.y + dy * s)
    }

    /// 所有卡片的屏幕矩形（含整理预览位移），chip 需避开它们。
    private func cardRectsScreen() -> [CGRect] {
        store.objects.map { o in
            let c = worldToScreen(organizePreviewPosition(for: o))
            let w = o.size.width * scale, h = o.size.height * scale
            return CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        }
    }

    /// 点到一组矩形的最短净空（在矩形内为 0）。
    private func clearance(of p: CGPoint, from rects: [CGRect]) -> CGFloat {
        guard !rects.isEmpty else { return .greatestFiniteMagnitude }
        var best = CGFloat.greatestFiniteMagnitude
        for r in rects {
            if r.contains(p) { return 0 }
            let dx = max(r.minX - p.x, p.x - r.maxX, 0)
            let dy = max(r.minY - p.y, p.y - r.maxY, 0)
            best = min(best, hypot(dx, dy))
        }
        return best
    }

    /// chip 挂点：限制在缆绳中段（避开两端卡片边缘），并挑选离所有卡片最远的位置，
    /// 避免下垂点滑到卡片上导致文字看不清。中段内有足够净空则取最低点，保留悬挂感。
    private func chipAnchor(p0: CGPoint, control: CGPoint, p1: CGPoint, avoiding rects: [CGRect]) -> CGPoint {
        func point(_ t: CGFloat) -> CGPoint {
            let mt = 1 - t
            return CGPoint(x: mt * mt * p0.x + 2 * mt * t * control.x + t * t * p1.x,
                           y: mt * mt * p0.y + 2 * mt * t * control.y + t * t * p1.y)
        }
        let want: CGFloat = 30 * scale        // 期望的最小净空（约半个 chip + 间隙）
        let steps = 28
        var lowestClear: CGPoint? = nil
        var mostOpen = point(0.5)
        var mostOpenDist: CGFloat = -1

        for i in 0...steps {
            let t = 0.28 + 0.44 * CGFloat(i) / CGFloat(steps)   // 只在中段 [0.28, 0.72] 取点
            let q = point(t)
            let d = clearance(of: q, from: rects)
            if d > mostOpenDist { mostOpenDist = d; mostOpen = q }
            if d >= want, lowestClear == nil || q.y > lowestClear!.y { lowestClear = q }
        }
        return lowestClear ?? mostOpen
    }

    private func organizePreviewPosition(for object: BuilderObject) -> CGPoint {
        guard organizeDetailsExpanded, let plan = organizer.plan else { return object.position }
        return plan.ghostPositions[object.id] ?? object.position
    }

    @ViewBuilder
    private var organizePreviewLinkLayer: some View {
        if organizeDetailsExpanded, let plan = organizer.plan, !plan.proposedLinks.isEmpty {
            Canvas { context, _ in
                for link in plan.proposedLinks {
                    guard let a = store.objects.first(where: { $0.id == link.source }),
                          let b = store.objects.first(where: { $0.id == link.target }) else { continue }
                    let p0 = worldToScreen(organizePreviewPosition(for: a))
                    let p1 = worldToScreen(organizePreviewPosition(for: b))
                    let distance = max(hypot(p1.x - p0.x, p1.y - p0.y), 1)
                    let sag = min(max(distance * 0.13, 24 * scale), 120 * scale)
                    let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
                    var path = Path()
                    path.move(to: p0)
                    path.addQuadCurve(to: p1, control: CGPoint(x: mid.x, y: mid.y + 2 * sag))
                    context.stroke(
                        path,
                        with: .color(.white.opacity(0.66)),
                        style: .init(lineWidth: 1.6, lineCap: .round, dash: [7, 5])
                    )
                }
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var agentBuildOverlay: some View {
        if let cursor = agentBuildCursor {
            if let targetSize = cursor.targetSize, let targetCenter = cursor.targetCenter {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.38),
                            style: .init(lineWidth: 1, dash: [6, 5]))
                    .frame(width: targetSize.width * scale + 10,
                           height: targetSize.height * scale + 10)
                    .position(worldToScreen(targetCenter))
                    .allowsHitTesting(false)
            }

            HStack(spacing: 7) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.12))
                    Circle().stroke(Color.white.opacity(0.72), lineWidth: 1)
                    Circle().fill(Color.white).frame(width: 4, height: 4)
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(cursor.label)
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textPrimary)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.78))
                                    .frame(width: proxy.size.width * cursor.progress)
                            }
                    }
                    .frame(width: 72, height: 2)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.16)))
            .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
            .position(worldToScreen(cursor.position))
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.28), value: cursor.position)
            .animation(.linear(duration: 0.08), value: cursor.progress)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
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
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .atlasP1Glass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AtlasColor.textPrimary)
            .contentShape(Circle())
            .help("退出画布")

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: AtlasSpacing.s) {
                    Text(store.worldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名世界" : store.worldName)
                        .font(AtlasFont.serifHeading)
                        .foregroundStyle(AtlasColor.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: 210, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if canEdit { openWorldNameEditor() }
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

    // MARK: - 右侧详情卡

    @ViewBuilder
    private var detailPanel: some View {
        if canEdit, let rid = store.selectedRelationID, let rbind = store.relationBinding(for: rid) {
            RelationDetailCard(relation: rbind, store: store) {
                store.removeLink(rid)
            }
            .id(rid)
            .frame(width: 300)
            .padding(.trailing, AtlasSpacing.l)
            .padding(.top, 102)
            .padding(.bottom, AtlasSpacing.l)
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .trailing)))
        } else if let id = store.selectedID, let bind = store.binding(for: id) {
            DetailCard(object: bind, store: store) {
                store.delete(id)
            }
            .id(id)
            .frame(width: 300)
            .padding(.trailing, AtlasSpacing.l)
            .padding(.top, 102)
            .padding(.bottom, AtlasSpacing.l)
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .trailing)))
        }
    }

    // MARK: - 左侧 Session 记录

    private var sessionRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            assistantFloatingCard
                .padding(.top, 112)

            unlocatedMapTray
                .padding(.top, AtlasSpacing.m)

            Spacer(minLength: 0)

            sessionTray
        }
        .padding(.leading, AtlasSpacing.l)
        .padding(.bottom, 96)
        .frame(maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var unlocatedMapTray: some View {
        let pending = store.unlocatedObjects
        if canEdit, !pending.isEmpty {
            VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                HStack {
                    Label("待定位到地图", systemImage: "mappin.and.ellipse")
                        .font(AtlasFont.label)
                    Spacer()
                    Text("\(pending.count)")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textSecondary)
                }
                ForEach(pending.prefix(4)) { object in
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                            showMapEditor = true
                        }
                    } label: {
                        HStack(spacing: AtlasSpacing.s) {
                            Image(systemName: object.kind.symbol)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(store.displayName(object))
                                    .lineLimit(1)
                                Text(store.preferredMapPlacement(for: object).rawValue)
                                    .font(AtlasFont.caption)
                                    .foregroundStyle(AtlasColor.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textPrimary)
                        .padding(.horizontal, AtlasSpacing.s)
                        .frame(height: 42)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .atlasP1Glass(RoundedRectangle(cornerRadius: 12, style: .continuous), interactive: true)
                }

                if pending.count > 4 {
                    Text("另有 \(pending.count - 4) 张卡片")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }
            .padding(AtlasSpacing.m)
            .frame(width: 260)
            .atlasP1Glass(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
        }
    }

    private var assistantFloatingCard: some View {
        let shape = RoundedRectangle(
            cornerRadius: assistantCardExpanded ? 24 : 15,
            style: .continuous
        )
        return VStack(alignment: .leading, spacing: assistantCardExpanded ? AtlasSpacing.m : 0) {
            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    assistantCardExpanded.toggle()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AtlasColor.inverse)
                    .frame(width: 52, height: 22)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .help(assistantCardExpanded ? "收起回复卡" : "展开最新回复")

            if assistantCardExpanded {
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
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
            }
        }
        .padding(assistantCardExpanded ? AtlasSpacing.m : 4)
        .frame(width: assistantCardExpanded ? 330 : 60, alignment: .leading)
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
            in: shape
        )
        .background(.ultraThinMaterial, in: shape)
        .overlay(
            shape.stroke(
                Color.white.opacity(agentIsThinking ? (thinkingGlowExpanded ? 0.52 : 0.16) : 0.13),
                lineWidth: agentIsThinking ? 1.4 : 1
            )
        )
        .overlay {
            if agentIsThinking {
                AngularGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.08),
                        AtlasColor.auroraMint.opacity(0.72),
                        Color.white.opacity(0.92),
                        AtlasColor.auroraMint.opacity(0.24),
                        .clear,
                        .clear
                    ],
                    center: .center
                )
                .rotationEffect(.degrees(thinkingBorderRotation))
                .mask(shape.stroke(lineWidth: 2))
                .allowsHitTesting(false)
            }
        }
        .shadow(color: .black.opacity(0.34), radius: 22, y: 12)
        .shadow(
            color: Color.white.opacity(agentIsThinking ? (thinkingGlowExpanded ? 0.24 : 0.05) : 0),
            radius: thinkingGlowExpanded ? 24 : 8
        )
        .scaleEffect(
            agentIsThinking && !reduceMotion
                ? (thinkingGlowExpanded ? 1.006 : 0.998)
                : 1,
            anchor: .center
        )
        .offset(
            y: agentIsThinking && !reduceMotion
                ? (thinkingGlowExpanded ? -3 : 1)
                : 0
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: assistantCardExpanded)
        .onAppear { setThinkingGlow(agentIsThinking) }
        .onChange(of: agentIsThinking) { _, active in setThinkingGlow(active) }
    }

    private var sessionTray: some View {
        let shape = RoundedRectangle(
            cornerRadius: sessionExpanded ? AtlasRadius.panel : 18,
            style: .continuous
        )
        return VStack(alignment: .leading, spacing: 0) {
            if sessionExpanded {
                VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                    ForEach(recentSessionEntries) { entry in
                        sessionChip(entry)
                    }
                }
                .padding(.horizontal, AtlasSpacing.m)
                .padding(.top, AtlasSpacing.m)
                .padding(.bottom, AtlasSpacing.s)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottomLeading)))

                Divider().overlay(AtlasColor.borderSubtle)
            }

            Button {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    sessionExpanded.toggle()
                }
            } label: {
                HStack(spacing: AtlasSpacing.s) {
                    Image(systemName: "paperplane")
                    Text("智能体日志")
                        .font(AtlasFont.label)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: sessionExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AtlasColor.textPrimary)
                .padding(.horizontal, AtlasSpacing.m)
                .frame(height: sessionExpanded ? 48 : 38)
            }
            .buttonStyle(.plain)
        }
        .frame(width: sessionExpanded ? 330 : 154, alignment: .leading)
        .atlasFrostedPanel(shape)
        .animation(.spring(response: 0.44, dampingFraction: 0.86), value: sessionExpanded)
    }

    private var latestUserEntry: AgentSessionEntry? {
        sessionEntries.last { $0.kind == .user }
    }

    private var latestAssistantEntry: AgentSessionEntry {
        sessionEntries.last { $0.kind != .user } ?? sessionEntries[0]
    }

    private var agentIsThinking: Bool {
        organizer.isThinking || isParsingIntent || isResearchingInspiration || isAgentBuilding
    }

    private func setThinkingGlow(_ active: Bool) {
        if active {
            thinkingGlowExpanded = false
            thinkingBorderRotation = 0

            guard !reduceMotion else {
                thinkingGlowExpanded = true
                return
            }

            withAnimation(.easeInOut(duration: 1.65).repeatForever(autoreverses: true)) {
                thinkingGlowExpanded = true
            }
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                thinkingBorderRotation = 360
            }
        } else {
            withAnimation(.easeOut(duration: 0.28)) {
                thinkingGlowExpanded = false
                thinkingBorderRotation = 0
            }
        }
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
                if organizer.isThinking || organizer.plan != nil || organizer.errorText != nil {
                    organizePanel
                } else if isResearchingInspiration || inspirationProposal != nil {
                    inspirationPanel
                } else if !batchDrafts.isEmpty {
                    batchCreatePanel
                }
                contextChipRow

                VStack(alignment: .leading, spacing: 10) {
                    if !attachedCanvasImageIDs.isEmpty {
                        commandImageAttachmentRow
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .topLeading)))
                    }

                    TextField(commandPlaceholder, text: $commandText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textPrimary)
                        .lineLimit(1...6)
                        .frame(minHeight: 24, alignment: .topLeading)
                        .focused($commandFocused)
                        .onSubmit { runCommand() }

                    HStack(spacing: 8) {
                        commandAttachmentMenu

                        if let skill = selectedFixedSkill {
                            activeSkillChip(skill)
                        }

                        if let fileName = importedCommandFileName {
                            importedFileChip(fileName)
                        }

                        Spacer(minLength: 12)

                        Button { runCommand() } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.9))
                                .frame(width: 38, height: 38)
                                .background(Color.white, in: Circle())
                                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(!commandCanSend || organizer.isThinking || isParsingIntent || isResearchingInspiration || isAgentBuilding)
                        .opacity(commandCanSend ? 1 : 0.46)
                    }
                }
                .padding(12)
                .frame(width: 620, alignment: .leading)
                .atlasP1Glass(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    if agentIsThinking {
                        AngularGradient(
                            colors: [
                                .clear,
                                AtlasColor.auroraMint.opacity(0.18),
                                Color.white.opacity(0.95),
                                AtlasColor.auroraBlue.opacity(0.56),
                                AtlasColor.auroraViolet.opacity(0.42),
                                .clear,
                                .clear
                            ],
                            center: .center
                        )
                        .rotationEffect(.degrees(thinkingBorderRotation))
                        .mask(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(lineWidth: 2.2)
                        )
                        .allowsHitTesting(false)
                    }
                }
                .shadow(
                    color: AtlasColor.auroraMint.opacity(
                        agentIsThinking ? (thinkingGlowExpanded ? 0.22 : 0.06) : 0
                    ),
                    radius: thinkingGlowExpanded ? 25 : 8
                )
                .scaleEffect(
                    agentIsThinking && !reduceMotion
                        ? (thinkingGlowExpanded ? 1.008 : 0.998)
                        : 1
                )
                .animation(.spring(response: 0.36, dampingFraction: 0.9), value: commandLineEstimate)
            }
            .padding(.bottom, AtlasSpacing.l)
        }
    }

    private var commandLineEstimate: Int {
        let explicitLines = commandText.reduce(1) { count, character in
            character == "\n" ? count + 1 : count
        }
        let wrappedLines = max(1, Int(ceil(Double(commandText.count) / 48)))
        return min(6, max(explicitLines, wrappedLines))
    }

    private var commandCanSend: Bool {
        !commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !attachedCanvasImageIDs.isEmpty
    }

    private var commandAttachmentMenu: some View {
        Menu {
            Button {
                if canvasImageAttachments.isEmpty {
                    model.showToast("当前画布里还没有可引用的图片")
                } else {
                    showCanvasImagePicker = true
                }
            } label: {
                Label("导入画布图片", systemImage: "photo.on.rectangle.angled")
            }

            Menu {
                ForEach(FixedCanvasSkill.allCases) { skill in
                    Button {
                        activateFixedSkill(skill)
                    } label: {
                        Label(skill.title, systemImage: skill.symbol)
                    }
                }
            } label: {
                Label("使用固定 Skill", systemImage: "hexagon")
            }

            Divider()

            Button {
                showCommandFileImporter = true
            } label: {
                Label("导入文件（Markdown / TXT）", systemImage: "doc.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AtlasColor.textPrimary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.06), in: Circle())
                .overlay(Circle().stroke(AtlasColor.borderSubtle))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("添加上下文")
        .popover(isPresented: $showCanvasImagePicker, arrowEdge: .bottom) {
            canvasImagePicker
        }
    }

    private var canvasImageAttachments: [CanvasImageAttachment] {
        store.objects.compactMap { object in
            let values = Array(object.fields.values) + [object.summary]
            guard let source = values.compactMap(extractImageReference).first else { return nil }
            return CanvasImageAttachment(
                objectID: object.id,
                title: store.displayName(object),
                source: source,
                kind: object.kind
            )
        }
    }

    private var selectedCanvasImageAttachments: [CanvasImageAttachment] {
        attachedCanvasImageIDs.compactMap { id in
            canvasImageAttachments.first { $0.objectID == id }
        }
    }

    private var commandImageAttachmentRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(selectedCanvasImageAttachments) { attachment in
                    HStack(spacing: 8) {
                        CanvasImageThumbnail(source: attachment.source)
                            .frame(width: 54, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(attachment.title)
                                .font(AtlasFont.caption)
                                .foregroundStyle(AtlasColor.textPrimary)
                                .lineLimit(1)
                            Text("画布 · \(attachment.kind.title)")
                                .font(AtlasFont.monoSmall)
                                .foregroundStyle(AtlasColor.textTertiary)
                        }

                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                attachedCanvasImageIDs.removeAll { $0 == attachment.objectID }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color(white: 0.34))
                                .frame(width: 20, height: 20)
                                .background(Color.white.opacity(0.92), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(6)
                    .frame(width: 188, alignment: .leading)
                    .background(Color.white.opacity(0.055),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AtlasColor.borderSubtle))
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canvasImagePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("选择画布图片")
                        .font(AtlasFont.label)
                    Text("图片会作为固定格式附件加入对话")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer()
                Button {
                    showCanvasImagePicker = false
                } label: {
                    Text("完成").font(AtlasFont.caption)
                }
                .buttonStyle(.atlas(.primary))
            }

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.fixed(150), spacing: 8),
                    GridItem(.fixed(150), spacing: 8)
                ], spacing: 8) {
                    ForEach(canvasImageAttachments) { attachment in
                        let selected = attachedCanvasImageIDs.contains(attachment.objectID)
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                if selected {
                                    attachedCanvasImageIDs.removeAll { $0 == attachment.objectID }
                                } else {
                                    attachedCanvasImageIDs.append(attachment.objectID)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                CanvasImageThumbnail(source: attachment.source)
                                    .frame(width: 138, height: 86)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.72))
                                            .padding(6)
                                    }
                                Text(attachment.title)
                                    .font(AtlasFont.caption)
                                    .foregroundStyle(AtlasColor.textPrimary)
                                    .lineLimit(1)
                            }
                            .padding(6)
                            .frame(width: 150, alignment: .leading)
                            .background(
                                selected ? Color.white.opacity(0.12) : Color.white.opacity(0.045),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selected ? Color.white.opacity(0.42) : AtlasColor.borderSubtle))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(14)
        .frame(width: 340)
        .background(AtlasColor.elevated)
    }

    private func extractImageReference(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("data:image/") { return trimmed }

        let pattern = #"(?:https?://|file://|/)[^\s\)]+\.(?:png|jpe?g|webp|gif|heic|tiff?|bmp)(?:\?[^\s\)]*)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              let matchRange = Range(match.range, in: trimmed) else { return nil }
        return String(trimmed[matchRange])
    }

    private func activeSkillChip(_ skill: FixedCanvasSkill) -> some View {
        HStack(spacing: 5) {
            Image(systemName: skill.symbol)
                .font(.system(size: 9, weight: .medium))
            Text(skill.title)
                .font(AtlasFont.monoSmall)
                .lineLimit(1)
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    selectedFixedSkill = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(AtlasColor.textSecondary)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Color.white.opacity(0.055), in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle))
    }

    private func importedFileChip(_ fileName: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "doc.text")
                .font(.system(size: 9, weight: .medium))
            Text(fileName)
                .font(AtlasFont.monoSmall)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 116)
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    importedCommandFileName = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(AtlasColor.textSecondary)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Color.white.opacity(0.055), in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle))
    }

    private var commandFileTypes: [UTType] {
        [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "txt") ?? .plainText
        ]
    }

    private func activateFixedSkill(_ skill: FixedCanvasSkill) {
        withAnimation(.snappy(duration: 0.22)) {
            selectedFixedSkill = skill
            commandMode = skill.mode
        }
        commandFocused = true
        appendSession(.system, title: "固定 Skill", body: "本次输入将使用「\(skill.title)」。")
        model.showToast("已启用固定 Skill：\(skill.title)")
    }

    private func handleCommandFileImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let fileExtension = url.pathExtension.lowercased()
            guard fileExtension == "md" || fileExtension == "txt" else {
                model.showToast("目前仅支持 Markdown 和 TXT 文件")
                return
            }

            let hasSecurityAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityAccess { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                model.showToast("文件不是 UTF-8 文本，暂时无法导入")
                return
            }

            withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
                commandText = text
                importedCommandFileName = url.lastPathComponent
            }
            commandFocused = true
            appendSession(.parse, title: "导入文件",
                          body: "已载入「\(url.lastPathComponent)」，发送前仍可编辑。")
            model.showToast("文件内容已放入输入框")
        } catch {
            model.showToast("导入失败：\(error.localizedDescription)")
        }
    }

    // 输入框上方只保留被选中对象的上下文操作；画布级意图全部由自然语言判断。
    @ViewBuilder
    private var contextChipRow: some View {
        if let object = store.selected {
            quickActionRow(object)
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
        .frame(width: 620, alignment: .leading)
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
                Button { Task { await adoptBatchDrafts() } } label: {
                    AtlasButtonLabel(title: "采纳新建", systemImage: "checkmark")
                }
                .buttonStyle(.atlas(.primary))
                .disabled(isAgentBuilding)
                Button { withAnimation(.easeOut(duration: 0.2)) { batchDrafts = [] } } label: {
                    AtlasButtonLabel(title: "撤销", systemImage: "xmark")
                }
                .buttonStyle(.atlas(.glass))
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
        .frame(width: 620, alignment: .leading)
        .padding(.horizontal, AtlasSpacing.m).padding(.vertical, AtlasSpacing.s)
        .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
    }

    // 整理方案预览面板（仅在思考/有方案/有错误时出现）
    @ViewBuilder
    private var organizePanel: some View {
        if organizer.isThinking {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("正在整理画布…").font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
            }
            .frame(width: 620, alignment: .leading)
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

                Text(plan.summaries.first ?? "方案已生成，可先在画布上查看整理结果。")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .lineLimit(2)

                Button {
                    withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                        organizeDetailsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: organizeDetailsExpanded ? "eye.slash" : "eye")
                        Text(organizeDetailsExpanded ? "收起详情并复位" : "查看预览与详情")
                            .font(AtlasFont.caption)
                        Spacer()
                        Image(systemName: organizeDetailsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(AtlasColor.textPrimary)
                    .padding(.horizontal, AtlasSpacing.s)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.055),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(AtlasColor.borderSubtle))
                }
                .buttonStyle(.plain)

                if organizeDetailsExpanded {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("具体调整").font(AtlasFont.monoSmall)
                                    .foregroundStyle(AtlasColor.textTertiary)
                                ForEach(Array(plan.summaries.enumerated()), id: \.offset) { _, summary in
                                    HStack(alignment: .top, spacing: 7) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 3))
                                            .padding(.top, 6)
                                        Text(summary)
                                            .font(AtlasFont.caption)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .foregroundStyle(AtlasColor.textSecondary)
                                }
                            }

                            Divider().overlay(AtlasColor.borderSubtle)

                            VStack(alignment: .leading, spacing: 5) {
                                Text("整理依据").font(AtlasFont.monoSmall)
                                    .foregroundStyle(AtlasColor.textTertiary)
                                MarkdownDetailText(plan.note.isEmpty
                                    ? "依据对象类型、现有关系和画布密度生成；只调整布局与关系，不改写卡片正文。"
                                    : plan.note)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.visible)
                    .frame(maxHeight: 172)
                    .padding(AtlasSpacing.s)
                    .background(Color.black.opacity(0.13),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }

                HStack(spacing: AtlasSpacing.s) {
                    Button { adoptOrganizePlan() } label: {
                        AtlasButtonLabel(title: "采纳整理", systemImage: "checkmark")
                    }
                    .buttonStyle(.atlas(.primary))
                    Button {
                        appendSession(.parse, title: "撤销整理", body: "已丢弃当前整理方案。")
                        organizeDetailsExpanded = false
                        organizer.discard()
                    } label: {
                        AtlasButtonLabel(title: "撤销", systemImage: "xmark")
                    }
                    .buttonStyle(.atlas(.glass))
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
            .frame(width: 620, alignment: .leading)
            .padding(.horizontal, AtlasSpacing.m).padding(.vertical, AtlasSpacing.s)
            .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: organizeDetailsExpanded)
        } else if let err = organizer.errorText {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 11))
                Text(err).font(AtlasFont.caption).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AtlasColor.textSecondary)
            .frame(width: 620, alignment: .leading)
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
                canEdit: canEdit,
                initialMapJSON: store.mapJSON,
                pendingPlacementsJSON: store.pendingMapPlacementsJSON(),
                onExit: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        showMapEditor = false
                    }
                },
                onSave: { _, mapJSON in
                    // 就地生成海岸线并留在编辑器里让用户看到结果；返回由用户点“返回”触发
                    store.synchronizeMap(mapJSON)
                    model.showToast("海岸线已生成 · 点左上返回画布")
                }
            )
            .ignoresSafeArea()
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(
                        with: .scale(scale: 0.965, anchor: .center)
                    ),
                    removal: .opacity.combined(
                        with: .scale(scale: 0.982, anchor: .center)
                    )
                )
            )
            .zIndex(10)
        }
    }

    // MARK: - 交互

    // Stitch 式：一句话即落画布。不选中=新建对象（类型自动推断、随后可改）；
    // 选中=把这句话补进该对象的档案（真正的 AI 追问下一轮接入）。
    private func runCommand() {
        guard !isAgentBuilding else { return }
        let attachments = selectedCanvasImageAttachments
        let typedText = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typedText.isEmpty || !attachments.isEmpty else { return }
        let text = typedText.isEmpty ? "请结合这些画布图片继续。" : typedText
        let routesToOrganize = commandMode == .organize
            || (selectedFixedSkill == nil && shouldRouteToOrganize(text))
        let routesToResearch = !routesToOrganize && (
            commandMode == .research
            || (selectedFixedSkill == nil && shouldRouteToResearch(text))
        )
        let inferredMode: CommandMode = routesToOrganize ? .organize : (routesToResearch ? .research : .place)
        let sessionTitle: String
        switch inferredMode {
        case .organize: sessionTitle = "整理指令"
        case .research: sessionTitle = "灵感方向"
        case .place: sessionTitle = "画布指令"
        }
        let attachmentSummary = attachments
            .map { "画布图片 · \($0.title)" }
            .joined(separator: "\n")
        let sessionBody = attachmentSummary.isEmpty
            ? text
            : "\(text)\n\(attachmentSummary)"
        appendSession(.user, title: sessionTitle, body: sessionBody)
        importedCommandFileName = nil
        attachedCanvasImageIDs = []

        // 整理通道：交给 Agent 生成待采纳的整理方案（只动布局与关系，不改正文）。
        if routesToOrganize {
            organizeDetailsExpanded = false
            organizer.propose(instruction: text, store: store)
            appendSession(.parse, title: "正在生成整理方案", body: "模型会被限制为布局与关系工具，不会改写卡片正文。")
            commandText = ""
            commandMode = .place
            return
        }

        if routesToResearch {
            if commandMode != .research {
                appendSession(.parse, title: "识别为灵感研究", body: "已从放置指令切换到真实资料研究，不会把这段请求误建成画布卡片。")
            }
            researchInspiration(text)
            commandText = ""
            commandMode = .place
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
        commandMode = .place
    }

    private func shouldRouteToSelectedObject(_ text: String) -> Bool {
        guard store.selectedID != nil else { return false }
        let createWords = ["新建", "创建", "新增", "添加", "生成一个", "建一个", "批量"]
        return !createWords.contains { text.contains($0) }
    }

    private func shouldRouteToResearch(_ text: String) -> Bool {
        let researchWords = ["灵感", "真实存在", "可追溯", "原始资料", "资料来源", "附来源", "来源", "链接", "历史上的", "自然现象", "特殊习性", "习俗"]
        return researchWords.contains { text.contains($0) }
    }

    private func shouldRouteToOrganize(_ text: String) -> Bool {
        let organizeWords = [
            "整理", "归类", "排列", "排布", "布局", "对齐", "聚拢", "分组",
            "连接", "建立关系", "移除关系", "断开关系", "时间线", "按类型"
        ]
        return organizeWords.contains { text.contains($0) }
    }

    private func parseCanvasIntent(_ text: String) {
        AgentTelemetry.track("agent_canvas_parse_requested")
        guard AgentConfig.isConfigured else {
            appendSession(.parse, title: "AI 未连接", body: "建档需要连接模型。请先在设置中配置 DeepSeek API Key；不会使用本地规则替你拆分设定。")
            AgentTelemetry.track("agent_canvas_parse_blocked", properties: ["reason": "model_not_configured"])
            return
        }
        isParsingIntent = true
        appendSession(.parse, title: "正在理解画布指令", body: "使用建档助手技能：批量新建 / 命名解析 / 类型识别 / 摘要整理。")

        Task { @MainActor in
            do {
                let reply = try await DeepSeekClient().parseCanvasIntent(
                    instruction: text,
                    snapshot: CanvasOrganizer.snapshot(store)
                )
                let drafts = reply.drafts.map { BatchCreateDraft(kind: $0.kind, name: $0.name, summary: $0.summary) }
                isParsingIntent = false
                guard !drafts.isEmpty else {
                    appendSession(.parse, title: "没有识别到可新建对象", body: "模型没有返回可采纳的对象草稿。可以换一种说法，或补充对象名称与类型。")
                    return
                }

                if drafts.count > 1 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                        batchDrafts = drafts
                    }
                    AgentTelemetry.track("agent_canvas_drafts_proposed", properties: ["count": "\(drafts.count)"])
                    appendSession(.parse, title: "解析新建方案", body: batchSummary(drafts))
                } else if let draft = drafts.first {
                    await createDraftCard(draft)
                    AgentTelemetry.track("agent_canvas_draft_created", properties: ["kind": draft.kind.rawValue])
                    appendSession(.adopt, title: "新建草稿卡", body: "\(draft.kind.title) · \(draft.name)")
                }
            } catch {
                isParsingIntent = false
                appendSession(.parse, title: "模型解析失败", body: error.localizedDescription)
                AgentTelemetry.track("agent_canvas_parse_failed", properties: ["reason": "model_request_failed"])
            }
        }
    }

    private func createDraftCard(_ draft: BatchCreateDraft) async {
        placeCount += 1
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let angle = Double(placeCount) * 2.399
        let radius = 32.0 * Double(min(placeCount, 8))
        let screen = CGPoint(x: center.x + CGFloat(cos(angle) * radius),
                             y: center.y + CGFloat(sin(angle) * radius))
        let preferred = screenToWorld(screen)
        let world = store.nonOverlappingPosition(for: draft.kind.defaultSize, around: preferred)
        _ = await performAgentBuild(drafts: [draft], positions: [world])
    }

    private func adoptOrganizePlan() {
        guard let plan = organizer.plan else { return }
        appendSession(.adopt, title: "采纳整理方案", body: plan.summaries.prefix(4).joined(separator: "\n"))
        organizer.adopt(into: store)
        organizeDetailsExpanded = false
    }

    private func adoptBatchDrafts() async {
        let drafts = batchDrafts
        guard !drafts.isEmpty, !isAgentBuilding else { return }
        let cols = max(1, Int(ceil(sqrt(Double(drafts.count)))))
        let center = screenToWorld(CGPoint(x: viewSize.width / 2, y: viewSize.height / 2))
        let cellW: CGFloat = 280
        let cellH: CGFloat = 190
        let positions = drafts.indices.map { index in
            let row = index / cols
            let col = index % cols
            let preferred = CGPoint(
                x: center.x + CGFloat(col) * cellW - CGFloat(cols - 1) * cellW / 2,
                y: center.y + CGFloat(row) * cellH
            )
            let resolved = store.nonOverlappingPosition(for: drafts[index].kind.defaultSize, around: preferred)
            return resolved
        }
        withAnimation(.easeOut(duration: 0.2)) { batchDrafts = [] }
        _ = await performAgentBuild(drafts: drafts, positions: positions)
        appendSession(.adopt, title: "采纳批量新建", body: batchSummary(drafts))
        AgentTelemetry.track("agent_canvas_drafts_adopted", properties: ["count": "\(drafts.count)"])
    }

    @MainActor
    private func performAgentBuild(
        drafts: [BatchCreateDraft],
        positions: [CGPoint]
    ) async -> [String] {
        guard !drafts.isEmpty, drafts.count == positions.count, !isAgentBuilding else { return [] }
        isAgentBuilding = true
        store.clearSelection()
        appendSession(.parse, title: "智能体正在操作画布",
                      body: "将依次放置卡片、填写区域并检查连接，不会一次性写入。")

        var createdIDs: [String] = []
        for (draft, requestedPosition) in zip(drafts, positions) {
            let size = draft.kind.defaultSize
            let position = store.nonOverlappingPosition(for: size, around: requestedPosition)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                agentBuildCursor = AgentBuildCursor(
                    position: CGPoint(x: position.x - size.width * 0.44,
                                      y: position.y - size.height * 0.42),
                    label: "放置\(draft.kind.title)卡",
                    targetCenter: position,
                    targetSize: size,
                    progress: 0
                )
            }
            try? await Task.sleep(for: .seconds(0.34))

            var newID = ""
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                newID = store.add(draft.kind, at: position)
                store.clearSelection()
                if let index = store.objects.firstIndex(where: { $0.id == newID }) {
                    store.objects[index].aiAssisted = true
                }
                agentBuildCursor?.progress = 1
            }
            createdIDs.append(newID)
            try? await Task.sleep(for: .seconds(0.2))

            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    agentBuildCursor = AgentBuildCursor(
                        position: CGPoint(x: position.x - size.width * 0.32,
                                          y: position.y - size.height * 0.08),
                        label: "填写标题",
                        targetCenter: position,
                        targetSize: size,
                        progress: 0
                    )
            }
            await typeDraftText(draft.name, objectID: newID, keyPath: \.name, delay: .milliseconds(42))

            if !draft.summary.isEmpty {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    agentBuildCursor = AgentBuildCursor(
                        position: CGPoint(x: position.x - size.width * 0.3,
                                          y: position.y + size.height * 0.22),
                        label: "填写内容区域",
                        targetCenter: position,
                        targetSize: size,
                        progress: 0
                    )
                }
                await typeDraftText(draft.summary, objectID: newID, keyPath: \.summary, delay: .milliseconds(20))
            }
            try? await Task.sleep(for: .seconds(0.16))

        }

        withAnimation(.easeOut(duration: 0.24)) {
            agentBuildCursor = nil
            store.selectedIDs = Set(createdIDs)
        }
        isAgentBuilding = false
        return createdIDs
    }

    @MainActor
    private func typeDraftText(
        _ text: String,
        objectID: String,
        keyPath: WritableKeyPath<BuilderObject, String>,
        delay: Duration
    ) async {
        var typed = ""
        for (offset, character) in text.enumerated() {
            guard let index = store.objects.firstIndex(where: { $0.id == objectID }) else { return }
            typed.append(character)
            store.objects[index][keyPath: keyPath] = typed
            store.saved = false
            agentBuildCursor?.progress = Double(offset + 1) / Double(max(text.count, 1))
            try? await Task.sleep(for: delay)
        }
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
            .frame(width: 620, alignment: .leading)
            .padding(.horizontal, AtlasSpacing.m).padding(.vertical, AtlasSpacing.s)
            .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        } else if let proposal = inspirationProposal {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield").font(.system(size: 11))
                    Text("Agent 递来的\(proposal.domain.title)参照").font(AtlasFont.label)
                    Spacer()
                    Text("\(String(format: "%.1f", proposal.duration))s").font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                .foregroundStyle(AtlasColor.textSecondary)

                ForEach(proposal.cards) { card in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.title).font(AtlasFont.caption).foregroundStyle(AtlasColor.textPrimary).lineLimit(1)
                        Text("资料参照：\(card.fact)")
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textSecondary)
                            .lineLimit(3)
                        Text("可继续追问：\(card.creativeAngle)")
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                            .lineLimit(3)
                        Link("查看原始来源 · \(card.source.provider)", destination: card.source.url)
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.auroraMint)
                    }
                    .padding(.vertical, 3)
                }

                HStack(spacing: AtlasSpacing.s) {
                    Button { adoptInspirationProposal() } label: {
                        AtlasButtonLabel(title: "采纳为草稿便签", systemImage: "checkmark")
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
            .frame(width: 620, alignment: .leading)
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
                appendSession(.research, title: "检索词已规划", body: proposal.searchQueries.map { "\"\($0)\"" }.joined(separator: " · "))
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
                let preferred = CGPoint(x: center.x + CGFloat(index) * 230, y: center.y)
                let position = store.nonOverlappingPosition(for: BuilderKind.note.defaultSize, around: preferred)
                let id = store.add(.note, at: position)
                if let objectIndex = store.objects.firstIndex(where: { $0.id == id }) {
                    store.objects[objectIndex].name = card.title
                    store.objects[objectIndex].summary = """
                    Agent 资料参照 · 尚未成为正式设定

                    资料参照：\(card.fact)

                    可继续追问：\(card.creativeAngle)

                    原始来源：\(card.source.provider)
                    \(card.source.url.absoluteString)
                    """
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
        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
            showMapEditor = true
        }
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

private struct CanvasImageThumbnail: View {
    let source: String

    var body: some View {
        Group {
            if let image = localImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: source),
                      url.scheme == "http" || url.scheme == "https" {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallback
                    case .empty:
                        ZStack {
                            Color.white.opacity(0.055)
                            ProgressView().controlSize(.small)
                        }
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .background(Color.white.opacity(0.045))
    }

    private var localImage: NSImage? {
        if source.lowercased().hasPrefix("data:image/"),
           let comma = source.firstIndex(of: ","),
           let data = Data(base64Encoded: String(source[source.index(after: comma)...])) {
            return NSImage(data: data)
        }
        if let url = URL(string: source), url.isFileURL {
            return NSImage(contentsOf: url)
        }
        if source.hasPrefix("/") {
            return NSImage(contentsOfFile: source)
        }
        return nil
    }

    private var fallback: some View {
        ZStack {
            Color.white.opacity(0.055)
            Image(systemName: "photo")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(AtlasColor.textTertiary)
        }
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
            .atlasFloatingGlass(shape, interactive: true)
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.72), .white.opacity(0.18), .white.opacity(0.48)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
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
            MapCardBody(name: "世界地图", coastPaths: store.mapCoastPaths, onExpand: onExpand)
        } else {
            InfoCardBody(object: object, displayName: store.displayName(object), store: store)
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
    var coastPaths: [[CGPoint]]
    var onExpand: () -> Void

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                if coastPaths.isEmpty {
                    let border = Path(roundedRect: CGRect(x: size.width * 0.18, y: size.height * 0.30, width: size.width * 0.64, height: size.height * 0.40), cornerRadius: 32)
                    ctx.stroke(border, with: .color(.white.opacity(0.18)), style: .init(lineWidth: 1, dash: [5, 6]))
                } else {
                    let inset: CGFloat = 30
                    let sx = (size.width - inset * 2) / 1000
                    let sy = (size.height - inset * 2) / 650
                    let factor = min(sx, sy)
                    let ox = (size.width - 1000 * factor) / 2
                    let oy = (size.height - 650 * factor) / 2
                    for coast in coastPaths where coast.count > 1 {
                        var path = Path()
                        for (index, point) in coast.enumerated() {
                            let projected = CGPoint(x: ox + point.x * factor, y: oy + point.y * factor)
                            index == 0 ? path.move(to: projected) : path.addLine(to: projected)
                        }
                        ctx.stroke(path, with: .color(.white.opacity(0.78)), style: .init(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
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

}

// MARK: - 普通对象卡：随类型微调设计

private struct InfoCardBody: View {
    var object: BuilderObject
    var displayName: String
    @ObservedObject var store: WorldBuilderStore

    private enum Tier { case compact, regular, large }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            if object.kind == .note {
                noteLayout(width: w, height: h)
                    .padding(notePadding(width: w, height: h))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                let tier: Tier = (w < 176 || h < 116) ? .compact : (w < 300 ? .regular : .large)
                layout(tier)
                    .padding(pad(tier))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func notePadding(width: CGFloat, height: CGFloat) -> CGFloat {
        (width < 176 || height < 116) ? 11 : (width >= 300 ? AtlasSpacing.l : AtlasSpacing.m)
    }

    private func noteLayout(width: CGFloat, height: CGFloat) -> some View {
        let compact = width < 176 || height < 116
        let titleLines = max(1, min(3, Int((height - (compact ? 34 : 58)) / 24)))
        let bodyLines = max(1, Int((height - (compact ? 58 : 92) - CGFloat(titleLines * 23)) / 18))
        return VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            HStack(spacing: AtlasSpacing.s) {
                KindIcon(symbol: object.kind.symbol, size: compact ? 20 : (width >= 300 ? 26 : 24))
                if !compact {
                    Text(object.kind.title)
                        .font(AtlasFont.monoSmall)
                        .tracking(1)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer(minLength: 0)
                if object.aiAssisted {
                    Image(systemName: "sparkle")
                        .font(.system(size: 8))
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }

            Text(displayName)
                .font(width >= 300 ? .system(size: 19) : AtlasFont.body)
                .foregroundStyle(AtlasColor.textPrimary)
                .lineLimit(titleLines)
                .minimumScaleFactor(0.88)

            if !object.summary.isEmpty, bodyLines > 0 {
                Text(object.summary)
                    .font(width >= 300 ? AtlasFont.body : AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .lineLimit(bodyLines)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
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

                if tier == .large, !object.summary.isEmpty {
                    Text(object.summary)
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                TypeFieldPreview(object: object, store: store, expanded: tier == .large)

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

// MARK: - 类型专属画布摘要

/// 不把详情表单缩小后硬塞进卡片，而是为每种类型挑出最有辨识度的结构。
/// 常规尺寸显示一个核心构成，大尺寸再释放第二层信息。
private struct TypeFieldPreview: View {
    var object: BuilderObject
    @ObservedObject var store: WorldBuilderStore
    var expanded: Bool

    private func value(_ key: String) -> String {
        object.fields[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstLine(_ key: String) -> String {
        value(key).split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
    }

    private func linkedName(_ field: String) -> String? {
        guard let relation = store.links(for: object.id, field: field).first,
              let target = store.object(withID: relation.targetID) else { return nil }
        return store.displayName(target)
    }

    var body: some View {
        switch object.kind {
        case .location: locationPreview
        case .character: characterPreview
        case .org: organizationPreview
        case .event: eventPreview
        case .rule: rulePreview
        case .item: itemPreview
        case .work: workPreview
        case .note: notePreview
        case .map: EmptyView()
        }
    }

    private var locationPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            previewRow(symbol: "mappin", label: value("位置").isEmpty ? "位置待定" : value("位置"))
            if expanded {
                previewRow(symbol: "waveform", label: value("感官速写").isEmpty ? "补一句所见、所闻或气味" : value("感官速写"))
            }
        }
    }

    private var characterPreview: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let faction = linkedName("阵营归属") {
                previewRow(symbol: "building.2", label: faction)
            }
            StancePreview(rawValue: value("立场"))
            if expanded {
                let quote = value("代表台词")
                Text(quote.isEmpty ? "“写下一句只有这个人会说的话”" : "“\(quote)”")
                    .font(AtlasFont.caption)
                    .italic()
                    .foregroundStyle(quote.isEmpty ? AtlasColor.textTertiary : AtlasColor.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private var organizationPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            HierarchyPreview(levels: value("阶层结构"))
            if expanded {
                previewRow(symbol: "quote.bubble", label: value("理念").isEmpty ? "这个组织相信什么？" : value("理念"))
            }
        }
    }

    private var eventPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            previewRow(symbol: "switch.2", label: value("触发条件").isEmpty ? "尚未设定触发条件" : value("触发条件"))
            if expanded {
                HStack(spacing: 6) {
                    BranchChip(title: "A", text: value("立场选择 A"))
                    BranchChip(title: "B", text: value("立场选择 B"))
                }
            }
        }
    }

    private var rulePreview: some View {
        HStack(alignment: .top, spacing: 7) {
            BoundaryCell(symbol: "checkmark", label: "允许", value: firstLine("能做什么"))
            BoundaryCell(symbol: "xmark", label: "禁区", value: firstLine("不能做什么"))
        }
    }

    private var itemPreview: some View {
        VStack(alignment: .leading, spacing: 7) {
            let tags = value("属性").split(whereSeparator: { $0 == "，" || $0 == "," || $0.isNewline }).map(String.init)
            if tags.isEmpty {
                previewRow(symbol: "tag", label: "添加材质、状态或用途")
            } else {
                HStack(spacing: 5) {
                    ForEach(Array(tags.prefix(expanded ? 4 : 2)), id: \.self) { tag in
                        Text(tag.trimmingCharacters(in: .whitespaces))
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textSecondary)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }
            if expanded, let owner = linkedName("归属") {
                previewRow(symbol: "person.crop.circle", label: owner)
            }
        }
    }

    private var workPreview: some View {
        HStack(spacing: 9) {
            Image(systemName: value("创作内容").isEmpty ? "plus.rectangle.on.rectangle" : "doc.richtext")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AtlasColor.textSecondary)
                .frame(width: 32, height: 28)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value("创作内容").isEmpty ? "等待嵌入创作" : value("创作内容"))
                    .font(AtlasFont.caption)
                    .foregroundStyle(value("创作内容").isEmpty ? AtlasColor.textTertiary : AtlasColor.textSecondary)
                    .lineLimit(1)
                if expanded, !value("作者").isEmpty {
                    Text("作者 · \(value("作者"))")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }
        }
    }

    private var notePreview: some View {
        Text(object.summary.isEmpty ? "随手记下一段尚未归类的想法" : object.summary)
            .font(AtlasFont.caption)
            .foregroundStyle(object.summary.isEmpty ? AtlasColor.textTertiary : AtlasColor.textSecondary)
            .lineLimit(expanded ? 5 : 2)
    }

    private func previewRow(symbol: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(AtlasColor.textTertiary)
                .frame(width: 12)
            Text(label)
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textSecondary)
                .lineLimit(expanded ? 2 : 1)
        }
    }
}

/// Renders model explanations as Markdown while removing pictographs that do
/// not belong in Atlas's editorial UI. The plain-text fallback also strips
/// Markdown markers so raw syntax never leaks into the detail panel.
private struct MarkdownDetailText: View {
    private let content: AttributedString

    init(_ source: String) {
        let cleaned = source.filter { character in
            !character.unicodeScalars.contains {
                $0.properties.isEmojiPresentation || $0.value == 0xFE0F
            }
        }
        content = (try? AttributedString(
            markdown: cleaned,
            options: .init(interpretedSyntax: .full)
        )) ?? AttributedString(
            cleaned
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
        )
    }

    var body: some View {
        Text(content)
            .font(AtlasFont.caption)
            .foregroundStyle(AtlasColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct StancePreview: View {
    var rawValue: String
    private var position: CGFloat {
        min(max(CGFloat(Double(rawValue) ?? 0.5), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("忠于阵营")
                Spacer()
                Text("背叛")
            }
            .font(AtlasFont.monoSmall)
            .foregroundStyle(AtlasColor.textTertiary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10)).frame(height: 2)
                    Circle()
                        .fill(AtlasColor.textPrimary)
                        .frame(width: 6, height: 6)
                        .offset(x: max(0, proxy.size.width * position - 3))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 6)
        }
    }
}

private struct HierarchyPreview: View {
    var levels: String
    private var names: [String] {
        let parsed = levels.split(whereSeparator: { $0.isNewline || $0 == ">" || $0 == "／" }).map(String.init)
        return parsed.isEmpty ? ["领袖", "中层", "成员"] : Array(parsed.prefix(3))
    }

    var body: some View {
        VStack(spacing: 3) {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 6) {
                    Capsule()
                        .fill(Color.white.opacity(0.12 - Double(index) * 0.02))
                        .frame(width: CGFloat(18 + index * 15), height: 4)
                    Text(name.trimmingCharacters(in: .whitespaces))
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct BranchChip: View {
    var title: String
    var text: String
    var body: some View {
        HStack(spacing: 4) {
            Text(title).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textPrimary)
            Text(text.isEmpty ? "待定" : text)
                .font(AtlasFont.caption)
                .foregroundStyle(text.isEmpty ? AtlasColor.textTertiary : AtlasColor.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct BoundaryCell: View {
    var symbol: String
    var label: String
    var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 8, weight: .bold))
                Text(label).font(AtlasFont.monoSmall)
            }
            .foregroundStyle(AtlasColor.textTertiary)
            Text(value.isEmpty ? "尚未定义" : value)
                .font(AtlasFont.caption)
                .foregroundStyle(value.isEmpty ? AtlasColor.textTertiary : AtlasColor.textSecondary)
                .lineLimit(2)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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

                    if object.kind != .map && object.kind != .note {
                        TypeFieldsEditor(object: $object)
                        Divider().overlay(AtlasColor.borderSubtle)
                    }

                    VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                        Text(object.kind == .note ? "便签内容" : "补充档案")
                            .font(AtlasFont.caption)
                            .foregroundStyle(AtlasColor.textTertiary)
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

// MARK: - 详情卡里的类型专属字段

private struct TypeFieldsEditor: View {
    @Binding var object: BuilderObject

    private func binding(_ key: String) -> Binding<String> {
        Binding(
            get: { object.fields[key, default: ""] },
            set: { object.fields[key] = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            HStack {
                Text("\(object.kind.title)构成")
                    .font(AtlasFont.label)
                    .foregroundStyle(AtlasColor.textSecondary)
                Spacer()
                Text("画布可见")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }

            switch object.kind {
            case .location:
                CanvasFieldInput(label: "位置", prompt: "无位置 / 相对描述 / 地图坐标",
                                 text: binding("位置"), layer: .public)
                CanvasFieldInput(label: "感官速写", prompt: "一眼看到、听到或闻到什么",
                                 text: binding("感官速写"), layer: .public)
                CanvasFieldInput(label: "在这里会发生什么", prompt: "遭遇、谜题或一次相遇",
                                 text: binding("在这里会发生什么"), layer: .public, multiline: true)
                CanvasFieldInput(label: "隐藏入口", prompt: "探索后才会发现的通路或秘密",
                                 text: binding("隐藏入口"), layer: .reveal, multiline: true)

            case .character:
                StanceField(value: binding("立场"))
                CanvasFieldInput(label: "代表台词", prompt: "一句话立住这个人",
                                 text: binding("代表台词"), layer: .public, multiline: true)
                CanvasFieldInput(label: "真实身份", prompt: "故事深入后才揭晓的身份",
                                 text: binding("真实身份"), layer: .truth, multiline: true)

            case .org:
                CanvasFieldInput(label: "阶层结构", prompt: "领袖 > 中层 > 成员（可换行）",
                                 text: binding("阶层结构"), layer: .public, multiline: true)
                CanvasFieldInput(label: "理念", prompt: "这个势力相信什么",
                                 text: binding("理念"), layer: .public, multiline: true)
                CanvasFieldInput(label: "内幕", prompt: "不为外界所知的一面",
                                 text: binding("内幕"), layer: .reveal, multiline: true)

            case .event:
                CanvasFieldInput(label: "触发条件", prompt: "满足什么条件时发生",
                                 text: binding("触发条件"), layer: .public, multiline: true)
                HStack(alignment: .top, spacing: AtlasSpacing.s) {
                    CanvasFieldInput(label: "选择 A", prompt: "一种立场",
                                     text: binding("立场选择 A"), layer: .public, multiline: true)
                    CanvasFieldInput(label: "选择 B", prompt: "另一种立场",
                                     text: binding("立场选择 B"), layer: .reveal, multiline: true)
                }
                CanvasFieldInput(label: "结局分叉", prompt: "不同选择分别导向哪里",
                                 text: binding("结局分叉"), layer: .truth, multiline: true)

            case .rule:
                HStack(alignment: .top, spacing: AtlasSpacing.s) {
                    CanvasFieldInput(label: "能做什么", prompt: "能力范围",
                                     text: binding("能做什么"), layer: .public, multiline: true)
                    CanvasFieldInput(label: "不能做什么", prompt: "明确禁区",
                                     text: binding("不能做什么"), layer: .public, multiline: true)
                }
                CanvasFieldInput(label: "代价", prompt: "使用这套力量要付出什么",
                                 text: binding("代价"), layer: .public, multiline: true)
                CanvasFieldInput(label: "检定机制", prompt: "骰子、属性或判定逻辑",
                                 text: binding("检定机制"), layer: .reveal, multiline: true)

            case .item:
                CanvasFieldInput(label: "属性", prompt: "用逗号分隔：材质，状态，用途",
                                 text: binding("属性"), layer: .public)
                CanvasFieldInput(label: "谜题碎片", prompt: "物件里藏着的线索",
                                 text: binding("谜题碎片"), layer: .truth, multiline: true)

            case .work:
                CanvasFieldInput(label: "创作内容", prompt: "作品、文件、音频或链接",
                                 text: binding("创作内容"), layer: .public, multiline: true)
                CanvasFieldInput(label: "作者", prompt: "创作者或角色名",
                                 text: binding("作者"), layer: .public)

            case .map, .note:
                EmptyView()
            }
        }
    }
}

private enum FieldLayer {
    case `public`, reveal, truth

    var label: String {
        switch self {
        case .public: return "公开"
        case .reveal: return "揭示"
        case .truth: return "真相"
        }
    }

    var symbol: String {
        switch self {
        case .public: return "globe"
        case .reveal: return "lock.open"
        case .truth: return "lock"
        }
    }
}

private struct CanvasFieldInput: View {
    var label: String
    var prompt: String
    @Binding var text: String
    var layer: FieldLayer
    var multiline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(label)
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
                Spacer(minLength: 3)
                Image(systemName: layer.symbol)
                    .font(.system(size: 8.5, weight: .medium))
                Text(layer.label)
                    .font(AtlasFont.monoSmall)
            }
            .foregroundStyle(AtlasColor.textTertiary)

            if multiline {
                TextField(prompt, text: $text, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .padding(9)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AtlasColor.borderSubtle))
            } else {
                TextField(prompt, text: $text)
                    .textFieldStyle(.plain)
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .padding(9)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AtlasColor.borderSubtle))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StanceField: View {
    @Binding var value: String

    private var numericBinding: Binding<Double> {
        Binding(
            get: { min(max(Double(value) ?? 0.5, 0), 1) },
            set: { value = String(format: "%.2f", $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("立场").font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
                Spacer()
                Image(systemName: "globe").font(.system(size: 8.5, weight: .medium))
                Text("公开").font(AtlasFont.monoSmall)
            }
            .foregroundStyle(AtlasColor.textTertiary)
            HStack(spacing: 8) {
                Text("忠于阵营")
                Slider(value: numericBinding, in: 0...1)
                    .controlSize(.small)
                Text("背叛")
            }
            .font(AtlasFont.monoSmall)
            .foregroundStyle(AtlasColor.textTertiary)
        }
    }
}
