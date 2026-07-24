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

    init(model: AtlasAppModel, mode: String = "create", worldName: String = "未命名世界", onExit: @escaping () -> Void) {
        _model = ObservedObject(wrappedValue: model)
        self.onExit = onExit
        _store = StateObject(wrappedValue: WorldBuilderStore(worldName: worldName, seeded: mode == "manage"))
    }

    var body: some View {
        canvasStage
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .trailing) { detailPanel }
        .overlay(alignment: .bottom) { commandBar }
        .overlay { mapEditorOverlay }
        .background(Color(red: 0.035, green: 0.035, blue: 0.043))
    }

    // MARK: - 画布舞台

    private var canvasStage: some View {
        GeometryReader { proxy in
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
                }

                if store.projection == .timeline {
                    timelineAxis(in: proxy.size)
                }

                ForEach(store.objects) { object in
                    ObjectCard(
                        object: object,
                        scale: scale,
                        selected: store.selectedIDs.contains(object.id),
                        store: store,
                        onSelect: { select(object.id) },
                        onExpand: { openMapEditor(object.id) },
                        pan: pan
                    )
                    .position(worldToScreen(object.position))
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
                    emptyHint
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
                Text("在此新建卡片")
                ForEach(BuilderKind.creatable) { kind in
                    Button {
                        createCard(kind, atCanvas: lastHoverCanvas)
                    } label: {
                        Label(kind.title, systemImage: kind.symbol)
                    }
                }
            }
            .onAppear {
                viewSize = proxy.size
                if !didCenter {
                    pan = CGSize(width: proxy.size.width / 2 - 600 * scale,
                                 height: proxy.size.height / 2 - 400 * scale)
                    didCenter = true
                }
                startScrollMonitor()
            }
            .onDisappear { stopScrollMonitor() }
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

    private func relationLayer(in size: CGSize) -> some View {
        Canvas { context, _ in
            for relation in store.relations {
                guard let a = store.objects.first(where: { $0.id == relation.sourceID }),
                      let b = store.objects.first(where: { $0.id == relation.targetID }) else { continue }
                var path = Path()
                path.move(to: worldToScreen(a.position))
                path.addLine(to: worldToScreen(b.position))
                context.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }

    private func timelineAxis(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            var path = Path()
            let y = canvasSize.height * 0.5
            path.move(to: CGPoint(x: 80, y: y))
            path.addLine(to: CGPoint(x: canvasSize.width - 80, y: y))
            context.stroke(path, with: .color(.white.opacity(0.14)),
                           style: .init(lineWidth: 1, dash: [2, 6]))
        }
        .allowsHitTesting(false)
    }

    private var emptyHint: some View {
        VStack(spacing: AtlasSpacing.m) {
            Text("一块空白的世界")
                .font(AtlasFont.serifTitle)
                .foregroundStyle(AtlasColor.textSecondary)
            Text("右键画布任意处新建卡片，或在下面写一句话——雾港、守夜人、一场夜航……")
                .font(AtlasFont.body)
                .foregroundStyle(AtlasColor.textTertiary)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack(spacing: AtlasSpacing.m) {
            Button { onExit() } label: {
                Image(systemName: "chevron.left").frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AtlasColor.textPrimary)
            .atlasP1Glass(Circle(), interactive: true)

            VStack(alignment: .leading, spacing: 1) {
                TextField("未命名世界", text: $store.worldName)
                    .textFieldStyle(.plain)
                    .font(AtlasFont.serifHeading)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .frame(maxWidth: 220)
                Text(store.saved ? "所有更改已保存" : "正在编辑 · 尚未保存")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }

            Spacer()

            projectionSwitch

            Spacer()

            baseLayerMenu

            Button { model.showToast("公开预览将在下一轮接入") } label: {
                AtlasButtonLabel(title: "预览", systemImage: "eye")
            }
            .buttonStyle(.atlas(.glass))

            Button {
                store.saved = true
                model.showToast("世界已保存 · \(store.objects.count) 个对象")
            } label: {
                AtlasButtonLabel(title: "保存", systemImage: "checkmark")
            }
            .buttonStyle(.atlas(.primary))
        }
        .padding(.vertical, AtlasSpacing.m)
        .padding(.trailing, AtlasSpacing.m)
        // macOS 交通灯（红黄绿）在 .hiddenTitleBar 下仍浮于左上角，给顶栏左侧留出安全区。
        .padding(.leading, Self.trafficLightInset)
        .overlay(alignment: .bottom) { Divider().overlay(AtlasColor.borderSubtle) }
        .background(Color.black.opacity(0.14))
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
                        Text(mode.rawValue).font(AtlasFont.caption)
                    }
                    .foregroundStyle(store.projection == mode ? AtlasColor.inverse : AtlasColor.textSecondary)
                    .padding(.horizontal, AtlasSpacing.m)
                    .padding(.vertical, 6)
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
        if let id = store.selectedID, let bind = store.binding(for: id) {
            DetailCard(object: bind, store: store) {
                store.delete(id)
            }
            .frame(width: 300)
            .padding(.trailing, AtlasSpacing.l)
            .padding(.top, 68)
            .padding(.bottom, AtlasSpacing.l)
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    // MARK: - 命令条（Stitch 式：不选中=描述即落画布；选中=贴着对象追问）

    private var commandBar: some View {
        VStack(spacing: AtlasSpacing.s) {
            if let object = store.selected {
                // 选中态：上下文芯片 + 编号快捷建议（Agent 只递卡，采纳才作数）
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
            }

            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: store.selected == nil ? "plus.circle" : "text.cursor")
                    .font(.system(size: 13))
                    .foregroundStyle(AtlasColor.textTertiary)
                TextField(commandPlaceholder, text: $commandText)
                    .textFieldStyle(.plain)
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .focused($commandFocused)
                    .onSubmit { runCommand() }
                Button { runCommand() } label: {
                    Image(systemName: "arrow.up").frame(width: 20, height: 20)
                }
                .buttonStyle(.atlas(.primary))
                .disabled(commandText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, AtlasSpacing.m)
            .padding(.vertical, AtlasSpacing.s)
            .frame(width: 560)
            .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        }
        .padding(.bottom, AtlasSpacing.l)
    }

    private var commandPlaceholder: String {
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
                onSave: { _ in
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

        if let id = store.selectedID, let index = store.objects.firstIndex(where: { $0.id == id }) {
            store.objects[index].summary = store.objects[index].summary.isEmpty
                ? text : store.objects[index].summary + "\n" + text
            store.saved = false
        } else {
            let kind = inferKind(from: text)
            placeCount += 1
            let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
            let angle = Double(placeCount) * 2.399
            let radius = 24.0 * Double(min(placeCount, 6))
            let screen = CGPoint(x: center.x + CGFloat(cos(angle) * radius),
                                 y: center.y + CGFloat(sin(angle) * radius))
            let world = screenToWorld(screen)
            withAnimation(.snappy(duration: 0.25)) {
                let newID = store.add(kind, at: world)
                if let i = store.objects.firstIndex(where: { $0.id == newID }) {
                    store.objects[i].name = text
                }
            }
        }
        commandText = ""
    }

    // 轻量关键词推断：只是给一个初始类型，作者可在详情卡一键改。不是终局分类。
    private func inferKind(from text: String) -> BuilderKind {
        func has(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        if has(["组织", "阵营", "势力", "公会", "军团", "教会", "家族", "帮", "同盟", "议会"]) { return .org }
        if has(["事件", "祭", "战", "典礼", "仪式", "风暴", "叛乱", "会战", "节日"]) { return .event }
        if has(["规则", "禁令", "律法", "法则", "边界", "限制", "政策"]) { return .rule }
        if has(["角色", "守望", "者", "先生", "小姐", "师", "国王", "客", "队长", "匠"]) { return .character }
        if has(["物件", "长剑", "灯", "书", "钥匙", "印记", "符文", "器物"]) { return .item }
        if has(["作品", "画作", "手稿", "曲", "诗"]) { return .work }
        return .location
    }

    private func select(_ id: String?) {
        withAnimation(.snappy(duration: 0.22)) { store.selectedID = id }
    }

    // 右键在指针处新建卡片
    private func createCard(_ kind: BuilderKind, atCanvas point: CGPoint) {
        let world = screenToWorld(point == .zero
                                  ? CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                                  : point)
        withAnimation(.snappy(duration: 0.25)) {
            store.add(kind, at: world)
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
                scale = min(2.2, max(0.4, base * value.magnification))
            }
            .onEnded { _ in zoomAnchor = nil }
    }

    // 触摸板双指滑动 → 平移；⌘ + 滑动 → 缩放。macOS 原生滚轮事件。
    private func startScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            if showMapEditor { return event }          // 地图编辑器打开时交给它
            if event.modifierFlags.contains(.command) {
                let factor = 1 - event.scrollingDeltaY * 0.004
                scale = min(2.2, max(0.4, scale * factor))
            } else {
                pan.width += event.scrollingDeltaX
                pan.height += event.scrollingDeltaY
                panStart = pan
            }
            return nil
        }
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
    var onSelect: () -> Void
    var onExpand: () -> Void

    @State private var hoverLocal: CGPoint?
    @State private var moveStart: CGPoint?
    @State private var resizeStart: (center: CGPoint, size: CGSize)?
    @State private var activeCorner: Int?          // 当前贴近的角（0左上 1右上 2左下 3右下）

    var pan: CGSize

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
                    activeCorner = nearestResizeCorner(p)
                case .ended:
                    hoverLocal = nil
                    activeCorner = nil
                }
            }
            .gesture(unifiedDrag)
            .onTapGesture { onSelect() }
            .contextMenu {
                if object.kind == .map {
                    Button { onExpand() } label: { Label("展开编辑地图", systemImage: "arrow.up.left.and.arrow.down.right") }
                }
                Button { onSelect() } label: { Label("编辑详情", systemImage: "pencil") }
                Button { store.bringToFront(object.id) } label: { Label("置于顶层", systemImage: "square.3.layers.3d.top.filled") }
                Divider()
                Button(role: .destructive) { store.delete(object.id) } label: { Label("删除卡片", systemImage: "trash") }
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
                    .background(AtlasP1Glass.darkFill, in: Circle())
                    .overlay(Circle().stroke(AtlasColor.borderSubtle))
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
        .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
    }
}
