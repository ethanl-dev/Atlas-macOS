import SwiftUI

struct InboxView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var selectedID = "inbox-1"

    private let messages = AtlasInboxItem.samples

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    Text("收件箱")
                        .font(AtlasFont.title)
                    Text("申请、共同确认、审核结果和世界状态变化集中在这里")
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textSecondary)
                }
                Spacer()
                Button {
                    model.showToast("全部消息已标记为已读")
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(.atlas(.glass))
                .help("全部标记为已读")
            }
            .padding(AtlasSpacing.xl)

            Divider().overlay(AtlasColor.borderSubtle)

            HSplitView {
                messageList
                    .frame(minWidth: 300, idealWidth: 360, maxWidth: 430)
                messageDetail
                    .frame(minWidth: 440)
            }
        }
        .background(AtlasCanvasBackground())
    }

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(messages) { item in
                    Button {
                        selectedID = item.id
                    } label: {
                        HStack(alignment: .top, spacing: AtlasSpacing.m) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(item.unread ? 0.10 : 0.04), in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.title)
                                        .font(AtlasFont.label)
                                    Spacer()
                                    Text(item.time)
                                        .font(AtlasFont.monoSmall)
                                        .foregroundStyle(AtlasColor.textTertiary)
                                }
                                Text(item.summary)
                                    .font(AtlasFont.caption)
                                    .foregroundStyle(AtlasColor.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        .foregroundStyle(AtlasColor.textPrimary)
                        .padding(AtlasSpacing.l)
                        .background(selectedID == item.id ? Color.white.opacity(0.065) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(AtlasColor.borderSubtle)
                }
            }
        }
        .background(AtlasColor.canvas.opacity(0.50))
    }

    private var messageDetail: some View {
        let item = messages.first(where: { $0.id == selectedID }) ?? messages[0]

        return VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            HStack {
                Image(systemName: item.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.07), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(AtlasFont.title)
                    Text("\(item.source) · \(item.time)")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }

            Divider().overlay(AtlasColor.borderSubtle)

            Text(item.detail)
                .font(.system(size: 16))
                .foregroundStyle(AtlasColor.textSecondary)
                .lineSpacing(7)
                .frame(maxWidth: 680, alignment: .leading)

            MessagePath(kind: item.kind)
                .frame(height: 190)
                .frame(maxWidth: 680)

            Spacer()

            HStack {
                Button {
                    model.showToast("消息已归档")
                } label: {
                    AtlasButtonLabel(title: "归档", systemImage: "archivebox")
                }
                .buttonStyle(.atlas(.ghost))

                Spacer()

                Button {
                    switch item.kind {
                    case .review:
                        model.accessMode = .manage
                        model.destination = .review
                    case .task:
                        model.destination = .tasks
                    case .world:
                        model.destination = .canvas
                    }
                } label: {
                    AtlasButtonLabel(title: item.action, systemImage: "arrow.right")
                }
                .buttonStyle(.atlas(.primary))
            }
        }
        .padding(AtlasSpacing.xxl)
    }
}

private struct AtlasInboxItem: Identifiable {
    enum Kind { case review, task, world }

    let id: String
    let title: String
    let summary: String
    let detail: String
    let source: String
    let time: String
    let symbol: String
    let action: String
    let kind: Kind
    let unread: Bool

    static let samples: [AtlasInboxItem] = [
        .init(id: "inbox-1", title: "关系申请等待共同确认",
              summary: "岑希望与伊莱建立临时同盟。",
              detail: "这项关系会影响夜航守望事件的日志公开方式。双方确认后，关系将进入角色时间线，并成为 Wiki 候选变更。",
              source: "雾海来信", time: "刚刚", symbol: "person.2", action: "处理确认", kind: .review, unread: true),
        .init(id: "inbox-2", title: "夜航守望将在 48 小时后关闭",
              summary: "你已经接取任务，但还没有提交回应。",
              detail: "在截止前提交文字、绘画或其他创作。作品可以关联雾港、白塔和参与角色，并按照投入程度进行自评。",
              source: "任务提醒", time: "2 小时前", symbol: "clock", action: "继续任务", kind: .task, unread: true),
        .init(id: "inbox-3", title: "雾港状态等待事件结算",
              summary: "12 个参与者提交可能改变地点开放状态。",
              detail: "事件结算只会生成影响预览，不会自动改写正式世界线。管理者确认后，地点状态、角色经历和相关 Wiki 条目才会更新。",
              source: "世界状态", time: "昨天", symbol: "mappin.and.ellipse", action: "查看地图", kind: .world, unread: false)
    ]
}

private struct MessagePath: View {
    var kind: AtlasInboxItem.Kind

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let points = [
                    CGPoint(x: size.width * 0.12, y: size.height * 0.50),
                    CGPoint(x: size.width * 0.38, y: size.height * 0.50),
                    CGPoint(x: size.width * 0.64, y: size.height * 0.50),
                    CGPoint(x: size.width * 0.88, y: size.height * 0.50)
                ]
                var path = Path()
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(.white.opacity(0.14)), lineWidth: 1)
                for (index, point) in points.enumerated() {
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)),
                        with: .color(.white.opacity(index <= 1 ? 0.9 : 0.16))
                    )
                }
            }

            let labels = labels
            ForEach(labels.indices, id: \.self) { index in
                Text(labels[index])
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
                    .position(
                        x: proxy.size.width * [0.12, 0.38, 0.64, 0.88][index],
                        y: proxy.size.height * 0.50 + 24
                    )
            }
        }
    }

    private var labels: [String] {
        switch kind {
        case .review: return ["申请", "共同确认", "候选变更", "正式关系"]
        case .task: return ["接取", "创作", "提交", "世界记录"]
        case .world: return ["参与回应", "影响预览", "管理确认", "状态更新"]
        }
    }
}
