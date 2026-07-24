import SwiftUI

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 600
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}

struct CharacterCardSheet: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.dismiss) private var dismiss

    private var character: AtlasCharacterProfile {
        AtlasCharacterProfile.samples.first(where: { $0.id == model.selectedCharacterID }) ?? AtlasCharacterProfile.samples[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                    CharacterPortrait(seed: abs(character.id.hashValue % 9), initials: String(character.name.prefix(1)))
                        .frame(width: 220, height: 300)
                    VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(character.name).font(AtlasFont.display)
                                Text("\(character.owner) · \(character.role)")
                                    .font(AtlasFont.monoSmall)
                                    .foregroundStyle(AtlasColor.textTertiary)
                            }
                            Spacer()
                            Button { dismiss() } label: { Image(systemName: "xmark") }
                                .buttonStyle(.atlas(.glass))
                        }
                        Text(character.summary)
                            .font(AtlasFont.body)
                            .foregroundStyle(AtlasColor.textSecondary)
                            .lineSpacing(5)
                        Label(character.location, systemImage: "mappin")
                        Label(character.organization, systemImage: "person.3")
                    }
                }

                HStack(alignment: .top, spacing: AtlasSpacing.m) {
                    permissionList("适合互动", items: character.dos, tint: AtlasColor.auroraMint, symbol: "checkmark")
                    permissionList("不可触碰", items: character.donts, tint: AtlasColor.auroraRose, symbol: "xmark")
                }

                VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                    Text("全局创作许可").font(AtlasFont.heading)
                    FlowLayout(spacing: AtlasSpacing.s) {
                        ForEach(character.permissions) { permission in
                            Label("\(permission.title) · \(permission.state.rawValue)", systemImage: permissionSymbol(permission.state))
                                .font(AtlasFont.caption)
                                .padding(.horizontal, AtlasSpacing.s)
                                .padding(.vertical, 7)
                                .atlasChromaticGlass(Capsule(), tint: permissionTint(permission.state))
                        }
                    }
                }

                HStack {
                    Text("发起互动后，涉及永久关系、关键立场或不可逆经历时，会进入角色拥有者确认。")
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textTertiary)
                    Spacer()
                    if model.activeRole == .participant && model.canWriteActiveWorld {
                        Button {
                            model.activeSheet = .interactionInvite
                        } label: {
                            AtlasButtonLabel(title: "发起互动", systemImage: "arrowshape.turn.up.right")
                        }
                        .buttonStyle(.atlas(.primary))
                    }
                }
            }
            .padding(AtlasSpacing.xxl)
        }
        .frame(minWidth: 760, minHeight: 680)
        .background(AtlasCanvasBackground())
    }

    private func permissionList(_ title: String, items: [String], tint: Color, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            Text(title).font(AtlasFont.heading).foregroundStyle(tint)
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: symbol)
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.l)
        .atlasChromaticGlass(RoundedRectangle(cornerRadius: AtlasRadius.card), tint: tint)
    }

    private func permissionSymbol(_ state: AtlasCharacterProfile.Permission.State) -> String {
        switch state { case .allowed: "checkmark"; case .confirm: "questionmark"; case .forbidden: "xmark" }
    }

    private func permissionTint(_ state: AtlasCharacterProfile.Permission.State) -> Color {
        switch state { case .allowed: AtlasColor.auroraMint; case .confirm: AtlasColor.auroraAmber; case .forbidden: AtlasColor.auroraRose }
    }
}

struct InteractionInviteSheet: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var venueID = InteractionVenue.samples[0].id
    @State private var premise = ""
    @State private var hook = ""
    @State private var requiresConfirmation = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("发起角色互动").font(AtlasFont.heading)
                    Text("明确场景、行动和留给对方的可回应点")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
            }
            .padding(AtlasSpacing.l)
            Divider().overlay(AtlasColor.borderSubtle)

            VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                Picker("互动地点", selection: $venueID) {
                    ForEach(InteractionVenue.samples) { Text($0.name).tag($0.id) }
                }
                TextField("互动前提：你的角色正在做什么？", text: $premise)
                TextField("可回应点：对方可以如何加入？", text: $hook)
                Toggle("涉及关系或关键经历，提交给角色拥有者确认", isOn: $requiresConfirmation)
                    .toggleStyle(.switch)
                Label("发起邀请不会自动替对方角色作出选择。", systemImage: "checkmark.shield")
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .textFieldStyle(.plain)
            .padding(AtlasSpacing.xl)
            .frame(maxHeight: .infinity)

            Divider().overlay(AtlasColor.borderSubtle)
            HStack {
                Spacer()
                Button {
                    model.showToast(requiresConfirmation ? "互动邀请已发送，等待角色拥有者确认" : "互动邀请已发布")
                    dismiss()
                } label: {
                    AtlasButtonLabel(title: "发送邀请", systemImage: "paperplane")
                }
                .buttonStyle(.atlas(.primary))
                .disabled(premise.isEmpty || hook.isEmpty)
            }
            .padding(AtlasSpacing.l)
        }
        .frame(width: 620, height: 450)
        .background(AtlasCanvasBackground())
    }
}
