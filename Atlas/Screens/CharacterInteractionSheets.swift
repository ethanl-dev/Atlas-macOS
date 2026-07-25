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

    private var character: AtlasCharacterProfile {
        AtlasCharacterProfile.samples.first(where: { $0.id == model.selectedCharacterID }) ?? AtlasCharacterProfile.samples[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                CharacterPortraitBanner(
                    character: character
                )

                VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                    Text(character.name).font(AtlasFont.display)
                    Text("\(character.owner) · \(character.role)")
                        .font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                    Text(character.summary)
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineSpacing(5)
                    HStack(spacing: AtlasSpacing.xl) {
                        Label(character.location, systemImage: "mappin")
                        Label(character.organization, systemImage: "person.3")
                    }
                    .font(AtlasFont.caption)
                }

                CharacterCustomFields(
                    character: character,
                    canEditFields: character.id == "char-cen"
                )

                CharacterInteractionDisclosureGroup(character: character)

                HStack {
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
            .frame(maxWidth: 820, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(AtlasCanvasBackground())
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.55), radius: 42, y: 20)
    }
}

struct CharacterPortraitBanner: View {
    let character: AtlasCharacterProfile

    var body: some View {
        Image(characterImageName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 760)
            .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
            .overlay {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.50),
                    .init(color: .black.opacity(0.22), location: 0.72),
                    .init(color: .black.opacity(0.86), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.card))
            .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AtlasSpacing.l)
    }

    private var characterImageName: String {
        let images = [
            "PixabayBanner",
            "PixabayLandscape2",
            "PixabayLandscape3",
            "PixabayLandscape4",
            "PixabayLandscape5",
            "PixabayLandscape6"
        ]
        return images[abs(character.id.hashValue) % images.count]
    }
}

struct CharacterCustomFields: View {
    struct CustomField: Identifiable {
        let id = UUID()
        var label: String
        var value: String
    }

    let character: AtlasCharacterProfile
    let canEditFields: Bool
    @State private var fields: [CustomField] = [
        .init(label: "常用称呼", value: "可以称呼我为「小岑」"),
        .init(label: "互动备注", value: "夜间场景与调查剧情优先")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            ForEach($fields) { $field in
                if canEditFields {
                    VStack(alignment: .leading, spacing: 5) {
                        TextField("字段名", text: $field.label)
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                        TextField("字段内容", text: $field.value)
                            .font(AtlasFont.caption)
                    }
                    .textFieldStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(field.label)
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                        Text(field.value)
                            .font(AtlasFont.caption)
                            .foregroundStyle(AtlasColor.textPrimary)
                    }
                }
            }

            if canEditFields {
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        fields.append(.init(label: "新字段", value: "点击填写内容"))
                    }
                } label: {
                    Label("添加字段", systemImage: "plus")
                        .font(AtlasFont.caption)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AtlasColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CharacterInteractionDisclosureGroup: View {
    let character: AtlasCharacterProfile

    var body: some View {
        HStack(alignment: .top, spacing: AtlasSpacing.m) {
            CharacterDisclosurePanel(title: "适合互动", symbol: "checkmark") {
                VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                    ForEach(character.dos, id: \.self) { item in
                        Label(item, systemImage: "circle.fill")
                    }
                }
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textSecondary)
            }

            CharacterDisclosurePanel(title: "不允许触碰", symbol: "hand.raised") {
                VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                    ForEach(character.donts, id: \.self) { item in
                        Label(item, systemImage: "circle.fill")
                    }
                }
                .font(AtlasFont.caption)
                .foregroundStyle(AtlasColor.textSecondary)
            }

            CharacterDisclosurePanel(title: "全局创作许可", symbol: "checklist") {
                FlowLayout(spacing: AtlasSpacing.s) {
                    ForEach(character.permissions) { permission in
                        Label(
                            "\(permission.title) · \(permission.state.rawValue)",
                            systemImage: permissionSymbol(permission.state)
                        )
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .padding(.horizontal, AtlasSpacing.s)
                        .padding(.vertical, 7)
                        .atlasGlass(Capsule())
                    }
                }
            }
        }
    }

    private func permissionSymbol(_ state: AtlasCharacterProfile.Permission.State) -> String {
        switch state {
        case .allowed: return "checkmark"
        case .confirm: return "questionmark"
        case .forbidden: return "minus"
        }
    }
}

private struct CharacterDisclosurePanel<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content
    @State private var expanded = true

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: expanded ? AtlasRadius.card : 18,
            style: .continuous
        )
        VStack(alignment: .leading, spacing: 0) {
            if expanded {
                content()
                    .padding(.horizontal, AtlasSpacing.l)
                    .padding(.top, AtlasSpacing.l)
                    .padding(.bottom, AtlasSpacing.m)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            Button {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: AtlasSpacing.s) {
                    Image(systemName: symbol)
                    Text(title)
                        .font(AtlasFont.label)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(AtlasColor.textPrimary)
                .padding(.horizontal, AtlasSpacing.l)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .atlasP1Glass(shape)
        .animation(.spring(response: 0.44, dampingFraction: 0.86), value: expanded)
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
