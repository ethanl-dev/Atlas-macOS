import SwiftUI

struct ProfileView: View {
    @ObservedObject var model: AtlasAppModel

    private var managedWorlds: [AtlasWorld] {
        model.worlds.filter { model.role(in: $0.id) == .owner }
    }

    private var joinedWorlds: [AtlasWorld] {
        model.worlds.filter { model.role(in: $0.id) == .participant }
    }

    var body: some View {
        ZStack {
            AtlasCanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                    identity
                    metrics
                    worldSections
                }
                .frame(maxWidth: 1080)
                .padding(.horizontal, AtlasSpacing.xxxl)
                .padding(.top, AtlasSpacing.xxxl)
                .padding(.bottom, 110)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var identity: some View {
        HStack(alignment: .center, spacing: AtlasSpacing.xl) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AtlasColor.auroraRose, AtlasColor.auroraViolet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("岑")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 88, height: 88)
            .overlay(Circle().stroke(Color.white.opacity(0.42), lineWidth: 1))
            .shadow(color: AtlasColor.auroraViolet.opacity(0.30), radius: 28, y: 10)

            VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                HStack(spacing: AtlasSpacing.m) {
                    Text("岑")
                        .font(AtlasFont.display)
                    Text("@cen")
                        .font(AtlasFont.mono)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                Text("世界观创作者 · 角色与叙事设计")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
                Text("在尚未命名的海岸线上，替故事留下可以被找到的坐标。")
                    .font(AtlasFont.serifBody)
                    .foregroundStyle(AtlasColor.textPrimary.opacity(0.86))
            }

            Spacer()

            Button {
                model.showToast("个人资料编辑将在下一步接入")
            } label: {
                AtlasButtonLabel(title: "编辑资料", systemImage: "pencil")
            }
            .buttonStyle(.atlas(.glass))
        }
        .padding(AtlasSpacing.xl)
        .atlasGlass(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        }
    }

    private var metrics: some View {
        HStack(spacing: AtlasSpacing.m) {
            metric("管理世界", value: "\(managedWorlds.count)", tint: AtlasColor.auroraAmber)
            metric("加入世界", value: "\(joinedWorlds.count)", tint: AtlasColor.auroraMint)
            metric("创作记录", value: "18", tint: AtlasColor.auroraViolet)
            metric("共同关系", value: "06", tint: AtlasColor.auroraRose)
        }
    }

    private var worldSections: some View {
        HStack(alignment: .top, spacing: AtlasSpacing.l) {
            worldPanel(
                title: "我管理的世界",
                subtitle: "以企主身份维护的企划",
                worlds: managedWorlds,
                tint: AtlasColor.auroraAmber,
                collection: .managed
            )
            worldPanel(
                title: "我加入的世界",
                subtitle: "正在参与创作的企划",
                worlds: joinedWorlds,
                tint: AtlasColor.auroraMint,
                collection: .joined
            )
        }
    }

    private func metric(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
            Text(title)
                .font(AtlasFont.label)
                .foregroundStyle(AtlasColor.textSecondary)
        }
        .padding(AtlasSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: AtlasRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: AtlasRadius.card)
                .stroke(tint.opacity(0.20), lineWidth: 1)
        }
    }

    private func worldPanel(
        title: String,
        subtitle: String,
        worlds: [AtlasWorld],
        tint: Color,
        collection: WorldCollection
    ) -> some View {
        GlassPanel(title: title, subtitle: subtitle) {
            VStack(spacing: 0) {
                ForEach(worlds.prefix(3)) { world in
                    Button {
                        model.openWorld(world)
                    } label: {
                        HStack(spacing: AtlasSpacing.m) {
                            Image(systemName: world.symbol)
                                .foregroundStyle(tint)
                                .frame(width: 34, height: 34)
                                .background(tint.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(world.name).font(AtlasFont.label)
                                Text(world.status)
                                    .font(AtlasFont.monoSmall)
                                    .foregroundStyle(AtlasColor.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AtlasColor.textTertiary)
                        }
                        .padding(.vertical, AtlasSpacing.m)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if world.id != worlds.prefix(3).last?.id {
                        Divider().overlay(AtlasColor.borderSubtle)
                    }
                }

                Button {
                    model.showWorldCollection(collection)
                } label: {
                    HStack {
                        Text("查看全部")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(AtlasFont.label)
                    .foregroundStyle(tint)
                    .padding(.top, AtlasSpacing.m)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
