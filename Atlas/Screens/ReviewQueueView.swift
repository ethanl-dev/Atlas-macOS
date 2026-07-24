import SwiftUI

struct ReviewQueueView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var selectedSubmissionID = "SUB-041"

    private var selectedSubmission: AtlasSubmission {
        model.submissions.first(where: { $0.id == selectedSubmissionID }) ?? model.submissions[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AtlasColor.borderSubtle)

            HSplitView {
                queue
                    .frame(minWidth: 270, idealWidth: 320, maxWidth: 380)
                reviewSurface
                    .frame(minWidth: 540)
            }
        }
        .background(AtlasCanvasBackground())
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text("审核队列")
                    .font(AtlasFont.title)
                Text("管理者确认世界事实、角色关系和作品归档去向")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
            }
            Spacer()
            Text("\(model.submissions.filter { $0.state == .pending || $0.state == .shared }.count) 待处理")
                .font(AtlasFont.mono)
                .foregroundStyle(AtlasColor.textSecondary)
        }
        .padding(AtlasSpacing.xl)
    }

    private var queue: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.submissions) { submission in
                    Button {
                        selectedSubmissionID = submission.id
                    } label: {
                        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                            HStack {
                                Text(submission.id)
                                    .font(AtlasFont.monoSmall)
                                    .foregroundStyle(AtlasColor.textTertiary)
                                Spacer()
                                Text(submission.state.rawValue)
                                    .font(AtlasFont.monoSmall)
                                    .foregroundStyle(AtlasColor.textSecondary)
                            }
                            Text(submission.title)
                                .font(AtlasFont.label)
                                .multilineTextAlignment(.leading)
                            HStack {
                                Text(submission.author)
                                Text("→")
                                Text(submission.destination)
                            }
                            .font(AtlasFont.caption)
                            .foregroundStyle(AtlasColor.textTertiary)
                        }
                        .foregroundStyle(AtlasColor.textPrimary)
                        .padding(AtlasSpacing.l)
                        .background(selectedSubmissionID == submission.id ? Color.white.opacity(0.065) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(AtlasColor.borderSubtle)
                }
            }
        }
        .background(AtlasColor.canvas.opacity(0.54))
    }

    private var reviewSurface: some View {
        let submission = selectedSubmission

        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(submission.title)
                        .font(AtlasFont.heading)
                    Text("\(submission.author) · \(submission.destination)")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer()
                Label(submission.state.rawValue, systemImage: statusSymbol(submission.state))
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
            }
            .padding(AtlasSpacing.xl)

            Divider().overlay(AtlasColor.borderSubtle)

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    submittedContent
                        .frame(width: proxy.size.width * 0.50)
                    Divider().overlay(AtlasColor.borderSubtle)
                    impactPreview(submission)
                }
            }

            Divider().overlay(AtlasColor.borderSubtle)

            actions(submission)
                .padding(AtlasSpacing.l)
        }
    }

    private var submittedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                Text("提交内容")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)

                Text("在第七页航海日志的背面，岑找到了一段被潮水浸没的坐标。她没有立刻公开，而是把坐标交给伊莱，要求对方用旧式航图复核。")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AtlasColor.textSecondary)
                    .lineSpacing(7)
                    .textSelection(.enabled)

                SubmissionTrace()
                    .frame(height: 210)

                VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                    Text("授权与来源")
                        .font(AtlasFont.heading)
                    Label("原创文字，允许企划内归档", systemImage: "checkmark")
                    Label("未使用图片生成或画风模仿", systemImage: "checkmark")
                    Label("自评分：5 分", systemImage: "gauge.with.dots.needle.50percent")
                }
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textSecondary)
            }
            .padding(AtlasSpacing.xl)
        }
    }

    private func impactPreview(_ submission: AtlasSubmission) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            HStack {
                Text("影响预览")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
                Spacer()
                Button {
                    model.showToast("未发现与正式设定的直接冲突")
                } label: {
                    Label("查冲突", systemImage: "point.3.filled.connected.trianglepath.dotted")
                        .font(AtlasFont.caption)
                }
                .buttonStyle(.plain)
            }

            ReviewImpactGraph(objects: submission.affectedObjects)
                .frame(height: 190)

            VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                Text("建议去向")
                    .font(AtlasFont.heading)

                impactLine("坐标存在", destination: "白塔 Wiki", canApply: true)
                impactLine("岑交付坐标", destination: "角色时间线", canApply: true)
                impactLine("雾港解除封锁", destination: "等待事件结算", canApply: false)
            }

            Divider().overlay(AtlasColor.borderSubtle)

            Text("涉及世界事实或双方关系时，提交不会直接写入正式档案。采纳后先成为候选变更，再由管理者发布。")
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(AtlasSpacing.xl)
        .background(AtlasColor.canvas.opacity(0.30))
    }

    private func actions(_ submission: AtlasSubmission) -> some View {
        HStack {
            Button {
                model.review(submission.id, result: .revision)
            } label: {
                AtlasButtonLabel(title: "退回修改", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.atlas(.ghost))

            Spacer()

            Button {
                model.review(submission.id, result: .accepted)
                model.showToast("已归入角色作品集")
            } label: {
                AtlasButtonLabel(title: "仅入作品集", systemImage: "person.crop.rectangle.stack")
            }
            .buttonStyle(.atlas(.glass))

            Button {
                model.review(submission.id, result: .accepted)
            } label: {
                AtlasButtonLabel(title: "采纳到 Wiki 候选", systemImage: "checkmark")
            }
            .buttonStyle(.atlas(.primary))
        }
    }

    private func impactLine(_ title: String, destination: String, canApply: Bool) -> some View {
        HStack(spacing: AtlasSpacing.s) {
            Image(systemName: canApply ? "plus.circle" : "pause.circle")
                .foregroundStyle(canApply ? AtlasColor.textPrimary : AtlasColor.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AtlasFont.body)
                Text(destination)
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusSymbol(_ state: AtlasSubmission.State) -> String {
        switch state {
        case .pending: return "hourglass"
        case .shared: return "person.2"
        case .revision: return "arrow.uturn.backward"
        case .accepted: return "checkmark.seal"
        }
    }
}

private struct SubmissionTrace: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AtlasRadius.card)
                .fill(Color.white.opacity(0.025))

            Canvas { context, size in
                let points = [
                    CGPoint(x: size.width * 0.18, y: size.height * 0.66),
                    CGPoint(x: size.width * 0.42, y: size.height * 0.34),
                    CGPoint(x: size.width * 0.68, y: size.height * 0.52),
                    CGPoint(x: size.width * 0.84, y: size.height * 0.24)
                ]

                var path = Path()
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(.white.opacity(0.24)), style: .init(lineWidth: 1, dash: [4, 5]))

                for (index, point) in points.enumerated() {
                    let radius: CGFloat = index == 2 ? 8 : 5
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white.opacity(index == 2 ? 0.95 : 0.5))
                    )
                }
            }

            Text("航海坐标片段")
                .font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textTertiary)
                .padding(AtlasSpacing.s)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.card).stroke(AtlasColor.borderSubtle))
    }
}

private struct ReviewImpactGraph: View {
    var objects: [String]

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.36
                for index in objects.indices {
                    let angle = CGFloat(index) / CGFloat(max(objects.count, 1)) * .pi * 2 - .pi / 2
                    let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    var line = Path()
                    line.move(to: center)
                    line.addLine(to: point)
                    context.stroke(line, with: .color(.white.opacity(0.14)), lineWidth: 1)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(.white.opacity(0.65)))
                }
                context.fill(Path(ellipseIn: CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18)), with: .color(.white))
            }

            ForEach(Array(objects.enumerated()), id: \.offset) { index, object in
                let angle = CGFloat(index) / CGFloat(max(objects.count, 1)) * .pi * 2 - .pi / 2
                Text(object)
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .position(
                        x: proxy.size.width / 2 + cos(angle) * min(proxy.size.width, proxy.size.height) * 0.36,
                        y: proxy.size.height / 2 + sin(angle) * min(proxy.size.width, proxy.size.height) * 0.36 + 18
                    )
            }
        }
    }
}
