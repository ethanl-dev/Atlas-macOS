import SwiftUI

struct WorldWikiView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var query = ""
    @State private var selectedType: WorldObjectType?
    @State private var showsOutline = true
    @State private var showsInspector = false

    private var filteredObjects: [WorldObject] {
        WorldObject.samples.filter { object in
            (selectedType == nil || object.type == selectedType) &&
            (query.isEmpty || object.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 900

            ZStack {
                HStack(spacing: 0) {
                    if showsOutline && !compact {
                        outline(compact: false)
                            .frame(width: 250)
                        Divider()
                            .overlay(AtlasColor.borderSubtle)
                    }

                    document(compact: compact)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                }

                if showsOutline && compact {
                    drawerScrim {
                        withAnimation(.snappy(duration: 0.22)) {
                            showsOutline = false
                        }
                    }

                    HStack(spacing: 0) {
                        outline(compact: true)
                            .frame(width: min(292, proxy.size.width - 48))
                            .shadow(color: .black.opacity(0.45), radius: 24, x: 10)
                        Spacer(minLength: 0)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                if showsInspector {
                    drawerScrim {
                        withAnimation(.snappy(duration: 0.22)) {
                            showsInspector = false
                        }
                    }

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        inspector
                            .frame(width: min(300, proxy.size.width - 48))
                            .shadow(color: .black.opacity(0.45), radius: 24, x: -10)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .clipped()
            .onAppear {
                if compact {
                    showsOutline = false
                }
            }
            .onChange(of: compact) { _, isCompact in
                if isCompact {
                    showsOutline = false
                }
            }
            .animation(.snappy(duration: 0.22), value: showsOutline)
            .animation(.snappy(duration: 0.22), value: showsInspector)
        }
        .background(AtlasCanvasBackground())
    }

    private func outline(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            HStack {
                Text("WORLD WIKI")
                    .font(AtlasFont.mono)
                    .foregroundStyle(AtlasColor.textTertiary)
                Spacer()
                if compact {
                    Button {
                        showsOutline = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .help("关闭目录")
                }
                if model.accessMode == .manage {
                    Button {
                        model.activeSheet = .objectEditor
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .help("新建世界对象")
                }
            }

            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AtlasColor.textTertiary)
                TextField("搜索 Wiki", text: $query)
                    .textFieldStyle(.plain)
                    .font(AtlasFont.body)
            }
            .padding(AtlasSpacing.s)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AtlasSpacing.xs) {
                    typeChip(nil, title: "全部")
                    ForEach(WorldObjectType.allCases) { type in
                        typeChip(type, title: type.rawValue)
                    }
                }
            }

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredObjects) { object in
                        Button {
                            model.selectedObjectID = object.id
                        } label: {
                            HStack(spacing: AtlasSpacing.s) {
                                Image(systemName: object.type.symbol)
                                    .font(.system(size: 11, weight: .medium))
                                    .frame(width: 19)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(object.name)
                                        .font(AtlasFont.label)
                                        .lineLimit(1)
                                    Text(object.id)
                                        .font(AtlasFont.monoSmall)
                                        .foregroundStyle(AtlasColor.textTertiary)
                                }
                                Spacer()
                                if object.status == .pending {
                                    Image(systemName: "hourglass")
                                        .font(.system(size: 9))
                                        .foregroundStyle(AtlasColor.textTertiary)
                                }
                            }
                            .foregroundStyle(AtlasColor.textPrimary)
                            .padding(.horizontal, AtlasSpacing.s)
                            .padding(.vertical, AtlasSpacing.s)
                            .background {
                                if model.selectedObjectID == object.id {
                                    RoundedRectangle(cornerRadius: AtlasRadius.control)
                                        .fill(Color.white.opacity(0.09))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(AtlasSpacing.l)
        .background(AtlasColor.canvas.opacity(0.66))
    }

    private func document(compact: Bool) -> some View {
        let object = model.selectedObject

        return ScrollView {
            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                HStack {
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            showsOutline.toggle()
                            if showsOutline && compact {
                                showsInspector = false
                            }
                        }
                    } label: {
                        Image(systemName: showsOutline ? "sidebar.left" : "sidebar.left")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.atlas(.glass))
                    .help(showsOutline ? "隐藏对象目录" : "显示对象目录")

                    Label(object.type.rawValue, systemImage: object.type.symbol)
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                    Text(object.id)
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                    Spacer()
                    if model.accessMode == .manage {
                        Button {
                            model.activeSheet = .objectEditor
                        } label: {
                            AtlasButtonLabel(title: "编辑", systemImage: "pencil")
                        }
                        .buttonStyle(.atlas(.glass))
                    } else {
                        Button {
                            model.showToast("修改建议已建立为草稿")
                        } label: {
                            AtlasButtonLabel(title: "提出修改", systemImage: "bubble.left")
                        }
                        .buttonStyle(.atlas(.glass))
                    }

                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            showsInspector.toggle()
                            if showsInspector && compact {
                                showsOutline = false
                            }
                        }
                    } label: {
                        Image(systemName: "sidebar.trailing")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.atlas(.glass))
                    .help(showsInspector ? "关闭对象属性" : "查看对象属性")
                }

                VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                    Text(object.name)
                        .font(AtlasFont.display)
                    Text(object.summary)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineSpacing(5)
                }

                WikiObjectVisual(object: object)
                    .frame(height: 230)

                Divider().overlay(AtlasColor.borderSubtle)

                VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                    Text("正式档案")
                        .font(AtlasFont.heading)
                    Text(documentCopy(for: object))
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                    Text("关联对象")
                        .font(AtlasFont.heading)
                    ForEach(WorldObject.samples.filter { $0.id != object.id }.prefix(3)) { linked in
                        Button {
                            model.selectedObjectID = linked.id
                        } label: {
                            HStack {
                                Image(systemName: linked.type.symbol)
                                    .frame(width: 20)
                                Text(linked.name)
                                    .font(AtlasFont.body)
                                Spacer()
                                Text(linked.type.rawValue)
                                    .font(AtlasFont.monoSmall)
                                    .foregroundStyle(AtlasColor.textTertiary)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9))
                            }
                            .padding(.vertical, AtlasSpacing.s)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottom) {
                            Divider().overlay(AtlasColor.borderSubtle)
                        }
                    }
                }
            }
            .padding(AtlasSpacing.xxl)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var inspector: some View {
        let object = model.selectedObject

        return VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            HStack {
                Text("对象属性")
                    .font(AtlasFont.heading)
                Spacer()
                Button {
                    showsInspector = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("关闭对象属性")
            }

            InspectorProperty(label: "状态", value: object.status.rawValue)
            InspectorProperty(label: "版本", value: "v\(object.version)")
            InspectorProperty(label: "关联", value: "\(object.linkCount)")
            InspectorProperty(label: "AI 辅助", value: object.aiAssisted ? "已标注" : "无")
            InspectorProperty(label: "公开范围", value: object.status == .published ? "公开" : "企划成员")

            Divider().overlay(AtlasColor.borderSubtle)

            Text("版本脉络")
                .font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textTertiary)

            versionRow("v\(object.version)", title: "当前版本", active: true)
            versionRow("v\(max(1, object.version - 1))", title: "补充对象关联")
            versionRow("v1", title: "创建档案")

            Spacer()

            Button {
                model.destination = .canvas
            } label: {
                AtlasButtonLabel(title: "在地图中定位", systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.atlas(.glass))
        }
        .padding(AtlasSpacing.l)
        .background(AtlasColor.canvas.opacity(0.96))
        .overlay(alignment: .leading) {
            Divider()
                .overlay(AtlasColor.borderDefault)
        }
    }

    private func drawerScrim(action: @escaping () -> Void) -> some View {
        Color.black.opacity(0.34)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .transition(.opacity)
    }

    private func typeChip(_ type: WorldObjectType?, title: String) -> some View {
        Button {
            selectedType = type
        } label: {
            Text(title)
                .font(AtlasFont.caption)
                .foregroundStyle(selectedType == type ? AtlasColor.inverse : AtlasColor.textSecondary)
                .padding(.horizontal, AtlasSpacing.s)
                .padding(.vertical, 5)
                .background {
                    if selectedType == type {
                        Capsule().fill(Color.white)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func versionRow(_ version: String, title: String, active: Bool = false) -> some View {
        HStack(alignment: .top, spacing: AtlasSpacing.s) {
            Circle()
                .fill(active ? Color.white : Color.white.opacity(0.25))
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(version)
                    .font(AtlasFont.monoSmall)
                Text(title)
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
        }
    }

    private func documentCopy(for object: WorldObject) -> String {
        switch object.type {
        case .world:
            return "雾潮纪元第四十二年，北方海域的旧航线再度开放。沿海居民发现，海雾中偶尔会出现无法被星图记录的岛屿，而从岛上寄出的信件，落款日期都在三十年以后。\n\n这个世界的正式事实由管理者确认，参与者的行动通过事件结算写入时间线。"
        case .location:
            return "这里的树木会保存经过者的声音，并在夜里沿银色溪流低声复述。进入森林深处需要守林人的许可，未登记的路线会在第二次经过时改变方向。"
        case .character:
            return "角色档案记录当前位置、当前目标、关系申请和参与事件。角色所有者保有最终解释权，涉及双方关系的修改必须共同确认。"
        case .event:
            return "世界事件会改变地点、角色、组织和规则的状态。结算前所有影响均处于候选状态，不能直接改写正式世界线。"
        case .rule:
            return "文本 Agent 仅可用于整理、检查、检索和草稿辅助。图片生成、图生图、改图、画风模仿与使用参与者作品训练均默认关闭。"
        default:
            return "该对象已进入世界档案，可被地图、事件、作品与角色经历引用。任何正式修改都会保留版本记录和变更来源。"
        }
    }
}

private struct WikiObjectVisual: View {
    var object: WorldObject

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous)
                .fill(Color.white.opacity(0.025))

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for index in 0..<9 {
                    let radius = CGFloat(24 + index * 14)
                    var path = Path()
                    for sample in 0...80 {
                        let angle = CGFloat(sample) / 80 * .pi * 2
                        let wobble = 1 + 0.05 * sin(angle * CGFloat(index % 4 + 2) + CGFloat(index))
                        let point = CGPoint(
                            x: center.x + cos(angle) * radius * 1.8 * wobble,
                            y: center.y + sin(angle) * radius * 0.72 * wobble
                        )
                        if sample == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                    context.stroke(path, with: .color(.white.opacity(0.035 + Double(index) * 0.008)), lineWidth: 0.7)
                }
            }

            VStack(spacing: AtlasSpacing.s) {
                Image(systemName: object.type.symbol)
                    .font(.system(size: 28, weight: .light))
                Text(object.id)
                    .font(AtlasFont.mono)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.card).stroke(AtlasColor.borderSubtle))
    }
}
