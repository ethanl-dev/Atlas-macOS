import SwiftUI

struct ProjectOverviewView: View {
    @ObservedObject var model: AtlasAppModel

    var body: some View {
        VStack(spacing: 0) {
            projectHeader
            Divider().overlay(AtlasColor.borderSubtle)

            GeometryReader { proxy in
                if proxy.size.width >= 840 {
                    HStack(spacing: 0) {
                        worldState
                            .frame(width: proxy.size.width * 0.58)
                        Divider().overlay(AtlasColor.borderSubtle)
                        activityRail
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            worldState
                                .frame(height: max(430, proxy.size.height * 0.62))
                            Divider().overlay(AtlasColor.borderSubtle)
                            activityRail
                                .frame(minHeight: 440)
                        }
                    }
                }
            }
        }
        .background(AtlasCanvasBackground())
    }

    private var projectHeader: some View {
        ViewThatFits(in: .horizontal) {
            projectHeaderContent
            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                projectIdentity
                HStack { Spacer(); projectActions }
            }
        }
        .padding(AtlasSpacing.xl)
    }

    private var projectHeaderContent: some View {
        HStack(alignment: .center, spacing: AtlasSpacing.l) {
            projectIdentity
            Spacer()
            projectActions
        }
    }

    private var projectIdentity: some View {
        HStack(alignment: .center, spacing: AtlasSpacing.l) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                Image(systemName: model.activeWorld.symbol)
                    .font(.system(size: 22, weight: .light))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AtlasSpacing.s) {
                    Text(model.activeWorld.name)
                        .font(AtlasFont.title)
                    Label(model.activeRole.rawValue, systemImage: model.activeRole.symbol)
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(AtlasColor.borderSubtle))
                }
                Text(model.activeWorld.hook)
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
            }
        }
    }

    private var projectActions: some View {
        HStack(spacing: AtlasSpacing.s) {
            if model.accessMode == .manage && model.canWriteActiveWorld {
                Button {
                    model.activeSheet = .publish
                } label: {
                    AtlasButtonLabel(title: "发布检查", systemImage: "checkmark.circle")
                }
                .buttonStyle(.atlas(.glass))
            }

            if model.activeRole == .owner && model.canWriteActiveWorld {
                Button {
                    model.navigate(to: .canvas)
                } label: {
                    AtlasButtonLabel(title: "编辑世界地图", systemImage: "arrow.right")
                }
                .buttonStyle(.atlas(.primary))
            }
        }
    }

    private var worldState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    Text("CURRENT WORLD STATE")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                    Text("潮汐回响 · 第二阶段")
                        .font(AtlasFont.heading)
                }
                Spacer()
                Text("LIVE")
                    .font(AtlasFont.monoSmall)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Capsule().stroke(AtlasColor.borderDefault))
            }
            .padding(AtlasSpacing.xl)

            ZStack {
                WorldStateGraph()

                VStack {
                    Spacer()
                    HStack {
                        stateLegend("地点", symbol: "mappin")
                        stateLegend("角色", symbol: "person")
                        stateLegend("事件", symbol: "bolt")
                        Spacer()
                        if model.activeRole == .owner {
                            Button {
                                model.navigate(to: .canvas)
                            } label: {
                                Label("编辑地图", systemImage: "arrow.up.right")
                                    .font(AtlasFont.caption)
                            }
                            .buttonStyle(.atlas(.glass))
                        }
                    }
                    .padding(AtlasSpacing.l)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(AtlasColor.borderSubtle)

            HStack(spacing: 0) {
                metric("活跃角色", value: "24")
                metric("开放任务", value: "07")
                metric("待处理", value: model.accessMode == .manage ? "08" : "02")
                metric("Wiki 变更", value: "36")
            }
            .frame(height: 88)
        }
    }

    private var activityRail: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            HStack {
                Text(model.accessMode == .manage ? "运营脉冲" : "我的参与")
                    .font(AtlasFont.heading)
                Spacer()
                Button {
                    model.destination = .inbox
                } label: {
                    Image(systemName: "tray")
                }
                .buttonStyle(.plain)
                .help("打开收件箱")
            }

            if model.accessMode == .manage {
                readinessRail
            } else {
                participantRail
            }

            Spacer()

            Text("最近变化")
                .font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textTertiary)

            TimelineRow(symbol: "plus", title: "白昼提交了新角色", meta: "昨天 21:34")
            TimelineRow(symbol: "arrow.triangle.branch", title: "雾港状态等待结算", meta: "2 小时前")
            TimelineRow(symbol: "checkmark", title: "AI 使用边界已锁定", meta: "今天 08:12")
        }
        .padding(AtlasSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(AtlasColor.canvas.opacity(0.30))
    }

    private var readinessRail: some View {
        VStack(spacing: AtlasSpacing.s) {
            operationRow("审核申请", count: "3", destination: .review)
            operationRow("提交待处理", count: "8", destination: .review)
            operationRow("事件待结算", count: "2", destination: .tasks)
            operationRow("公开页缺口", count: "1", destination: .publicPreview)
        }
    }

    private var participantRail: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            HStack(spacing: AtlasSpacing.m) {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 48, height: 48)
                    .overlay(Text("岑").font(AtlasFont.heading))
                VStack(alignment: .leading, spacing: 2) {
                    Text("岑 · 档案修复师")
                        .font(AtlasFont.label)
                    Text("当前位于雾港")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }

            Divider().overlay(AtlasColor.borderSubtle)

            operationRow("继续夜航守望", count: "48h", destination: .tasks)
            operationRow("关系待确认", count: "2", destination: .tasks)
            operationRow("收件箱", count: "1", destination: .inbox)
        }
    }

    private func operationRow(_ title: String, count: String, destination: AtlasDestination) -> some View {
        Button {
            model.destination = destination
        } label: {
            HStack {
                Text(title)
                    .font(AtlasFont.body)
                Spacer()
                Text(count)
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .padding(.vertical, AtlasSpacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider().overlay(AtlasColor.borderSubtle)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 21, weight: .semibold, design: .monospaced))
            Text(title)
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AtlasSpacing.l)
        .overlay(alignment: .trailing) {
            Divider().overlay(AtlasColor.borderSubtle)
        }
    }

    private func stateLegend(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(AtlasFont.caption)
            .foregroundStyle(AtlasColor.textSecondary)
    }
}

private struct WorldStateGraph: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let points = [
                    CGPoint(x: size.width * 0.22, y: size.height * 0.35),
                    CGPoint(x: size.width * 0.50, y: size.height * 0.20),
                    CGPoint(x: size.width * 0.73, y: size.height * 0.38),
                    CGPoint(x: size.width * 0.62, y: size.height * 0.68),
                    CGPoint(x: size.width * 0.32, y: size.height * 0.70)
                ]

                let edges = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0), (1, 3), (0, 3)]
                for edge in edges {
                    var path = Path()
                    path.move(to: points[edge.0])
                    path.addLine(to: points[edge.1])
                    context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 1)
                }

                for (index, point) in points.enumerated() {
                    let radius: CGFloat = index == 1 ? 12 : 7
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white.opacity(index == 1 ? 0.95 : 0.58))
                    )
                }
            }

            Text("夜航守望")
                .font(AtlasFont.label)
                .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.20 + 28)
            Text("雾港")
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textSecondary)
                .position(x: proxy.size.width * 0.22, y: proxy.size.height * 0.35 + 22)
            Text("白塔")
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textSecondary)
                .position(x: proxy.size.width * 0.73, y: proxy.size.height * 0.38 + 22)
        }
    }
}

private struct TimelineRow: View {
    var symbol: String
    var title: String
    var meta: String

    var body: some View {
        HStack(alignment: .top, spacing: AtlasSpacing.s) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.06), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AtlasFont.caption)
                Text(meta)
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
        }
    }
}
