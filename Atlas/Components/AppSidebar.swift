import SwiftUI

struct AtlasAppSidebar: View {
    @ObservedObject var model: AtlasAppModel

    private let projectItems: [AtlasDestination] = [
        .overview, .canvas, .wiki, .assets, .tasks, .review, .publicPreview
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            brand
            navigation
            Spacer(minLength: AtlasSpacing.l)
            activeProject
            Divider().overlay(AtlasColor.borderSubtle)
            accountEntry
        }
        .padding(AtlasSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.70))
        .background(AtlasCanvasBackground())
    }

    private var accountEntry: some View {
        HStack(spacing: AtlasSpacing.s) {
            AtlasProfileMenu(model: model)
            VStack(alignment: .leading, spacing: 1) {
                Text("岑")
                    .font(AtlasFont.label)
                Text("账号与世界")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, AtlasSpacing.s)
        .padding(.top, 2)
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
        SidebarGroup(title: model.activeWorld.name.uppercased()) {
            ForEach(visibleProjectItems) { item in
                SidebarDestinationButton(
                    item: item,
                    title: sidebarTitle(for: item),
                    selected: model.destination == item,
                    badge: item == .review ? "\(model.submissions.filter { $0.state == .pending || $0.state == .shared }.count)" : nil
                ) {
                    model.navigate(to: item)
                }
            }
        }
    }

    private var visibleProjectItems: [AtlasDestination] {
        projectItems.filter { item in
            switch model.activeRole {
            case .owner:
                return true
            case .participant:
                return item != .review
            case .visitor:
                return item == .publicPreview ||
                    item == .canvas ||
                    item == .wiki ||
                    item == .assets ||
                    item == .tasks
            }
        }
    }

    private func sidebarTitle(for item: AtlasDestination) -> String {
        if item == .publicPreview && model.activeRole == .visitor {
            return "企划详情"
        }
        return item.rawValue
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

            Label(model.activeRole.rawValue, systemImage: model.activeRole.symbol)
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .atlasChromaticGlass(Capsule(), tint: roleTint)
        }
        .padding(AtlasSpacing.s)
        .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
    }

    private var roleTint: Color {
        switch model.activeRole {
        case .owner: return AtlasColor.auroraAmber
        case .participant: return AtlasColor.auroraMint
        case .visitor: return AtlasColor.auroraViolet
        }
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
    var title: String
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
                Text(title)
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
