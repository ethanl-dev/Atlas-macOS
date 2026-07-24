import SwiftUI

//
//  WorldCreationFlow —— 创作仪式（不是向导）。
//
//  设计意图：
//  首页星图把"每一个企划都是一个世界"讲成了一件有气质的事；
//  创建世界不该退回成一张后台表单。这里把它重构成一次「点亮一颗世界之星」
//  的仪式：作者命名它、注入意象、听世界回应、最后亲手点亮。
//
//  贯穿原则（呼应 Atlas 的立场——把创作权从 AI 手里夺回来）：
//  · 背景是与星图同源的深空星场，作者每前进一步，星就更亮一分。
//  · 世界名与意象用宋体（衬线），是"作品"的字，不是"界面"的字。
//  · AI 生成的一切都叫「回声」，只是草稿；接受 / 改写 / 让它沉默，都由作者决定。
//  · 没有 STEP 1/4 的进度感，没有"发布准备度"的仪表盘——那些是工具的语言。
//

struct WorldCreationFlow: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil

    private enum Act: Int, CaseIterable {
        case name, image, echo, ignite
        var overline: String {
            switch self {
            case .name:   return "序 · 命名"
            case .image:  return "序 · 意象"
            case .echo:   return "序 · 回应"
            case .ignite: return "世界已亮"
            }
        }
    }

    @State private var act: Act = .name
    @State private var glow: Double = 0.12

    @State private var worldName = ""
    @State private var hook = ""
    @State private var origin = CreationOrigin.image
    @State private var aiStance = AIStance.scribe
    @State private var echoStates: [String: EchoState] = [:]

    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            WorldCreationStarView(glow: glow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                titlebar
                Spacer(minLength: 0)
                stagePanel
                    .frame(maxWidth: 560)
                    .padding(.horizontal, AtlasSpacing.xxl)
                Spacer(minLength: 0)
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.035, green: 0.035, blue: 0.043))
        .onAppear { syncGlow(animated: false) }
    }

    // MARK: - 顶栏（去掉 STEP 进度，只留身份与关闭）

    private var titlebar: some View {
        HStack(spacing: AtlasSpacing.m) {
            AtlasMark()
            Text("创世")
                .font(AtlasFont.monoSmall)
                .tracking(3)
                .foregroundStyle(AtlasColor.textTertiary)
            Spacer()
            Button { close() } label: {
                Image(systemName: "xmark").frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AtlasColor.textPrimary)
            .atlasP1Glass(Circle(), interactive: true)
            .help("关闭")
        }
        .padding(AtlasSpacing.l)
    }

    // MARK: - 仪式面板

    @ViewBuilder
    private var stagePanel: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            Text(act.overline)
                .font(AtlasFont.monoSmall)
                .tracking(4)
                .foregroundStyle(AtlasColor.textTertiary)

            switch act {
            case .name:   nameAct
            case .image:  imageAct
            case .echo:   echoAct
            case .ignite: igniteAct
            }
        }
        .padding(AtlasSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .id(act)
    }

    // 幕一 · 命名
    private var nameAct: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            Text("先给它一个名字。")
                .font(AtlasFont.serifDisplay)
                .foregroundStyle(AtlasColor.textPrimary)
            Text("名字之后可以再改。但世界会记得，你第一次是怎么称呼它的。")
                .font(AtlasFont.body)
                .foregroundStyle(AtlasColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                TextField("未命名世界", text: $worldName)
                    .textFieldStyle(.plain)
                    .font(AtlasFont.serifTitle)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .focused($nameFocused)
                    .onSubmit(advance)
                Rectangle()
                    .fill(nameFocused ? AtlasColor.borderStrong : AtlasColor.borderSubtle)
                    .frame(height: 1)
                    .animation(.easeOut(duration: 0.2), value: nameFocused)
            }
            .padding(.top, AtlasSpacing.s)
        }
        .onAppear { nameFocused = true }
    }

    // 幕二 · 意象
    private var imageAct: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            Text("写下那句，只有你知道为什么心动的话。")
                .font(AtlasFont.serifTitle)
                .foregroundStyle(AtlasColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("这句话是世界的种子。Atlas 只让它发芽——长成什么，始终你说了算。")
                .font(AtlasFont.body)
                .foregroundStyle(AtlasColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: AtlasSpacing.m) {
                Rectangle()
                    .fill(AtlasColor.borderStrong)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                TextEditor(text: $hook)
                    .font(AtlasFont.serifBody)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(height: 96)
                    .overlay(alignment: .topLeading) {
                        if hook.isEmpty {
                            Text("潮汐带走声音，白塔保存远航记录……")
                                .font(AtlasFont.serifBody)
                                .foregroundStyle(AtlasColor.textTertiary)
                                .allowsHitTesting(false)
                                .padding(.top, 1)
                        }
                    }
            }
            .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(AtlasColor.borderSubtle)

            // 让它从哪里生长（次要，不喧宾夺主）
            labeledRow("让它从哪里生长") {
                FlowChips(
                    items: CreationOrigin.allCases.map { ($0.id, $0.title) },
                    selected: origin.id
                ) { id in
                    if let picked = CreationOrigin(rawValue: id) {
                        withAnimation(.snappy) { origin = picked }
                    }
                }
            }

            // AI 的位置——把"授权"说成一句立场，而不是一个开关
            labeledRow("AI 的位置") {
                FlowChips(
                    items: AIStance.allCases.map { ($0.id, $0.title) },
                    selected: aiStance.id
                ) { id in
                    if let picked = AIStance(rawValue: id) {
                        withAnimation(.snappy) { aiStance = picked }
                    }
                }
            }
        }
    }

    // 幕三 · 世界回应
    private var echoAct: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            Text("世界开始回应你。")
                .font(AtlasFont.serifTitle)
                .foregroundStyle(AtlasColor.textPrimary)
            Text("这些是 Atlas 从你的意象里听到的回声。它们只是草稿——接受、改写，或让它沉默，都由你决定。")
                .font(AtlasFont.body)
                .foregroundStyle(AtlasColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: AtlasSpacing.s) {
                ForEach(EchoSuggestion.samples) { suggestion in
                    EchoRow(
                        suggestion: suggestion,
                        state: echoStates[suggestion.id] ?? .pending
                    ) { newState in
                        withAnimation(.snappy) { echoStates[suggestion.id] = newState }
                    }
                }
            }

            Text(confirmedCount == 0
                 ? "还没有回声被确认——空着进入也可以，世界会等你。"
                 : "你已经确认了 \(confirmedCount) 个回声。")
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textTertiary)
                .padding(.top, AtlasSpacing.xxs)
        }
    }

    // 幕四 · 点亮
    private var igniteAct: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            Text("「\(displayName)」亮了。")
                .font(AtlasFont.serifDisplay)
                .foregroundStyle(AtlasColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("地图、Wiki、任务与公开页，从此共享同一片星空下的这一颗。你可以随时回来，继续让它长大。")
                .font(AtlasFont.body)
                .foregroundStyle(AtlasColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AtlasSpacing.s) {
                metaChip("候选地点 \(confirmedLocations)")
                metaChip("事件 1")
                metaChip("规则 1")
                if aiStance != .none {
                    metaChip(aiStance.title)
                }
            }
            .padding(.top, AtlasSpacing.xs)
        }
    }

    // MARK: - 底部：星座式进度 + 前进动作

    private var footer: some View {
        HStack {
            if act != .name {
                Button { retreat() } label: {
                    AtlasButtonLabel(title: "返回", systemImage: "chevron.left")
                        .padding(.horizontal, AtlasSpacing.m)
                        .frame(height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AtlasColor.textSecondary)
                .atlasP1Glass(Capsule(), interactive: true)
            }

            Spacer()
            constellation
            Spacer()

            Button { advance() } label: {
                AtlasButtonLabel(title: forwardTitle, systemImage: nil)
                    .foregroundStyle(AtlasColor.inverse)
                    .padding(.horizontal, AtlasSpacing.m)
            }
            .buttonStyle(.plain)
            .frame(height: 34)
            .background(Color.white.opacity(forwardDisabled ? 0.35 : 1),
                       in: Capsule())
            .disabled(forwardDisabled)
            .animation(.easeOut(duration: 0.15), value: forwardDisabled)
        }
        .padding(AtlasSpacing.l)
    }

    private var constellation: some View {
        HStack(spacing: AtlasSpacing.m) {
            ForEach(Act.allCases, id: \.rawValue) { a in
                Circle()
                    .fill(Color.white.opacity(a.rawValue <= act.rawValue ? 0.95 : 0.22))
                    .frame(width: a == act ? 7 : 5, height: a == act ? 7 : 5)
                    .shadow(color: .white.opacity(a == act ? 0.6 : 0), radius: 5)
                    .animation(.easeInOut(duration: 0.4), value: act)
            }
        }
    }

    // MARK: - 小组件

    private func labeledRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            Text(title)
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textTertiary)
            content()
        }
    }

    private func metaChip(_ text: String) -> some View {
        Text(text)
            .font(AtlasFont.monoSmall)
            .foregroundStyle(AtlasColor.textSecondary)
            .padding(.horizontal, AtlasSpacing.s)
            .padding(.vertical, 5)
            .background(AtlasP1Glass.darkFill, in: Capsule())
            .overlay(Capsule().stroke(AtlasColor.borderSubtle))
    }

    // MARK: - 逻辑

    private var displayName: String {
        worldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名世界" : worldName
    }

    private var confirmedCount: Int {
        echoStates.values.filter { $0 == .accepted || $0 == .rewritten }.count
    }

    private var confirmedLocations: Int {
        EchoSuggestion.samples.filter { $0.type == "地点" }
            .filter { s in
                let st = echoStates[s.id] ?? .pending
                return st == .accepted || st == .rewritten
            }.count
    }

    private var forwardTitle: String {
        switch act {
        case .name:   return "继续"
        case .image:  return "让世界回应"
        case .echo:   return "点亮世界"
        case .ignite: return "进入这个世界"
        }
    }

    private var forwardDisabled: Bool {
        act == .image && hook.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func advance() {
        if forwardDisabled { return }
        switch act {
        case .name:
            transition(to: .image)
        case .image:
            transition(to: .echo)
        case .echo:
            transition(to: .ignite)
        case .ignite:
            enterWorld()
        }
    }

    private func retreat() {
        guard let prev = Act(rawValue: act.rawValue - 1) else { return }
        transition(to: prev)
    }

    private func transition(to next: Act) {
        withAnimation(.easeInOut(duration: 0.5)) { act = next }
        withAnimation(.easeInOut(duration: 1.2)) { glow = glowValue(for: next) }
    }

    private func syncGlow(animated: Bool) {
        if animated {
            withAnimation(.easeInOut(duration: 1.2)) { glow = glowValue(for: act) }
        } else {
            glow = glowValue(for: act)
        }
    }

    private func glowValue(for act: Act) -> Double {
        switch act {
        case .name:   return 0.14
        case .image:  return 0.34
        case .echo:   return 0.60
        case .ignite: return 1.0
        }
    }

    private func enterWorld() {
        if let onComplete {
            onComplete()
        } else {
            model.creationCompleted = true
            model.accessMode = .manage
            model.destination = .canvas
            close()
        }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}

// MARK: - 起点

private enum CreationOrigin: String, CaseIterable, Identifiable {
    case image, map, characters, event, importFile, blank
    var id: String { rawValue }
    var title: String {
        switch self {
        case .image:      return "一句意象"
        case .map:        return "一张地图"
        case .characters: return "一群人"
        case .event:      return "一起事件"
        case .importFile: return "已有企划"
        case .blank:      return "空白"
        }
    }
}

// MARK: - AI 的位置（把授权说成立场）

private enum AIStance: String, CaseIterable, Identifiable {
    case scribe, assist, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .scribe: return "只做书记员"
        case .assist: return "可整理校对"
        case .none:   return "完全不介入"
        }
    }
}

// MARK: - 横向 chip 选择器

private struct FlowChips: View {
    var items: [(String, String)]
    var selected: String
    var onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: AtlasSpacing.s) {
            ForEach(items, id: \.0) { item in
                let isOn = item.0 == selected
                Button { onSelect(item.0) } label: {
                    Text(item.1)
                        .font(AtlasFont.caption)
                        .foregroundStyle(isOn ? AtlasColor.textPrimary : AtlasColor.textSecondary)
                        .padding(.horizontal, AtlasSpacing.m)
                        .padding(.vertical, 6)
                        .background(
                            isOn ? Color.white.opacity(0.10) : AtlasP1Glass.darkFill,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(isOn ? AtlasColor.borderStrong : AtlasColor.borderSubtle)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 回声（AI 草案）

private enum EchoState: String {
    case pending = "待你决定"
    case accepted = "已接受"
    case rewritten = "已改写"
    case silenced = "已沉默"
}

private struct EchoSuggestion: Identifiable {
    let id: String
    let type: String
    let title: String
    let detail: String
    let symbol: String

    static let samples: [EchoSuggestion] = [
        .init(id: "location-1", type: "地点", title: "雾港",
              detail: "声音会在退潮时被海水带走。", symbol: "mappin.and.ellipse"),
        .init(id: "location-2", type: "地点", title: "白塔档案室",
              detail: "保存远航记录与失声者口述。", symbol: "building.columns"),
        .init(id: "location-3", type: "地点", title: "失声海域",
              detail: "地图无法稳定记录的危险水域。", symbol: "water.waves"),
        .init(id: "event-1", type: "事件", title: "夜航守望",
              detail: "参与者的回应决定雾港是否开放。", symbol: "bolt.horizontal.circle"),
        .init(id: "rule-1", type: "规则", title: "使用边界",
              detail: "文本只可整理；图片生成与画风模仿关闭。", symbol: "checkmark.shield")
    ]
}

private struct EchoRow: View {
    var suggestion: EchoSuggestion
    var state: EchoState
    var onChange: (EchoState) -> Void

    private var confirmed: Bool { state == .accepted || state == .rewritten }
    private var silenced: Bool { state == .silenced }

    var body: some View {
        HStack(spacing: AtlasSpacing.m) {
            Image(systemName: suggestion.symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 34, height: 34)
                .foregroundStyle(confirmed ? AtlasColor.textPrimary : AtlasColor.textSecondary)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AtlasSpacing.s) {
                    Text(suggestion.type)
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                    Text(suggestion.title)
                        .font(AtlasFont.serifBody)
                        .foregroundStyle(AtlasColor.textPrimary)
                }
                Text(suggestion.detail)
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button("接受") { onChange(.accepted) }
                Button("改写") { onChange(.rewritten) }
                Button("让它沉默") { onChange(.silenced) }
            } label: {
                HStack(spacing: 5) {
                    Text(state.rawValue)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .font(AtlasFont.caption)
                .foregroundStyle(confirmed ? AtlasColor.textPrimary : AtlasColor.textSecondary)
                .padding(.horizontal, AtlasSpacing.s)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(AtlasSpacing.m)
        .background(AtlasP1Glass.darkFill, in: RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous)
                .stroke(AtlasColor.borderSubtle)
        )
        .opacity(silenced ? 0.4 : 1)
    }
}
