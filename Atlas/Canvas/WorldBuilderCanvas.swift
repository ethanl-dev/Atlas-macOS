import SwiftUI

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
                    NodeChip(
                        object: object,
                        selected: object.id == store.selectedID,
                        displayName: store.displayName(object)
                    )
                    .position(worldToScreen(object.position))
                    .gesture(nodeDrag(object))
                    .onTapGesture { select(object.id) }
                }

                if store.objects.isEmpty {
                    emptyHint
                }
            }
            .coordinateSpace(.named("canvas"))
            .contentShape(Rectangle())
            .gesture(panGesture)
            .simultaneousGesture(magnifyGesture)
            .onTapGesture { select(nil) }
            .onAppear {
                viewSize = proxy.size
                if !didCenter {
                    pan = CGSize(width: proxy.size.width / 2 - 600 * scale,
                                 height: proxy.size.height / 2 - 400 * scale)
                    didCenter = true
                }
            }
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
            Text("在下面写一句话——雾港、守夜人、一场夜航……回车，它就落在这里。")
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
        .padding(AtlasSpacing.m)
        .background(.clear)
        .overlay(alignment: .bottom) { Divider().overlay(AtlasColor.borderSubtle) }
        .background(Color.black.opacity(0.14))
    }

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
                        NodeGlyph(shape: object.kind.shape, symbol: object.kind.symbol, size: 16,
                                  official: object.status == .official)
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
                    store.showMapBase = true
                    store.projection = .map
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

    private func nodeDrag(_ object: BuilderObject) -> some Gesture {
        DragGesture(coordinateSpace: .named("canvas"))
            .onChanged { value in
                let world = screenToWorld(value.location)
                store.move(object.id, to: world)
                if store.selectedID != object.id { store.selectedID = object.id }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                pan = CGSize(width: panStart.width + value.translation.width,
                             height: panStart.height + value.translation.height)
            }
            .onEnded { _ in panStart = pan }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(1.6, max(0.55, value.magnification))
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

// MARK: - 画布上的对象节点

private struct NodeChip: View {
    var object: BuilderObject
    var selected: Bool
    var displayName: String
    @State private var hovering = false

    var body: some View {
        HStack(spacing: AtlasSpacing.s) {
            NodeGlyph(
                shape: object.kind.shape,
                symbol: object.kind.symbol,
                size: selected ? 30 : 26,
                official: object.status == .official,
                emphasized: selected
            )
            .overlay(alignment: .topLeading) {
                if object.aiAssisted {
                    Image(systemName: "sparkle").font(.system(size: 7))
                        .foregroundStyle(AtlasColor.textTertiary).offset(x: -2, y: -2)
                }
            }

            if selected || hovering {
                VStack(alignment: .leading, spacing: 0) {
                    Text(displayName).font(AtlasFont.label)
                    Text(object.status.rawValue).font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                .fixedSize()
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .foregroundStyle(AtlasColor.textPrimary)
        .padding(5)
        .background {
            if selected || hovering {
                Color.clear.atlasGlass(Capsule())
            }
        }
        .animation(.snappy(duration: 0.18), value: hovering)
        .onHover { hovering = $0 }
    }
}

// MARK: - 类型字形（形状 + 图标，黑白）

struct NodeGlyph: View {
    var shape: BuilderShape
    var symbol: String
    var size: CGFloat
    var official: Bool = false
    var emphasized: Bool = false

    var body: some View {
        ZStack {
            glyphShape
                .fill(emphasized ? Color.white : Color(white: official ? 0.82 : 0.30))
            glyphShape
                .stroke(official ? Color.white.opacity(0.9) : Color.white.opacity(0.4),
                        style: .init(lineWidth: official ? 1.2 : 1, dash: official ? [] : [3, 3]))
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(emphasized ? AtlasColor.inverse : (official ? AtlasColor.inverse : AtlasColor.textPrimary))
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
                        NodeGlyph(shape: object.kind.shape, symbol: object.kind.symbol, size: 22,
                                  official: object.status == .official)
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

            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text("状态").font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                Picker("", selection: $object.status) {
                    ForEach(BuilderStatus.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text("档案内容").font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                TextEditor(text: $object.summary)
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(height: 120)
                    .padding(AtlasSpacing.s)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
                    .overlay(alignment: .topLeading) {
                        if object.summary.isEmpty {
                            Text("在这里补充这个\(object.kind.title)的设定……")
                                .font(AtlasFont.body)
                                .foregroundStyle(AtlasColor.textTertiary)
                                .padding(AtlasSpacing.s)
                                .padding(.top, 2)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Spacer()

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
