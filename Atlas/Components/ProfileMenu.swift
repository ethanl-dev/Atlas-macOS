import SwiftUI

struct AtlasProfileMenu: View {
    @ObservedObject var model: AtlasAppModel
    @State private var presented = false
    @State private var profileRowHovered = false

    var body: some View {
        Button {
            presented.toggle()
        } label: {
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .overlay(Circle().stroke(Color.white.opacity(0.46), lineWidth: 1))
            .shadow(color: AtlasColor.auroraViolet.opacity(0.28), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .help("打开个人主页")
        .popover(isPresented: $presented, arrowEdge: .top) {
            profilePanel
        }
    }

    private var profilePanel: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            Button {
                withAnimation(.snappy(duration: 0.32)) {
                    model.navigate(to: .profile)
                }
                presented = false
            } label: {
                HStack(spacing: AtlasSpacing.m) {
                    avatar
                    VStack(alignment: .leading, spacing: 2) {
                        Text("岑")
                            .font(AtlasFont.heading)
                        Text("@cen · 查看个人主页")
                            .font(AtlasFont.caption)
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                .padding(AtlasSpacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.white.opacity(profileRowHovered ? 0.08 : 0.025),
                    in: RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.16)) {
                    profileRowHovered = hovering
                }
            }

            Divider().overlay(AtlasColor.borderSubtle)

            profileLink("我管理的世界", symbol: "crown", tint: AtlasColor.auroraAmber) {
                model.showWorldCollection(.managed)
            }

            profileLink("我加入的世界", symbol: "person.2", tint: AtlasColor.auroraMint) {
                model.showWorldCollection(.joined)
            }

            profileLink("收件箱", symbol: "tray", tint: AtlasColor.auroraViolet, badge: "3") {
                model.navigate(to: .inbox)
            }
        }
        .padding(AtlasSpacing.l)
        .frame(width: 280)
        .background(AtlasCanvasBackground())
    }

    private var avatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [AtlasColor.auroraRose, AtlasColor.auroraViolet],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 44, height: 44)
            .overlay(Text("岑").font(AtlasFont.label).foregroundStyle(.white))
    }

    private func profileLink(
        _ title: String,
        symbol: String,
        tint: Color,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            presented = false
        } label: {
            HStack(spacing: AtlasSpacing.m) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(AtlasFont.label)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(AtlasFont.monoSmall)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(tint.opacity(0.16), in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
