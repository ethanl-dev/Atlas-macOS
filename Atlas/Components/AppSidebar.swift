import SwiftUI

struct AtlasAppSidebar: View {
    @ObservedObject var model: AtlasAppModel

    private let globalItems: [AtlasDestination] = [.discover, .worlds, .inbox]
    private let projectItems: [AtlasDestination] = [
        .overview, .canvas, .wiki, .assets, .tasks, .review, .publicPreview
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            brand
            navigation
            Spacer(minLength: AtlasSpacing.l)
            activeProject
        }
        .padding(AtlasSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(AtlasColor.canvas.opacity(0.96))
        .background(AtlasCanvasBackground())
    }

    private var brand: some View {
        Button {
            model.destination = .discover
        } label: {
            HStack(spacing: AtlasSpacing.s) {
                AtlasMark()
                VStack(alignment: .leading, spacing: 0) {
                    Text("ATLAS")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(2)
                    Text("世界基础设施")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer()
            }
            .foregroundStyle(AtlasColor.textPrimary)
        }
        .buttonStyle(.plain)
        .padding(.top, AtlasSpacing.s)
    }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            SidebarGroup(title: "ATLAS") {
                ForEach(globalItems) { item in
                    SidebarDestinationButton(
                        item: item,
                        selected: model.destination == item
                    ) {
                        model.destination = item
                    }
                }
            }

            SidebarGroup(title: model.activeWorld.name.uppercased()) {
                ForEach(visibleProjectItems) { item in
                    SidebarDestinationButton(
                        item: item,
                        selected: model.destination == item,
                        badge: item == .review ? "\(model.submissions.filter { $0.state == .pending || $0.state == .shared }.count)" : nil
                    ) {
                        model.destination = item
                        if item == .publicPreview {
                            model.accessMode = .publicPreview
                        }
                    }
                }
            }
        }
    }

    private var visibleProjectItems: [AtlasDestination] {
        projectItems.filter { item in
            item != .review || model.accessMode == .manage
        }
    }

    private var activeProject: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            HStack(spacing: AtlasSpacing.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    Image(systemName: model.activeWorld.symbol)
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.activeWorld.name)
                        .font(AtlasFont.label)
                    Text("\(model.activeWorld.status) · \(model.activeWorld.members) 人")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer()
            }

            if model.accessMode != .publicPreview {
                HStack(spacing: AtlasSpacing.xs) {
                    ForEach([ProjectAccessMode.participate, .manage]) { mode in
                        Button {
                            withAnimation(.snappy(duration: 0.24)) {
                                model.switchMode(mode)
                            }
                        } label: {
                            Label(mode.rawValue, systemImage: mode.symbol)
                                .font(AtlasFont.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .foregroundStyle(model.accessMode == mode ? AtlasColor.inverse : AtlasColor.textSecondary)
                                .background {
                                    if model.accessMode == mode {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous).stroke(AtlasColor.borderSubtle))
            } else {
                Button {
                    model.switchMode(.manage)
                } label: {
                    Label("返回管理模式", systemImage: "arrow.uturn.backward")
                        .font(AtlasFont.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.atlas(.glass))
            }
        }
        .padding(AtlasSpacing.s)
        .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
    }
}

private struct SidebarGroup<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            Text(title)
                .font(AtlasFont.monoSmall)
                .foregroundStyle(AtlasColor.textTertiary)
                .padding(.horizontal, AtlasSpacing.s)
            content
        }
    }
}

private struct SidebarDestinationButton: View {
    var item: AtlasDestination
    var selected: Bool
    var badge: String?
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(item.rawValue)
                    .font(AtlasFont.label)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(AtlasFont.monoSmall)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
            }
            .foregroundStyle(selected ? AtlasColor.textPrimary : AtlasColor.textSecondary)
            .padding(.horizontal, AtlasSpacing.s)
            .padding(.vertical, AtlasSpacing.s - 1)
            .background {
                if selected {
                    Color.clear.atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous))
                } else if hovering {
                    RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct AtlasMark: View {
    var body: some View {
        Grid(horizontalSpacing: 2.5, verticalSpacing: 2.5) {
            GridRow { dot; dot }
            GridRow { dot; dot }
        }
        .padding(6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var dot: some View {
        Circle()
            .fill(AtlasColor.textPrimary)
            .frame(width: 5, height: 5)
    }
}
