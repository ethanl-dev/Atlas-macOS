import SwiftUI

/// 星图不显示品牌字标，但保留与完整 Dock 相同的 7pt 内边距，
/// 因而头像在所有页面拥有完全一致的屏幕坐标。
struct ProfileAvatarDock: View {
    @ObservedObject var model: AtlasAppModel

    var body: some View {
        AtlasProfileMenu(model: model)
            .padding(7)
    }
}

struct ProfileBrandDock: View {
    @ObservedObject var model: AtlasAppModel

    var body: some View {
        HStack(alignment: .bottom, spacing: AtlasSpacing.s) {
            AtlasProfileMenu(model: model)
            ProjectAtlasBrand(model: model)
        }
        .padding(7)
        .atlasGlass(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
    }
}

struct ProjectAtlasBrand: View {
    @ObservedObject var model: AtlasAppModel

    var body: some View {
        Button {
            model.destination = .discover
        } label: {
            Image("AtlasWordmark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(AtlasColor.textPrimary)
                .frame(width: 82, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("返回 ATLAS 星图")
    }
}

struct ProjectQuickMenu: View {
    @ObservedObject var model: AtlasAppModel
    @State private var expanded = false
    @State private var hovering = false

    private var items: [AtlasDestination] {
        var result: [AtlasDestination] = [.publicPreview, .canvas, .wiki, .assets, .tasks]
        if model.activeRole == .owner {
            result.append(.review)
        }
        return result.filter { $0 != model.destination }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if expanded {
                ForEach(Array(items.enumerated()).reversed(), id: \.element.id) { index, item in
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                            model.navigate(to: item)
                            expanded = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(menuTitle(item))
                                .font(AtlasFont.label)
                            Image(systemName: item.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.10), in: Circle())
                                .foregroundStyle(.white)
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 7)
                        .padding(.vertical, 6)
                        .atlasGlass(Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.82, anchor: .bottomTrailing)),
                            removal: .opacity.combined(with: .scale(scale: 0.86, anchor: .bottomTrailing))
                        )
                    )
                    .animation(.spring(response: 0.34, dampingFraction: 0.76).delay(Double(index) * 0.035), value: expanded)
                }
            }

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    expanded.toggle()
                }
            } label: {
                Image(systemName: expanded ? "xmark" : "square.grid.2x2")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AtlasColor.textPrimary)
                    .frame(width: 52, height: 52)
                    .atlasChromaticGlass(
                        Circle(),
                        tint: expanded ? AtlasColor.auroraViolet : AtlasColor.auroraMint.opacity(0.75)
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.24)))
                    .shadow(color: AtlasColor.auroraViolet.opacity(expanded ? 0.38 : 0.20), radius: 20, y: 8)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .scaleEffect(hovering ? 1.08 : 1)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.28, dampingFraction: 0.66), value: hovering)
            .help(expanded ? "收起项目菜单" : "打开项目菜单")
        }
    }

    private func menuTint(_ item: AtlasDestination) -> Color {
        switch item {
        case .publicPreview: AtlasColor.textPrimary
        case .canvas: AtlasColor.auroraMint
        case .wiki: AtlasColor.auroraMint
        case .assets: AtlasColor.auroraViolet
        case .tasks: AtlasColor.auroraAmber
        case .review: AtlasColor.auroraRose
        default: AtlasColor.textPrimary
        }
    }

    private func menuTitle(_ item: AtlasDestination) -> String {
        switch item {
        case .publicPreview: "回到详情"
        case .canvas: "画布"
        default: item.rawValue
        }
    }
}

struct WorldCanvasPlaceholderView: View {
    @ObservedObject var model: AtlasAppModel

    var body: some View {
        ZStack {
            AtlasCanvasBackground()
            VStack(spacing: AtlasSpacing.m) {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(AtlasColor.textTertiary)
                Text("WORLD CANVAS")
                    .font(AtlasFont.mono)
                    .foregroundStyle(AtlasColor.textSecondary)
                Text("地图与世界画布暂时留白")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
                Button {
                    model.destination = .publicPreview
                } label: {
                    AtlasButtonLabel(title: "返回企划首页", systemImage: "arrow.left")
                }
                .buttonStyle(.atlas(.glass))
            }
        }
    }
}
