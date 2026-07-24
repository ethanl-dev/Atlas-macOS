import SwiftUI

struct InteractionHubView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var selectedState: AtlasTask.State = .open

    private var visibleTasks: [AtlasTask] {
        model.tasks.filter { $0.state == selectedState }
    }

    private var selectedTask: AtlasTask {
        if let id = model.selectedTaskID,
           let task = model.tasks.first(where: { $0.id == id }) {
            return task
        }
        return visibleTasks.first ?? model.tasks[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AtlasColor.borderSubtle)

            GeometryReader { proxy in
                if proxy.size.width >= 820 {
                    HSplitView {
                        taskBoard.frame(minWidth: 440)
                        taskDetail.frame(minWidth: 300, idealWidth: 360, maxWidth: 440)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            taskBoard.frame(minHeight: 430)
                            Divider().overlay(AtlasColor.borderSubtle)
                            taskDetail.frame(minHeight: 480)
                        }
                    }
                }
            }
        }
        .background(AtlasCanvasBackground())
        .onAppear {
            if model.selectedTaskID == nil {
                model.selectedTaskID = model.tasks[0].id
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text("任务与互动")
                    .font(AtlasFont.title)
                Text(model.accessMode == .manage
                     ? "发布任务、推进事件并处理世界状态变化"
                     : "使用角色接取任务、建立关系并提交创作")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
            }
            Spacer()

            if model.accessMode == .manage {
                Button {
                    model.activeSheet = .newTask
                } label: {
                    AtlasButtonLabel(title: "发布任务", systemImage: "plus")
                }
                .buttonStyle(.atlas(.primary))
            } else if model.activeRole == .participant {
                Button {
                    model.activeSheet = .submitWork
                } label: {
                    AtlasButtonLabel(title: "提交创作", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.atlas(.primary))
            }
        }
        .padding(AtlasSpacing.xl)
    }

    private var taskBoard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach([AtlasTask.State.open, .active, .settling], id: \.rawValue) { state in
                    Button {
                        selectedState = state
                        model.selectedTaskID = model.tasks.first(where: { $0.state == state })?.id
                    } label: {
                        HStack(spacing: AtlasSpacing.s) {
                            Text(state.rawValue)
                                .font(AtlasFont.label)
                            Text("\(model.tasks.filter { $0.state == state }.count)")
                                .font(AtlasFont.monoSmall)
                                .foregroundStyle(AtlasColor.textTertiary)
                        }
                        .foregroundStyle(selectedState == state ? AtlasColor.textPrimary : AtlasColor.textSecondary)
                        .padding(.horizontal, AtlasSpacing.l)
                        .padding(.vertical, AtlasSpacing.m)
                        .overlay(alignment: .bottom) {
                            if selectedState == state {
                                Rectangle().fill(Color.white).frame(height: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, AtlasSpacing.l)
            .background(AtlasColor.canvas.opacity(0.34))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleTasks) { task in
                        TaskRow(
                            task: task,
                            selected: model.selectedTaskID == task.id,
                            joined: model.joinedTaskIDs.contains(task.id)
                        ) {
                            model.selectedTaskID = task.id
                        }
                        Divider().overlay(AtlasColor.borderSubtle)
                    }
                }
            }
        }
    }

    private var taskDetail: some View {
        let task = selectedTask

        return VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            HStack {
                Label(task.state.rawValue, systemImage: stateSymbol(task.state))
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
                Spacer()
                Menu {
                    Button("复制任务链接") {
                        model.showToast("任务链接已复制")
                    }
                    if model.activeRole == .owner {
                        Button("在地图编辑器中定位") {
                            model.navigate(to: .canvas)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                Text(task.title)
                    .font(AtlasFont.title)
                Text(task.summary)
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ParticipationGauge(task: task)
                .frame(height: 118)

            Divider().overlay(AtlasColor.borderSubtle)

            Text("关联世界对象")
                .font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textTertiary)

            ForEach(task.objectIDs, id: \.self) { id in
                let object = WorldObject.samples.first(where: { $0.id == id })
                Button {
                    if let object {
                        model.selectedObjectID = object.id
                    }
                    model.navigate(to: .canvas)
                } label: {
                    HStack {
                        Image(systemName: object?.type.symbol ?? "circle")
                            .frame(width: 20)
                        Text(object?.name ?? id)
                            .font(AtlasFont.body)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                    .padding(.vertical, AtlasSpacing.s)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if model.activeRole == .owner {
                managementActions(task)
            } else if model.activeRole == .participant {
                participantActions(task)
            } else {
                visitorActions
            }
        }
        .padding(AtlasSpacing.xl)
        .background(AtlasColor.canvas.opacity(0.50))
    }

    private var visitorActions: some View {
        VStack(spacing: AtlasSpacing.s) {
            Label("游客可查看活动与参与情况", systemImage: "eye")
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AtlasSpacing.s)

            Button {
                model.showToast("已打开参与角色")
            } label: {
                AtlasButtonLabel(title: "查看参与角色", systemImage: "person.2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.atlas(.glass))
        }
    }

    private func managementActions(_ task: AtlasTask) -> some View {
        VStack(spacing: AtlasSpacing.s) {
            Button {
                if task.state == .settling {
                    model.showToast("已生成事件影响预览：3 个对象待确认")
                } else {
                    model.showToast("任务编辑器已进入草稿状态")
                }
            } label: {
                AtlasButtonLabel(
                    title: task.state == .settling ? "生成结算预览" : "编辑任务",
                    systemImage: task.state == .settling ? "point.3.connected.trianglepath.dotted" : "pencil"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.atlas(.primary))

            if task.state == .settling {
                Button {
                    model.destination = .review
                } label: {
                    AtlasButtonLabel(title: "审阅提交", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.atlas(.glass))
            }
        }
    }

    private func participantActions(_ task: AtlasTask) -> some View {
        let joined = model.joinedTaskIDs.contains(task.id)

        return VStack(spacing: AtlasSpacing.s) {
            if task.state == .open && !joined {
                Button {
                    model.joinTask(task)
                } label: {
                    AtlasButtonLabel(title: "使用「岑」接取", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.atlas(.primary))
            } else {
                Button {
                    model.activeSheet = .submitWork
                } label: {
                    AtlasButtonLabel(title: joined ? "提交任务回应" : "查看我的提交", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.atlas(.primary))
            }

            Button {
                model.showToast("已打开相关角色与关系")
            } label: {
                AtlasButtonLabel(title: "查看参与角色", systemImage: "person.2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.atlas(.glass))
        }
    }

    private func stateSymbol(_ state: AtlasTask.State) -> String {
        switch state {
        case .open: return "person.badge.plus"
        case .active: return "waveform.path.ecg"
        case .settling: return "hourglass"
        }
    }
}

private struct TaskRow: View {
    var task: AtlasTask
    var selected: Bool
    var joined: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AtlasSpacing.l) {
                VStack(spacing: 3) {
                    Text(String(format: "%02d", task.participants))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    Text(task.capacity.map { "/ \($0)" } ?? "参与")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                .frame(width: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: AtlasSpacing.s) {
                        Text(task.title)
                            .font(AtlasFont.heading)
                        if joined {
                            Text("已接取")
                                .font(AtlasFont.monoSmall)
                                .foregroundStyle(AtlasColor.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(Capsule().stroke(AtlasColor.borderSubtle))
                        }
                    }
                    Text(task.summary)
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .foregroundStyle(AtlasColor.textPrimary)
            .padding(.horizontal, AtlasSpacing.xl)
            .padding(.vertical, AtlasSpacing.l)
            .background(selected ? Color.white.opacity(0.065) : hovering ? Color.white.opacity(0.03) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct ParticipationGauge: View {
    var task: AtlasTask

    var body: some View {
        GeometryReader { proxy in
            let capacity = task.capacity ?? max(task.participants, 12)
            let progress = min(1, Double(task.participants) / Double(capacity))

            ZStack(alignment: .leading) {
                Canvas { context, size in
                    let y = size.height / 2
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(.white.opacity(0.10)), lineWidth: 1)

                    for index in 0..<capacity {
                        let x = capacity == 1 ? size.width / 2 : CGFloat(index) / CGFloat(capacity - 1) * size.width
                        let filled = index < task.participants
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)),
                            with: .color(.white.opacity(filled ? 0.9 : 0.14))
                        )
                    }
                }

                VStack(alignment: .leading) {
                    Text("\(Int(progress * 100))%")
                        .font(AtlasFont.mono)
                    Spacer()
                    Text(task.capacity == nil ? "开放参与" : "参与席位")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }
        }
    }
}

struct SubmitWorkSheet: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.dismiss) private var dismiss

    @State private var stage = 0
    @State private var selectedTaskID = "task-night-watch"
    @State private var selectedEvent = "第二幕 · 白塔封锁"
    @State private var relatedCharacterIDs: Set<String> = ["char-cen"]
    @State private var workType = "文字"
    @State private var workSubtype = "散文"
    @State private var title = "第七页日志背面坐标"
    @State private var content = "岑在被潮水浸没的航海日志背面发现了一段坐标。"
    @State private var tags = "第二幕, 调查, 第七码头"
    @State private var attachedFiles: [String] = []
    @State private var crossModule = false
    @State private var polished = false
    @State private var scaleScore = 2.0
    @State private var completionScore = 2.0
    @State private var bonusScore = 1.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("提交创作")
                        .font(AtlasFont.heading)
                    Text(stage == 0 ? "关联世界对象与任务" : "只衡量投入，不评判质量")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .padding(AtlasSpacing.l)

            Divider().overlay(AtlasColor.borderSubtle)

            if stage == 0 {
                submissionForm
            } else {
                selfRating
            }

            Divider().overlay(AtlasColor.borderSubtle)

            HStack {
                if stage > 0 {
                    Button("返回修改") {
                        withAnimation(.snappy) { stage = 0 }
                    }
                    .buttonStyle(.atlas(.glass))
                }
                Spacer()
                Button {
                    if stage == 0 {
                        withAnimation(.snappy) { stage = 1 }
                    } else {
                        let submission = AtlasSubmission(
                            id: "SUB-\(40 + model.submissions.count + model.characterApprovals.count + 1)",
                            title: title,
                            author: "岑",
                            state: .pending,
                            destination: "\(workType) · \(workSubtype) · \(selectedEvent)",
                            affectedObjects: relatedCharacterIDs.compactMap { characterID in
                                AtlasCharacterProfile.samples.first(where: { $0.id == characterID })?.name
                            } + ["夜航守望"],
                            wikiObjectID: nil,
                            wikiChangeKind: relatedCharacterIDs.count > 1 ? .confirmedRelationship : .newEntry,
                            authorCredits: relatedCharacterIDs.count > 1
                                ? [
                                    .init(name: "岑", avatarSeed: 1, timestamp: "刚刚提交", order: 0),
                                    .init(name: "关联角色拥有者", avatarSeed: 2, timestamp: "等待确认", order: 1)
                                ]
                                : nil
                        )
                        model.submitWorkForReview(
                            submission,
                            requiresCharacterApproval: relatedCharacterIDs.contains(where: { $0 != "char-cen" })
                        )
                        dismiss()
                    }
                } label: {
                    AtlasButtonLabel(
                        title: stage == 0 ? "继续自评" : "确认并提交",
                        systemImage: "arrow.right"
                    )
                }
                .buttonStyle(.atlas(.primary))
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(AtlasSpacing.l)
        }
        .frame(width: 820, height: 680)
        .background(AtlasCanvasBackground())
    }

    private var submissionForm: some View {
        ScrollView {
            HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                    Text("关联角色").font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                    ForEach(AtlasCharacterProfile.samples) { character in
                        Toggle(isOn: Binding(
                            get: { relatedCharacterIDs.contains(character.id) },
                            set: { selected in
                                if selected { relatedCharacterIDs.insert(character.id) }
                                else if character.id != "char-cen" { relatedCharacterIDs.remove(character.id) }
                            }
                        )) {
                            Label(character.name, systemImage: character.symbol)
                        }
                        .toggleStyle(.checkbox)
                        .disabled(character.id == "char-cen")
                    }

                    Picker("关联任务", selection: $selectedTaskID) {
                        ForEach(model.tasks) { task in
                            Text(task.title).tag(task.id)
                        }
                    }

                    Picker("关联活动", selection: $selectedEvent) {
                        ForEach(["第二幕 · 白塔封锁", "夜航守望", "自由互动"], id: \.self) { Text($0) }
                    }

                    Picker("作品类型", selection: $workType) {
                        ForEach(["文字", "绘画", "影像", "3D", "手工", "音乐", "程序"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    Picker("作品子类", selection: $workSubtype) {
                        ForEach(subtypes, id: \.self) { Text($0) }
                    }

                    Divider().overlay(AtlasColor.borderSubtle)
                    Toggle("跨模块互动", isOn: $crossModule).toggleStyle(.checkbox)
                    Toggle("超常精修投入", isOn: $polished).toggleStyle(.checkbox)
                    Label("AI 边界已应用", systemImage: "checkmark.shield")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textSecondary)
                }
                .frame(width: 250)

                VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                    TextField("作品标题", text: $title)
                        .textFieldStyle(.plain)
                        .font(AtlasFont.heading)
                        .padding(AtlasSpacing.m)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))

                    TextEditor(text: $content)
                        .font(AtlasFont.body)
                        .scrollContentBackground(.hidden)
                        .padding(AtlasSpacing.s)
                        .frame(height: 210)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))

                    TextField("标签，以逗号分隔", text: $tags)
                        .textFieldStyle(.plain)
                        .padding(AtlasSpacing.s)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))

                    Button {
                        attachedFiles.append("atlas-work-\(attachedFiles.count + 1).\(workType == "文字" ? "md" : "png")")
                    } label: {
                        Label("添加文件或外部链接", systemImage: "paperclip")
                            .font(AtlasFont.caption)
                    }
                    .buttonStyle(.plain)

                    ForEach(attachedFiles, id: \.self) { file in
                        Label(file, systemImage: "doc")
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textSecondary)
                    }
                }
            }
            .padding(AtlasSpacing.xl)
        }
    }

    private var subtypes: [String] {
        switch workType {
        case "文字": return ["散文", "诗歌", "剧本"]
        case "影像": return ["通用影像", "Machinima", "游戏实况"]
        case "绘画": return ["插画", "漫画", "动图"]
        default: return ["通用", "合作作品", "实验作品"]
        }
    }

    private var selfRating: some View {
        HStack(spacing: AtlasSpacing.xxl) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                Circle()
                    .trim(from: 0, to: min(totalScore / 12, 1))
                    .stroke(Color.white, style: .init(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(totalScore))")
                        .font(.system(size: 42, weight: .semibold, design: .monospaced))
                    Text("投入分")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }
            .frame(width: 220, height: 220)

            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                scoreSlider("创作规模", value: $scaleScore, range: 1...5)
                scoreSlider("完成程度", value: $completionScore, range: 1...4)
                scoreSlider("额外投入", value: $bonusScore, range: 0...3)

                Divider().overlay(AtlasColor.borderSubtle)

                Text("分数与创作质量无关，只记录本次投入。自评分会和作品一起公开，平台不进行 AI 检测或人工质量评分。")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AtlasSpacing.xxl)
        .frame(maxHeight: .infinity)
    }

    private var totalScore: Double {
        scaleScore + completionScore + bonusScore + (crossModule ? 2 : 0) + (polished ? 2 : 0)
    }

    private func scoreSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            HStack {
                Text(title)
                    .font(AtlasFont.label)
                Spacer()
                Text("+\(Int(value.wrappedValue))")
                    .font(AtlasFont.mono)
            }
            Slider(value: value, in: range, step: 1)
                .tint(.white)
        }
    }
}
