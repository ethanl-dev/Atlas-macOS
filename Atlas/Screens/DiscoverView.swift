import SwiftUI

struct DiscoverView: View {
    @ObservedObject var model: AtlasAppModel
    var onCreate: () -> Void
    @State private var departureProgress: CGFloat = 0
    @State private var departingWorld: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebStarMapView { worldName in
                beginDeparture(to: worldName)
            }
            .ignoresSafeArea()

            Button(action: onCreate) {
                Label("创建世界", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 15)
                    .frame(height: 34)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .atlasP1Glass(Capsule(), interactive: true)
            .padding(.top, 42)
            .padding(.trailing, 82)

            if let departingWorld {
                departureOverlay(worldName: departingWorld)
                    .transition(.opacity)
                    .allowsHitTesting(true)
            }
        }
        .background(Color(red: 0.012, green: 0.013, blue: 0.023))
    }

    private func beginDeparture(to worldName: String) {
        guard departingWorld == nil else { return }
        departingWorld = worldName
        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
            departureProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            withAnimation(.easeInOut(duration: 0.42)) {
                openWorld(named: worldName)
            }
        }
    }

    private func departureOverlay(worldName: String) -> some View {
        ZStack {
            Color.black
                .opacity(0.12 + departureProgress * 0.68)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AtlasColor.auroraBlue.opacity(0.52),
                            AtlasColor.auroraViolet.opacity(0.24),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 310
                    )
                )
                .frame(width: 620, height: 620)
                .scaleEffect(0.18 + departureProgress * 1.65)
                .blur(radius: 18 + departureProgress * 34)
                .blendMode(.plusLighter)

            VStack(spacing: AtlasSpacing.s) {
                Text("正在进入")
                    .font(AtlasFont.monoSmall)
                    .tracking(2.4)
                    .foregroundStyle(AtlasColor.textTertiary)
                Text(worldName)
                    .font(AtlasFont.serifTitle)
                    .foregroundStyle(AtlasColor.textPrimary)
            }
            .opacity(departureProgress)
            .scaleEffect(0.94 + departureProgress * 0.06)
        }
        .ignoresSafeArea()
    }

    private func openWorld(named name: String) {
        let normalizedName = name == "极光档案" ? "雾海来信" : name
        let world = model.worlds.first { $0.name == normalizedName } ?? model.worlds[0]
        model.openWorld(world)
    }
}
