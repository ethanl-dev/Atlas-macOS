import SwiftUI

struct WorldCanvasView: View {
    @ObservedObject var model: AtlasAppModel
    @StateObject private var agent = AgentController()
    @State private var agentInput = ""
    @State private var tool: CanvasTool = .select
    @State private var showInspector = true
    @State private var showLayers = false
    @State private var showEvents = true
    @State private var showRelations = true
    @State private var zoom: CGFloat = 1
    @State private var nodePositions: [String: CGPoint] = [
        "WLD-001": .init(x: 0.50, y: 0.52),
        "LOC-014": .init(x: 0.29, y: 0.34),
        "CHR-027": .init(x: 0.66, y: 0.31),
        "ORG-005": .init(x: 0.73, y: 0.66),
        "EVT-009": .init(x: 0.39, y: 0.72),
        "RUL-003": .init(x: 0.82, y: 0.44)
    ]

    var body: some View {
        ZStack {
            AtlasCanvasBackground(animated: true)
            terrain
                .scaleEffect(zoom)

            relationLayer
                .scaleEffect(zoom)

            nodeLayer
                .scaleEffect(zoom)

            VStack {
                toolbar
                Spacer()
                if model.accessMode == .manage {
                    VStack(spacing: AtlasSpacing.s) {
                        pendingCards
                        agentDock
                    }
                }
            }
            .padding(AtlasSpacing.l)

            HStack {
                Spacer()
                VStack {
                    Spacer()
                    zoomControl
                }
                if showInspector {
                    inspector
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(AtlasSpacing.l)
        }
        .clipped()
    }

    private var terrain: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let regions = [
                    CGRect(x: size.width * 0.10, y: size.height * 0.12, width: size.width * 0.36, height: size.height * 0.42),
                    CGRect(x: size.width * 0.47, y: size.height * 0.16, width: size.width * 0.42, height: size.height * 0.34),
                    CGRect(x: size.width * 0.21, y: size.height * 0.51, width: size.width * 0.55, height: size.height * 0.38)
                ]

                for (index, rect) in regions.enumerated() {
                    let shape = organicPath(in: rect, phase: CGFloat(index) * 0.7)
                    context.fill(shape, with: .color(.white.opacity(index == 1 ? 0.045 : 0.032)))
                    context.stroke(shape, with: .color(.white.opacity(0.12)), lineWidth: 1)

                    for inset in stride(from: CGFloat(14), through: 52, by: 14) {
                        let contourRect = rect.insetBy(dx: inset, dy: inset * 0.64)
                        if contourRect.width > 20, contourRect.height > 20 {
                            context.stroke(
                                organicPath(in: contourRect, phase: CGFloat(index) * 0.7 + inset * 0.01),
                                with: .color(.white.opacity(0.035)),
                                lineWidth: 0.6
                            )
                        }
                    }
                }
            }
            .allowsHitTesting(false)

            VStack {
                HStack {
                    Text("雾海诸岛")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                        .tracking(2)
                    Spacer()
                }
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Rectangle()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 74, height: 1)
                        Text("120 KM")
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                    Spacer()
                }
            }
            .padding(AtlasSpacing.xl)
        }
    }

    private var relationLayer: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                guard showRelations else { return }
                let edges = [
                    ("WLD-001", "LOC-014"),
                    ("WLD-001", "CHR-027"),
                    ("WLD-001", "ORG-005"),
                    ("LOC-014", "EVT-009"),
                    ("CHR-027", "EVT-009"),
                    ("ORG-005", "RUL-003")
                ]

                for (source, target) in edges {
                    guard let a = nodePositions[source], let b = nodePositions[target] else { continue }
                    var path = Path()
                    path.move(to: CGPoint(x: a.x * size.width, y: a.y * size.height))
                    path.addCurve(
                        to: CGPoint(x: b.x * size.width, y: b.y * size.height),
                        control1: CGPoint(x: a.x * size.width, y: b.y * size.height),
                        control2: CGPoint(x: b.x * size.width, y: a.y * size.height)
                    )
                    context.stroke(
                        path,
                        with: .color(.white.opacity(0.16)),
                        style: .init(lineWidth: 1, dash: source == "WLD-001" ? [] : [4, 5])
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var nodeLayer: some View {
        GeometryReader { proxy in
            ForEach(WorldObject.samples) { object in
                if object.type != .event || showEvents {
                    MapObjectNode(
                        object: object,
                        selected: object.id == model.selectedObjectID,
                        accessMode: model.accessMode,
                        draggable: model.accessMode == .manage && tool == .select,
                        conflictCount: model.accessMode == .manage ? (agent.conflicts[object.id] ?? 0) : 0,
                        aiAssisted: agent.aiAssisted.contains(object.id),
                        action: {
                            withAnimation(.snappy(duration: 0.22)) {
                                model.selectedObjectID = object.id
                                showInspector = true
                            }
                        },
                        onDrag: { translation in
                            guard let current = nodePositions[object.id] else { return }
                            nodePositions[object.id] = CGPoint(
                                x: min(max(current.x + translation.width / proxy.size.width, 0.08), 0.92),
                                y: min(max(current.y + translation.height / proxy.size.height, 0.10), 0.90)
                            )
                        },
                        onConflict: {
                            withAnimation(.snappy(duration: 0.22)) {
                                model.selectedObjectID = object.id
                                showInspector = true
                            }
                            agent.revealConflict(object: object)
                        }
                    )
                    .position(
                        x: (nodePositions[object.id]?.x ?? 0.5) * proxy.size.width,
                        y: (nodePositions[object.id]?.y ?? 0.5) * proxy.size.height
                    )
                }
            }
        }
        .padding(.top, 26)
        .padding(.bottom, model.accessMode == .manage ? 72 : 0)
    }

    private var toolbar: some View {
        HStack(spacing: AtlasSpacing.s) {
            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: "map")
                VStack(alignment: .leading, spacing: 0) {
                    Text("World Canvas")
                        .font(AtlasFont.label)
                    Text(model.accessMode == .manage ? "管理世界结构" : "探索世界与事件")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }

            Divider()
                .frame(height: 26)
                .overlay(AtlasColor.borderSubtle)

            if model.accessMode == .manage {
                ForEach(CanvasTool.allCases) { item in
                    Button {
                        tool = item
                        if item == .location || item == .event {
                            model.activeSheet = .objectEditor
                        }
                    } label: {
                        Image(systemName: item.symbol)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(tool == item ? AtlasColor.inverse : AtlasColor.textSecondary)
                            .padding(6)
                            .background {
                                if tool == item {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(item.title)
                }
            } else {
                Button {
                    model.destination = .tasks
                } label: {
                    Label("附近任务", systemImage: "bolt.horizontal")
                        .font(AtlasFont.caption)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                showLayers.toggle()
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("图层")
            .popover(isPresented: $showLayers, arrowEdge: .bottom) {
                layerPopover
            }

            Button {
                withAnimation(.snappy) { showInspector.toggle() }
            } label: {
                Image(systemName: "sidebar.right")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("检查器")
        }
        .foregroundStyle(AtlasColor.textPrimary)
        .padding(.horizontal, AtlasSpacing.m)
        .padding(.vertical, AtlasSpacing.s)
        .atlasGlass(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AtlasColor.borderSubtle))
    }

    private var layerPopover: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            Text("地图图层")
                .font(AtlasFont.heading)
            Toggle("设定与关联", isOn: $showRelations)
            Toggle("活动与事件", isOn: $showEvents)
            Divider()
            Button("重置视图") {
                withAnimation(.snappy) { zoom = 1 }
            }
            .buttonStyle(.plain)
        }
        .font(AtlasFont.body)
        .padding(AtlasSpacing.l)
        .frame(width: 210)
    }

    private var inspector: some View {
        let object = model.selectedObject

        return VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            HStack {
                Label(object.type.rawValue, systemImage: object.type.symbol)
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
                Spacer()
                Button {
                    withAnimation(.snappy) { showInspector = false }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                Text(object.name)
                    .font(AtlasFont.title)
                Text(object.summary)
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(AtlasColor.borderSubtle)

            InspectorProperty(label: "状态", value: object.status.rawValue)
            InspectorProperty(label: "版本", value: "v\(object.version)")
            InspectorProperty(label: "关联对象", value: "\(object.linkCount)")
            InspectorProperty(label: "可见范围", value: object.status == .published ? "公开" : "企划成员")
            if agent.draftCount(object.id) > 0 {
                InspectorProperty(label: "AI 草稿字段", value: "+\(agent.draftCount(object.id))（待确认）")
            }

            Spacer()

            if model.accessMode == .manage {
                VStack(spacing: AtlasSpacing.s) {
                    Button {
                        model.activeSheet = .objectEditor
                    } label: {
                        AtlasButtonLabel(title: "编辑对象", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.atlas(.primary))

                    HStack {
                        Button {
                            model.showToast("已进入关联创建状态")
                        } label: {
                            Image(systemName: "link.badge.plus")
                        }
                        .buttonStyle(.atlas(.glass))
                        .help("添加关联")

                        Button {
                            model.destination = .wiki
                        } label: {
                            Image(systemName: "books.vertical")
                        }
                        .buttonStyle(.atlas(.glass))
                        .help("在 Wiki 中查看")

                        Button {
                            model.showToast("版本差异面板将在下一轮接入")
                        } label: {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        }
                        .buttonStyle(.atlas(.glass))
                        .help("版本记录")
                    }
                }
            } else {
                VStack(spacing: AtlasSpacing.s) {
                    Button {
                        model.destination = .tasks
                    } label: {
                        AtlasButtonLabel(title: "查看相关任务", systemImage: "bolt.horizontal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.atlas(.primary))

                    Button {
                        model.activeSheet = .submitWork
                    } label: {
                        AtlasButtonLabel(title: "围绕此处创作", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.atlas(.glass))
                }
            }
        }
        .padding(AtlasSpacing.l)
        .frame(width: 292, alignment: .leading)
        .frame(maxHeight: 530)
        .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous).stroke(AtlasColor.borderSubtle))
    }

    // 待确认卡托盘：浮在 Agent 坞上方，每张卡可采纳/改写/存备注/扫掉
    private var pendingCards: some View {
        Group {
            if !agent.cards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: AtlasSpacing.s) {
                        ForEach(agent.cards) { card in
                            AgentCardView(card: card, agent: agent)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                }
                .frame(maxWidth: 720)
            }
        }
    }

    // Agent 坞：上下文芯片 + 编号快捷动作（Stitch 式）+ 提问。Agent 只递卡，不改正式设定。
    private var agentDock: some View {
        let object = model.selectedObject
        return VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            HStack(spacing: AtlasSpacing.xs) {
                Image(systemName: "sparkles").foregroundStyle(AtlasColor.textSecondary)
                HStack(spacing: 4) {
                    Image(systemName: object.type.symbol).font(.system(size: 9))
                    Text(object.name).font(AtlasFont.caption)
                }
                .foregroundStyle(AtlasColor.textSecondary)
                .padding(.horizontal, AtlasSpacing.s).padding(.vertical, 3)
                .background(Color.white.opacity(0.06), in: Capsule())

                Divider().frame(height: 20).overlay(AtlasColor.borderSubtle)

                ForEach(Array(agent.quickActions(for: object).enumerated()), id: \.element.id) { index, action in
                    Button { agent.run(action, object: object) } label: {
                        HStack(spacing: 4) {
                            Text(action.title).font(AtlasFont.label)
                            Text("\(index + 1)").font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                        }
                    }
                    .buttonStyle(.atlas(.glass))
                }
                Spacer()
            }

            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: "text.cursor").font(.system(size: 11)).foregroundStyle(AtlasColor.textTertiary)
                TextField("对选中对象提问…（Agent 只会回你一张卡）", text: $agentInput)
                    .textFieldStyle(.plain).font(AtlasFont.body)
                    .onSubmit { runAsk(object) }
                Button { runAsk(object) } label: {
                    Image(systemName: "arrow.up").frame(width: 18, height: 18)
                }
                .buttonStyle(.atlas(.primary))
            }
            .padding(.horizontal, AtlasSpacing.s).padding(.vertical, AtlasSpacing.xs)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous))
        }
        .padding(AtlasSpacing.m)
        .frame(maxWidth: 720)
        .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous).stroke(AtlasColor.borderSubtle))
    }

    private func runAsk(_ object: WorldObject) {
        agent.ask(agentInput, object: object)
        agentInput = ""
    }

    private var zoomControl: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { zoom = min(1.45, zoom + 0.12) }
            } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            Button {
                withAnimation(.snappy) { zoom = max(0.72, zoom - 0.12) }
            } label: {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
            }
            Button {
                withAnimation(.snappy) { zoom = 1 }
            } label: {
                Image(systemName: "scope")
                    .frame(width: 28, height: 28)
            }
        }
        .buttonStyle(.plain)
        .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous))
        .padding(.bottom, model.accessMode == .manage ? 60 : 0)
    }

    private func organicPath(in rect: CGRect, phase: CGFloat) -> Path {
        var path = Path()
        let samples = 42
        for index in 0...samples {
            let angle = CGFloat(index) / CGFloat(samples) * .pi * 2
            let variation = 1 + 0.07 * sin(angle * 3 + phase) + 0.04 * cos(angle * 5 - phase)
            let point = CGPoint(
                x: rect.midX + cos(angle) * rect.width * 0.5 * variation,
                y: rect.midY + sin(angle) * rect.height * 0.5 * variation
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private enum CanvasTool: String, CaseIterable, Identifiable {
    case select
    case location
    case relation
    case event

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: return "选择与移动"
        case .location: return "添加地点"
        case .relation: return "添加关联"
        case .event: return "添加事件"
        }
    }

    var symbol: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .location: return "mappin.and.ellipse"
        case .relation: return "point.3.connected.trianglepath.dotted"
        case .event: return "bolt.horizontal.circle"
        }
    }
}

private struct MapObjectNode: View {
    var object: WorldObject
    var selected: Bool
    var accessMode: ProjectAccessMode
    var draggable: Bool
    var conflictCount: Int = 0
    var aiAssisted: Bool = false
    var action: () -> Void
    var onDrag: (CGSize) -> Void
    var onConflict: () -> Void = {}
    @State private var dragOrigin: CGSize = .zero
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AtlasSpacing.s) {
                ZStack {
                    Circle()
                        .fill(selected ? Color.white : Color(white: object.status.emphasis))
                    Image(systemName: object.type.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AtlasColor.inverse)
                }
                .frame(width: selected ? 30 : 25, height: selected ? 30 : 25)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .overlay(alignment: .topLeading) {
                    if aiAssisted {
                        Image(systemName: "sparkle").font(.system(size: 7))
                            .foregroundStyle(AtlasColor.textTertiary)
                            .offset(x: -2, y: -2)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if conflictCount > 0 {
                        Text("\(conflictCount)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(AtlasColor.inverse)
                            .frame(width: 15, height: 15)
                            .background(Color.white, in: Circle())
                            .overlay(Circle().stroke(AtlasColor.canvas, lineWidth: 1.5))
                            .offset(x: 5, y: -5)
                            .onTapGesture { onConflict() }
                    }
                }

                if selected || hovering {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(object.name)
                            .font(AtlasFont.label)
                        Text(accessMode == .manage ? object.status.rawValue : object.type.rawValue)
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
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
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard draggable else { return }
                    let delta = CGSize(
                        width: value.translation.width - dragOrigin.width,
                        height: value.translation.height - dragOrigin.height
                    )
                    onDrag(delta)
                    dragOrigin = value.translation
                }
                .onEnded { _ in dragOrigin = .zero }
        )
    }
}

struct InspectorProperty: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textTertiary)
            Spacer()
            Text(value)
                .font(AtlasFont.caption)
        }
    }
}
