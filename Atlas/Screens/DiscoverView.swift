import SwiftUI

struct DiscoverView: View {
    @ObservedObject var model: AtlasAppModel
    var onCreate: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebStarMapView { worldName in
                openWorld(named: worldName)
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
            .padding(.trailing, 28)
        }
        .background(Color(red: 0.012, green: 0.013, blue: 0.023))
    }

    private func openWorld(named name: String) {
        let normalizedName = name == "极光档案" ? "雾海来信" : name
        let world = model.worlds.first { $0.name == normalizedName } ?? model.worlds[0]
        model.openWorld(world)
    }
}
