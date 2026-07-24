import SwiftUI

struct WorldsHomeView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var hoveredWorldID: String?

    private var visibleWorlds: [AtlasWorld] {
        model.worlds.filter { world in
            switch model.worldCollection {
            case .managed: return model.role(in: world.id) == .owner
            case .joined: return model.role(in: world.id) == .participant
            }
        }
    }

    private var pulseWorld: AtlasWorld {
        if let hoveredWorldID,
           let hovered = visibleWorlds.first(where: { $0.id == hoveredWorldID }) {
            return hovered
        }
        if let active = visibleWorlds.first(where: { $0.id == model.activeWorldID }) {
            return active
        }
        return visibleWorlds.first ?? model.activeWorld
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AtlasColor.borderSubtle)
            GeometryReader { proxy in
                if proxy.size.width >= 820 {
                    HSplitView {
                        worldList
                            .frame(minWidth: 350, idealWidth: 500)
                        worldPulse
                            .frame(minWidth: 320)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            worldList
                                .frame(height: max(300, proxy.size.height * 0.52))
                            Divider().overlay(AtlasColor.borderSubtle)
                            worldPulse
                                .frame(minHeight: 500)
                        }
                    }
                }
            }
        }
        .background(AtlasCanvasBackground())
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text(model.worldCollection.rawValue)
                    .font(AtlasFont.title)
                Text(model.worldCollection == .managed
                     ? "你创建或负责管理的企划世界"
                     : "你以参企者身份加入的企划世界")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
            }
            Spacer()
            Button {
                withAnimation(.snappy(duration: 0.32)) { model.beginWorldCreation() }
            } label: {
                AtlasButtonLabel(title: "创建世界", systemImage: "plus")
            }
            .buttonStyle(.atlas(.primary))
        }
        .padding(AtlasSpacing.xl)
        // 右上角头像由 RootView 全局悬浮，给它预留独立空间。
        .padding(.trailing, 58)
    }

    private var worldList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(visibleWorlds) { world in
                    WorldRow(
                        world: world,
                        role: model.role(in: world.id),
                        active: world.id == pulseWorld.id,
                        onHover: { hovering in
                            withAnimation(.snappy(duration: 0.24)) {
                                hoveredWorldID = hovering ? world.id : nil
                            }
                        }
                    ) {
                        model.openWorld(world)
                    }
                    Divider().overlay(AtlasColor.borderSubtle)
                }
            }
        }
        .background(AtlasColor.canvas.opacity(0.38))
    }

    private var worldPulse: some View {
        let world = pulseWorld
        let ended = world.status == "已结企"

        return VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            HStack {
                Label("WORLD PULSE", systemImage: "waveform.path.ecg")
                    .font(AtlasFont.mono)
                    .foregroundStyle(AtlasColor.textTertiary)
                Spacer()
                Text(world.status)
                    .font(AtlasFont.mono)
                    .foregroundStyle(ended ? AtlasColor.auroraAmber : AtlasColor.auroraMint)
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                AtlasColor.auroraViolet.opacity(0.15),
                                ended ? AtlasColor.auroraAmber : AtlasColor.auroraMint,
                                AtlasColor.auroraRose.opacity(0.20)
                            ],
                            center: .center
                        ),
                        style: .init(lineWidth: 3, lineCap: .round, dash: [42, 18])
                    )
                    .rotationEffect(.degrees(hoveredWorldID == nil ? 0 : 16))
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
                .id(world.id)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
            .frame(maxWidth: 250, maxHeight: 250)
            .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                if ended {
                    pulseRow("开展过的活动数", value: archiveValue(world, base: 12), symbol: "calendar.badge.checkmark")
                    pulseRow("总参与数", value: "\(world.members)", symbol: "person.2")
                    pulseRow("收录作品", value: archiveValue(world, base: 86), symbol: "photo.on.rectangle.angled")
                    pulseRow("归档设定", value: archiveValue(world, base: 42), symbol: "archivebox")
                } else {
                    pulseRow("世界对象", value: liveValue(world, base: 28), symbol: "circle.grid.cross")
                    pulseRow("待确认", value: liveValue(world, base: 3), symbol: "hourglass")
                    pulseRow("开放任务", value: liveValue(world, base: 5), symbol: "bolt.horizontal")
                    pulseRow("本周贡献", value: liveValue(world, base: 9), symbol: "arrow.up.right")
                }
            }
            .id("\(world.id)-metrics")
            .transition(.move(edge: .trailing).combined(with: .opacity))

            Spacer()

            HStack {
                Button {
                    model.openWorld(world)
                } label: {
                    AtlasButtonLabel(title: entryTitle(for: world), systemImage: "arrow.right")
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

    private func liveValue(_ world: AtlasWorld, base: Int) -> String {
        let seed = world.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return "\(base + seed % max(2, base / 2))"
    }

    private func archiveValue(_ world: AtlasWorld, base: Int) -> String {
        let seed = world.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return "\(base + seed % max(3, base / 3))"
    }

    private func entryTitle(for world: AtlasWorld) -> String {
        switch model.role(in: world.id) {
        case .owner: return "继续管理"
        case .participant: return "继续参与"
        case .visitor: return "进入探索"
        }
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
    var role: ProjectRole
    var active: Bool
    var onHover: (Bool) -> Void
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
                        Label(role.rawValue, systemImage: role.symbol)
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.05), in: Capsule())
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
                    Text(world.status)
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(world.status == "已结企" ? AtlasColor.auroraAmber : AtlasColor.textSecondary)
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
        .onHover {
            hovering = $0
            onHover($0)
        }
    }
}
