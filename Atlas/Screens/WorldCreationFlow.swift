import SwiftUI

struct WorldCreationFlow: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil

    @State private var stage = 0
    @State private var startKind = CreationStartKind.image
    @State private var worldName = "雾海来信"
    @State private var hook = "潮汐带走声音，白塔保存远航记录。"
    @State private var projectType = "混合企"
    @State private var allowsTextAI = true
    @State private var skeletonStates: [String: SkeletonState] = [:]

    var body: some View {
        VStack(spacing: 0) {
            titlebar
            Divider().overlay(AtlasColor.borderSubtle)
            stageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().overlay(AtlasColor.borderSubtle)
            footer
        }
        .frame(minWidth: 820, idealWidth: 920, minHeight: 610, idealHeight: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AtlasCanvasBackground())
    }

    private var titlebar: some View {
        HStack {
            AtlasMark()
            VStack(alignment: .leading, spacing: 1) {
                Text("创建世界")
                    .font(AtlasFont.heading)
                Text("STEP \(stage + 1) / 4")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            Spacer()
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.atlas(.glass))
            .help("关闭")
        }
        .padding(AtlasSpacing.l)
    }

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case 0: startStage
        case 1: intentStage
        case 2: skeletonStage
        default: readyStage
        }
    }

    private var startStage: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text("从哪里开始？")
                    .font(AtlasFont.display)
                Text("选一个离你现在的想法最近的入口，之后都可以改变。")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AtlasSpacing.m),
                GridItem(.flexible(), spacing: AtlasSpacing.m),
                GridItem(.flexible(), spacing: AtlasSpacing.m)
            ], spacing: AtlasSpacing.m) {
                ForEach(CreationStartKind.allCases) { kind in
                    Button {
                        withAnimation(.snappy) { startKind = kind }
                    } label: {
                        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 22, weight: .light))
                            Spacer()
                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title)
                                    .font(AtlasFont.heading)
                                Text(kind.subtitle)
                                    .font(AtlasFont.caption)
                                    .foregroundStyle(AtlasColor.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .foregroundStyle(AtlasColor.textPrimary)
                        .padding(AtlasSpacing.l)
                        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
                        .background(
                            startKind == kind ? Color.white.opacity(0.10) : Color.white.opacity(0.025),
                            in: RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous)
                                .stroke(startKind == kind ? AtlasColor.borderStrong : AtlasColor.borderSubtle)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(AtlasSpacing.xxl)
    }

    private var intentStage: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    Text("先写一句只有你知道为什么心动的话。")
                        .font(AtlasFont.title)
                    Text("Atlas 只搭骨架，正式设定始终由你确认。")
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textSecondary)
                }

                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    Text("世界名")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                    TextField("可以稍后再取名", text: $worldName)
                        .textFieldStyle(.plain)
                        .font(AtlasFont.heading)
                        .padding(AtlasSpacing.m)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
                }

                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    Text("一句世界意象")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                    TextEditor(text: $hook)
                        .font(AtlasFont.body)
                        .scrollContentBackground(.hidden)
                        .padding(AtlasSpacing.s)
                        .frame(height: 120)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
                }

                Picker("企划类型", selection: $projectType) {
                    ForEach(["画企", "文企", "混合企", "跑团", "长期世界"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("允许 Agent 整理与校对文本", isOn: $allowsTextAI)
                    .toggleStyle(.switch)
                    .font(AtlasFont.body)

                Spacer()
            }
            .padding(AtlasSpacing.xxl)
            .frame(maxWidth: 560)

            intentPreview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.025))
        }
    }

    private var intentPreview: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for index in 0..<5 {
                    let angle = Double(index) / 5 * Double.pi * 2
                    let point = CGPoint(
                        x: center.x + cos(angle) * min(size.width, size.height) * 0.28,
                        y: center.y + sin(angle) * min(size.width, size.height) * 0.28
                    )
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: point)
                    context.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 1)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)), with: .color(.white.opacity(0.7)))
                }
                context.fill(Path(ellipseIn: CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20)), with: .color(.white))
            }
            VStack(spacing: AtlasSpacing.xs) {
                Text(worldName.isEmpty ? "未命名世界" : worldName)
                    .font(AtlasFont.heading)
                Text("骨架正在形成")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
                    .padding(.top, 64)
            }
        }
    }

    private var skeletonStage: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                Text("原始意图")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
                Text(hook)
                    .font(AtlasFont.heading)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(AtlasColor.borderSubtle)
                Label("这些都是草案", systemImage: "hourglass")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
                Text("接受后进入待确认层，不会直接成为正式设定。")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
                Spacer()
            }
            .padding(AtlasSpacing.xl)
            .frame(width: 230)
            .background(Color.white.opacity(0.025))

            ScrollView {
                LazyVStack(spacing: AtlasSpacing.s) {
                    ForEach(SkeletonSuggestion.samples) { suggestion in
                        SkeletonRow(
                            suggestion: suggestion,
                            state: skeletonStates[suggestion.id] ?? .pending
                        ) { newState in
                            withAnimation(.snappy) {
                                skeletonStates[suggestion.id] = newState
                            }
                        }
                    }
                }
                .padding(AtlasSpacing.xl)
            }

            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                Text("发布准备度")
                    .font(AtlasFont.heading)
                readiness("世界气氛", value: 0.92)
                readiness("参与方式", value: 0.68)
                readiness("规则清晰度", value: 0.54)
                readiness("AI / 授权", value: allowsTextAI ? 0.82 : 1)
                readiness("公开页", value: 0.46)
                Spacer()
                Text("\(acceptedCount) 项已接受")
                    .font(AtlasFont.mono)
                    .foregroundStyle(AtlasColor.textSecondary)
            }
            .padding(AtlasSpacing.xl)
            .frame(width: 210)
            .background(Color.white.opacity(0.025))
        }
    }

    private var readyStage: some View {
        HStack(spacing: AtlasSpacing.xxl) {
            WorldSeedPreview()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .light))
                Text("\(worldName) 已经有了第一副骨架")
                    .font(AtlasFont.title)
                Text("地图、Wiki、任务和公开页会使用同一套世界对象。进入后可以继续移动地点、补充规则，并从管理模式预览参与者看到的内容。")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    summaryRow("候选地点", value: "3")
                    summaryRow("当前事件", value: "1")
                    summaryRow("规则模块", value: "1")
                    summaryRow("待确认风险", value: "2")
                }
                .padding(.vertical, AtlasSpacing.s)

                Spacer()
            }
            .frame(width: 330)
        }
        .padding(AtlasSpacing.xxl)
    }

    private var footer: some View {
        HStack {
            if stage > 0 {
                Button {
                    withAnimation(.snappy) { stage -= 1 }
                } label: {
                    AtlasButtonLabel(title: "返回", systemImage: "chevron.left")
                }
                .buttonStyle(.atlas(.glass))
            }

            Spacer()

            if stage < 3 {
                Button {
                    withAnimation(.snappy) { stage += 1 }
                } label: {
                    AtlasButtonLabel(
                        title: stage == 2 ? "生成 World Canvas" : "继续",
                        systemImage: "arrow.right"
                    )
                }
                .buttonStyle(.atlas(.primary))
                .disabled(stage == 1 && hook.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Button {
                    model.creationCompleted = true
                    model.accessMode = .manage
                    model.destination = .canvas
                    close()
                } label: {
                    AtlasButtonLabel(title: "进入 World Canvas", systemImage: "arrow.right")
                }
                .buttonStyle(.atlas(.primary))
            }
        }
        .padding(AtlasSpacing.l)
    }

    private var acceptedCount: Int {
        skeletonStates.values.filter { $0 == .accepted || $0 == .rewritten }.count
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func readiness(_ label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(AtlasFont.caption)
                Spacer()
                Text("\(Int(value * 100))%").font(AtlasFont.monoSmall)
            }
            ProgressView(value: value)
                .progressViewStyle(.linear)
                .tint(.white)
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AtlasFont.body)
                .foregroundStyle(AtlasColor.textSecondary)
            Spacer()
            Text(value)
                .font(AtlasFont.mono)
        }
        .padding(.vertical, AtlasSpacing.s)
        .overlay(alignment: .bottom) {
            Divider().overlay(AtlasColor.borderSubtle)
        }
    }
}

private enum CreationStartKind: String, CaseIterable, Identifiable {
    case image
    case map
    case characters
    case event
    case importFile
    case blank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image: return "一句世界意象"
        case .map: return "地图底盘"
        case .characters: return "角色群像"
        case .event: return "事件机制"
        case .importFile: return "导入企划书"
        case .blank: return "空白世界"
        }
    }

    var subtitle: String {
        switch self {
        case .image: return "从一个气氛、画面或句子开始"
        case .map: return "先确定世界发生在哪里"
        case .characters: return "从人物关系长出世界"
        case .event: return "先定义世界如何变化"
        case .importFile: return "整理已有文档和资料"
        case .blank: return "直接进入干净的 Canvas"
        }
    }

    var symbol: String {
        switch self {
        case .image: return "quote.opening"
        case .map: return "map"
        case .characters: return "person.3"
        case .event: return "bolt.horizontal"
        case .importFile: return "square.and.arrow.down"
        case .blank: return "circle.dashed"
        }
    }
}

private enum SkeletonState: String {
    case pending = "待确认"
    case accepted = "已接受"
    case rewritten = "已改写"
    case ignored = "暂时不用"
}

private struct SkeletonSuggestion: Identifiable {
    let id: String
    let type: String
    let title: String
    let detail: String
    let symbol: String

    static let samples: [SkeletonSuggestion] = [
        .init(id: "location-1", type: "地点", title: "雾港",
              detail: "声音会在退潮时被海水带走。", symbol: "mappin.and.ellipse"),
        .init(id: "location-2", type: "地点", title: "白塔档案室",
              detail: "保存远航记录与失声者口述。", symbol: "building.columns"),
        .init(id: "location-3", type: "地点", title: "失声海域",
              detail: "地图无法稳定记录的危险水域。", symbol: "water.waves"),
        .init(id: "event-1", type: "事件", title: "夜航守望",
              detail: "参与者的回应决定雾港是否开放。", symbol: "bolt.horizontal.circle"),
        .init(id: "rule-1", type: "规则", title: "AI 使用边界",
              detail: "文本只可整理；图片生成与画风模仿关闭。", symbol: "checkmark.shield")
    ]
}

private struct SkeletonRow: View {
    var suggestion: SkeletonSuggestion
    var state: SkeletonState
    var onChange: (SkeletonState) -> Void

    var body: some View {
        HStack(spacing: AtlasSpacing.m) {
            Image(systemName: suggestion.symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(suggestion.type)
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                    Text(suggestion.title)
                        .font(AtlasFont.label)
                }
                Text(suggestion.detail)
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
            }

            Spacer()

            Menu {
                Button("接受") { onChange(.accepted) }
                Button("改写") { onChange(.rewritten) }
                Button("暂时不用") { onChange(.ignored) }
            } label: {
                HStack(spacing: 5) {
                    Text(state.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(AtlasFont.caption)
                .foregroundStyle(state == .accepted || state == .rewritten ? AtlasColor.textPrimary : AtlasColor.textSecondary)
                .padding(.horizontal, AtlasSpacing.s)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(AtlasSpacing.m)
        .background(Color.white.opacity(0.025))
        .overlay(alignment: .bottom) {
            Divider().overlay(AtlasColor.borderSubtle)
        }
    }
}

private struct WorldSeedPreview: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.50, y: size.height * 0.48)
                let points: [(CGPoint, String)] = [
                    (.init(x: size.width * 0.25, y: size.height * 0.28), "雾港"),
                    (.init(x: size.width * 0.72, y: size.height * 0.26), "白塔"),
                    (.init(x: size.width * 0.78, y: size.height * 0.68), "失声海域"),
                    (.init(x: size.width * 0.28, y: size.height * 0.72), "夜航守望")
                ]
                for (point, _) in points {
                    var line = Path()
                    line.move(to: center)
                    line.addCurve(
                        to: point,
                        control1: CGPoint(x: center.x, y: point.y),
                        control2: CGPoint(x: point.x, y: center.y)
                    )
                    context.stroke(line, with: .color(.white.opacity(0.14)), style: .init(lineWidth: 1, dash: [3, 5]))
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(.white.opacity(0.8)))
                }
                context.fill(Path(ellipseIn: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24)), with: .color(.white))
            }

            Text("WORLD")
                .font(AtlasFont.monoSmall)
                .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.48 + 32)
        }
    }
}
