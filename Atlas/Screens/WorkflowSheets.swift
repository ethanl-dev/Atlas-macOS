import SwiftUI

struct ApplicationFlowSheet: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.dismiss) private var dismiss

    @State private var stage = 0
    @State private var characterName = "岑"
    @State private var role = "档案修复师"
    @State private var motivation = "希望修复那些被潮汐带走的远航记录。"
    @State private var acceptsPolicy = false

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader("申请加入", subtitle: "STEP \(stage + 1) / 3", dismiss: dismiss)
            Divider().overlay(AtlasColor.borderSubtle)

            Group {
                if stage == 0 {
                    applicationIntro
                } else if stage == 1 {
                    characterForm
                } else {
                    applicationReview
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(AtlasColor.borderSubtle)

            HStack {
                if stage > 0 {
                    Button("返回") {
                        withAnimation(.snappy) { stage -= 1 }
                    }
                    .buttonStyle(.atlas(.glass))
                }
                Spacer()
                Button {
                    if stage < 2 {
                        withAnimation(.snappy) { stage += 1 }
                    } else {
                        model.showToast("申请已提交，可在收件箱查看审核进度")
                        dismiss()
                    }
                } label: {
                    AtlasButtonLabel(
                        title: stage == 2 ? "提交申请" : "继续",
                        systemImage: "arrow.right"
                    )
                }
                .buttonStyle(.atlas(.primary))
                .disabled((stage == 0 && !acceptsPolicy) || (stage == 1 && characterName.isEmpty))
            }
            .padding(AtlasSpacing.l)
        }
        .frame(width: 700, height: 590)
        .background(AtlasCanvasBackground())
    }

    private var applicationIntro: some View {
        HStack(spacing: AtlasSpacing.xxl) {
            ApplicationOrbit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                Text("先确认你如何进入这个世界")
                    .font(AtlasFont.title)
                Text("本企划采用审核制。你将提交一个角色骨架，管理者只检查设定兼容性、授权与材料完整度。")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                    Label("持续招募", systemImage: "checkmark")
                    Label("预计 2–3 天完成审核", systemImage: "clock")
                    Label("允许文字整理，关闭图片生成", systemImage: "checkmark.shield")
                }
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textSecondary)

                Toggle("我已阅读 AI 与作品授权说明", isOn: $acceptsPolicy)
                    .toggleStyle(.switch)
                    .font(AtlasFont.body)

                Spacer()
            }
            .frame(width: 300)
        }
        .padding(AtlasSpacing.xxl)
    }

    private var characterForm: some View {
        HStack(alignment: .top, spacing: AtlasSpacing.xxl) {
            CharacterPortrait(seed: 5, initials: String(characterName.prefix(1)))
                .frame(width: 220, height: 300)

            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                formField("角色名") {
                    TextField("角色名", text: $characterName)
                }
                formField("身份 / 职业") {
                    TextField("角色如何在世界中生活", text: $role)
                }
                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    Text("进入世界的理由")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                    TextEditor(text: $motivation)
                        .font(AtlasFont.body)
                        .scrollContentBackground(.hidden)
                        .padding(AtlasSpacing.s)
                        .frame(height: 120)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
                }
                Button {
                    model.showToast("补充材料已添加")
                } label: {
                    Label("添加设卡或参考资料", systemImage: "paperclip")
                        .font(AtlasFont.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AtlasSpacing.xxl)
    }

    private var applicationReview: some View {
        HStack(spacing: AtlasSpacing.xxxl) {
            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                Text("申请路径")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
                ApplicationPath()
                Text("提交后，材料检查、管理者审核和补充说明都会进入收件箱。")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                Text(characterName)
                    .font(AtlasFont.title)
                Text(role)
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
                Text(motivation)
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(AtlasColor.borderSubtle)
                Label("AI 与授权声明已确认", systemImage: "checkmark")
                    .font(AtlasFont.caption)
            }
            .padding(AtlasSpacing.l)
            .frame(width: 290, alignment: .leading)
            .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.panel))
        }
        .padding(AtlasSpacing.xxl)
    }

    private func formField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            Text(title)
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textTertiary)
            content()
                .textFieldStyle(.plain)
                .font(AtlasFont.body)
                .padding(AtlasSpacing.m)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
        }
    }
}

struct PublishCheckSheet: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var published = false

    private let checks = [
        ("世界名与一句话钩子", true),
        ("公开简介", true),
        ("参与方式", true),
        ("AI 与授权声明", true),
        ("至少一项规则", true),
        ("报名状态", true)
    ]

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader("发布检查", subtitle: published ? "PUBLISHED" : "READY 100%", dismiss: dismiss)
            Divider().overlay(AtlasColor.borderSubtle)

            HStack(spacing: AtlasSpacing.xxl) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)
                    Circle()
                        .trim(from: 0, to: 1)
                        .stroke(Color.white, style: .init(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Image(systemName: published ? "checkmark" : "paperplane")
                            .font(.system(size: 28, weight: .light))
                        Text(published ? "已发布" : "可发布")
                            .font(AtlasFont.heading)
                    }
                }
                .frame(width: 220, height: 220)

                VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                    ForEach(checks, id: \.0) { check in
                        HStack {
                            Image(systemName: check.1 ? "checkmark.circle.fill" : "circle")
                            Text(check.0)
                                .font(AtlasFont.body)
                            Spacer()
                        }
                        .padding(.vertical, 5)
                    }

                    Divider().overlay(AtlasColor.borderSubtle)

                    Text(published
                         ? "公开页已经更新。星图与分享链接将使用这个版本。"
                         : "发布不会自动修改正式设定，只会公开当前已确认的世界内容。")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 310)
            }
            .padding(AtlasSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(AtlasColor.borderSubtle)

            HStack {
                Button {
                    model.accessMode = .publicPreview
                    model.destination = .publicPreview
                    dismiss()
                } label: {
                    AtlasButtonLabel(title: "预览公开页", systemImage: "eye")
                }
                .buttonStyle(.atlas(.glass))

                Spacer()

                if !published {
                    Menu {
                        Button("发布预热页") {
                            published = true
                            model.showToast("预热页已发布")
                        }
                        Button("发布招募页") {
                            published = true
                            model.showToast("招募页已发布")
                        }
                    } label: {
                        AtlasButtonLabel(title: "发布", systemImage: "paperplane")
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.atlas(.primary))
                } else {
                    Button("完成") { dismiss() }
                        .buttonStyle(.atlas(.primary))
                }
            }
            .padding(AtlasSpacing.l)
        }
        .frame(width: 650, height: 520)
        .background(AtlasCanvasBackground())
    }
}

struct PublicPageEditorSheet: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var hook: String
    @State private var introduction =
        "雾潮纪元第四十二年，北方海域的旧航线再度开放。来自未来的信，正在退潮后的白沙滩上等待收件人。"
    @State private var participation = "审核制"
    @State private var recruitmentOpen = true

    init(model: AtlasAppModel) {
        self.model = model
        _hook = State(initialValue: model.activeWorld.hook)
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader("编辑公开页", subtitle: "OWNER ONLY", dismiss: dismiss)
            Divider().overlay(AtlasColor.borderSubtle)

            ScrollView {
                VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                    editorField("一句话钩子") {
                        TextField("用一句话邀请大家进入这个世界", text: $hook)
                    }
                    editorField("公开简介") {
                        TextEditor(text: $introduction)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                    }
                    editorField("参与方式") {
                        Picker("参与方式", selection: $participation) {
                            Text("审核制").tag("审核制")
                            Text("邀请制").tag("邀请制")
                            Text("自由参与").tag("自由参与")
                        }
                        .labelsHidden()
                    }
                    Toggle("开放报名", isOn: $recruitmentOpen)
                        .font(AtlasFont.body)
                }
                .padding(AtlasSpacing.xxl)
            }

            Divider().overlay(AtlasColor.borderSubtle)
            HStack {
                Text("保存后仍需通过发布检查，才会更新访客看到的版本。")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.atlas(.ghost))
                Button {
                    model.showToast("公开页草稿已保存")
                    dismiss()
                } label: {
                    AtlasButtonLabel(title: "保存草稿", systemImage: "checkmark")
                }
                .buttonStyle(.atlas(.primary))
                .disabled(hook.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(AtlasSpacing.l)
        }
        .frame(width: 680, height: 620)
        .background(AtlasCanvasBackground())
    }

    private func editorField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            Text(title)
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textTertiary)
            content()
                .textFieldStyle(.plain)
                .font(AtlasFont.body)
                .padding(AtlasSpacing.m)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
        }
    }
}

struct ObjectEditorSheet: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var summary = ""
    @State private var mentions: [String] = []
    @State private var type: WorldObjectType = .location
    @State private var status: WorldObjectStatus = .draft

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader("世界对象", subtitle: "保存后进入待确认层", dismiss: dismiss)
            Divider().overlay(AtlasColor.borderSubtle)

            HStack(alignment: .top, spacing: AtlasSpacing.xxl) {
                VStack(spacing: AtlasSpacing.m) {
                    ForEach(WorldObjectType.allCases) { item in
                        Button {
                            type = item
                        } label: {
                            HStack {
                                Image(systemName: item.symbol)
                                    .frame(width: 20)
                                Text(item.rawValue)
                                Spacer()
                            }
                            .font(AtlasFont.body)
                            .foregroundStyle(type == item ? AtlasColor.textPrimary : AtlasColor.textSecondary)
                            .padding(AtlasSpacing.s)
                            .background(type == item ? Color.white.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 150)

                VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                    TextField("对象名称", text: $name)
                        .textFieldStyle(.plain)
                        .font(AtlasFont.heading)
                        .padding(AtlasSpacing.m)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))

                    MentionTextEditor(text: $summary, mentions: $mentions)

                    Picker("状态", selection: $status) {
                        Text("草稿").tag(WorldObjectStatus.draft)
                        Text("待确认").tag(WorldObjectStatus.pending)
                    }
                    .pickerStyle(.segmented)

                    Label("Agent 只能提出字段建议，不能直接写入正式设定", systemImage: "sparkles")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }
            .padding(AtlasSpacing.xl)
            .frame(maxHeight: .infinity)

            Divider().overlay(AtlasColor.borderSubtle)

            HStack {
                Spacer()
                Button {
                    let base = name.isEmpty ? "已创建未命名\(type.rawValue)草稿" : "已创建「\(name)」草稿"
                    model.showToast(mentions.isEmpty ? base : "\(base)，含 \(mentions.count) 处提及")
                    dismiss()
                } label: {
                    AtlasButtonLabel(title: "保存到待确认层", systemImage: "checkmark")
                }
                .buttonStyle(.atlas(.primary))
            }
            .padding(AtlasSpacing.l)
        }
        .frame(width: 650, height: 520)
        .background(AtlasCanvasBackground())
    }
}

struct NewTaskSheet: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var summary = ""
    @State private var taskType = "主线任务"
    @State private var capacity = 8.0

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader("发布任务", subtitle: "先建立草稿，再公开招募", dismiss: dismiss)
            Divider().overlay(AtlasColor.borderSubtle)

            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                Picker("任务类型", selection: $taskType) {
                    ForEach(["主线任务", "支线任务", "采集任务", "角色互动", "开放命题"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .pickerStyle(.segmented)

                TextField("任务名称", text: $title)
                    .textFieldStyle(.plain)
                    .font(AtlasFont.heading)
                    .padding(AtlasSpacing.m)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))

                TextEditor(text: $summary)
                    .font(AtlasFont.body)
                    .scrollContentBackground(.hidden)
                    .padding(AtlasSpacing.s)
                    .frame(height: 130)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))

                VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                    HStack {
                        Text("参与上限")
                        Spacer()
                        Text("\(Int(capacity)) 人")
                            .font(AtlasFont.mono)
                    }
                    Slider(value: $capacity, in: 2...24, step: 1)
                        .tint(.white)
                }
                .font(AtlasFont.body)

                HStack {
                    Label("关联地点", systemImage: "mappin")
                    Text("雾港")
                    Spacer()
                    Button("更改") {
                        model.showToast("已打开世界对象选择器")
                    }
                    .buttonStyle(.plain)
                }
                .font(AtlasFont.caption)
                .padding(AtlasSpacing.m)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
            }
            .padding(AtlasSpacing.xl)
            .frame(maxHeight: .infinity)

            Divider().overlay(AtlasColor.borderSubtle)

            HStack {
                Spacer()
                Button {
                    model.showToast("任务草稿已创建")
                    dismiss()
                } label: {
                    AtlasButtonLabel(title: "创建任务草稿", systemImage: "checkmark")
                }
                .buttonStyle(.atlas(.primary))
            }
            .padding(AtlasSpacing.l)
        }
        .frame(width: 660, height: 550)
        .background(AtlasCanvasBackground())
    }
}

private func sheetHeader(_ title: String, subtitle: String, dismiss: DismissAction) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(AtlasFont.heading)
            Text(subtitle)
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
}

private struct ApplicationOrbit: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for index in 0..<3 {
                    let radius = CGFloat(48 + index * 46)
                    context.stroke(
                        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white.opacity(0.06 + Double(index) * 0.025)),
                        style: .init(lineWidth: 1, dash: [3, 7])
                    )
                }
                context.fill(Path(ellipseIn: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24)), with: .color(.white))
                let point = CGPoint(x: center.x + 128, y: center.y)
                context.fill(Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)), with: .color(.white.opacity(0.65)))
            }

            Text("你的角色")
                .font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textTertiary)
                .position(x: proxy.size.width / 2 + 128, y: proxy.size.height / 2 + 24)
            Text("雾海来信")
                .font(AtlasFont.label)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2 + 34)
        }
    }
}

private struct ApplicationPath: View {
    var body: some View {
        VStack(spacing: AtlasSpacing.m) {
            pathStep("1", title: "提交角色骨架", active: true)
            pathStep("2", title: "材料与授权检查")
            pathStep("3", title: "管理者审核")
            pathStep("4", title: "进入世界")
        }
    }

    private func pathStep(_ number: String, title: String, active: Bool = false) -> some View {
        HStack(spacing: AtlasSpacing.m) {
            Text(number)
                .font(AtlasFont.monoSmall)
                .foregroundStyle(active ? AtlasColor.inverse : AtlasColor.textSecondary)
                .frame(width: 24, height: 24)
                .background(active ? Color.white : Color.white.opacity(0.06), in: Circle())
            Text(title)
                .font(AtlasFont.body)
            Spacer()
        }
    }
}
