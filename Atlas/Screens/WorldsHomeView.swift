import SwiftUI

struct WorldsHomeView: View {
    @ObservedObject var model: AtlasAppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AtlasColor.borderSubtle)
            HSplitView {
                worldList
                    .frame(minWidth: 410, idealWidth: 520)
                worldPulse
                    .frame(minWidth: 360)
            }
        }
        .background(AtlasCanvasBackground())
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text("我的世界")
                    .font(AtlasFont.title)
                Text("从草稿、正在运行的企划和历史档案继续工作")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
            }
            Spacer()
            Button {
                model.activeSheet = .createWorld
            } label: {
                AtlasButtonLabel(title: "创建世界", systemImage: "plus")
            }
            .buttonStyle(.atlas(.primary))
        }
        .padding(AtlasSpacing.xl)
    }

    private var worldList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.worlds) { world in
                    WorldRow(world: world, active: world.id == model.activeWorldID) {
                        model.openWorld(world, mode: .manage)
                    }
                    Divider().overlay(AtlasColor.borderSubtle)
                }
            }
        }
        .background(AtlasColor.canvas.opacity(0.38))
    }

    private var worldPulse: some View {
        let world = model.activeWorld

        return VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            HStack {
                Label("WORLD PULSE", systemImage: "waveform.path.ecg")
                    .font(AtlasFont.mono)
                    .foregroundStyle(AtlasColor.textTertiary)
                Spacer()
                Text("\(Int(world.progress * 100))% 可运行")
                    .font(AtlasFont.mono)
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                Circle()
                    .trim(from: 0, to: world.progress)
                    .stroke(Color.white, style: .init(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .stroke(Color.white.opacity(0.05), style: .init(lineWidth: 1, dash: [2, 8]))
                    .padding(26)
                VStack(spacing: AtlasSpacing.xs) {
                    Image(systemName: world.symbol)
                        .font(.system(size: 28, weight: .light))
                    Text(world.name)
                        .font(AtlasFont.heading)
                    Text(world.status)
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }
            .frame(maxWidth: 250, maxHeight: 250)
            .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                pulseRow("世界对象", value: "34", symbol: "circle.grid.cross")
                pulseRow("待确认", value: "08", symbol: "hourglass")
                pulseRow("开放任务", value: "07", symbol: "bolt.horizontal")
                pulseRow("本周贡献", value: "16", symbol: "arrow.up.right")
            }

            Spacer()

            HStack {
                Button {
                    model.openWorld(world, mode: .manage)
                } label: {
                    AtlasButtonLabel(title: "继续管理", systemImage: "arrow.right")
                }
                .buttonStyle(.atlas(.primary))

                Button {
                    model.accessMode = .publicPreview
                    model.destination = .publicPreview
                } label: {
                    Image(systemName: "eye")
                }
                .buttonStyle(.atlas(.glass))
                .help("公开预览")
            }
        }
        .padding(AtlasSpacing.xl)
    }

    private func pulseRow(_ title: String, value: String, symbol: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .frame(width: 20)
                .foregroundStyle(AtlasColor.textTertiary)
            Text(title)
                .font(AtlasFont.body)
            Spacer()
            Text(value)
                .font(AtlasFont.mono)
        }
        .padding(.vertical, AtlasSpacing.m)
        .overlay(alignment: .bottom) {
            Divider().overlay(AtlasColor.borderSubtle)
        }
    }
}

private struct WorldRow: View {
    var world: AtlasWorld
    var active: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AtlasSpacing.l) {
                Image(systemName: world.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(active ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: AtlasSpacing.s) {
                        Text(world.name)
                            .font(AtlasFont.heading)
                        Text(world.status)
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                    Text(world.hook)
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(world.members) 人")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                    ProgressView(value: world.progress)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(width: 72)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .padding(.horizontal, AtlasSpacing.xl)
            .padding(.vertical, AtlasSpacing.l)
            .background(hovering ? Color.white.opacity(0.035) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
