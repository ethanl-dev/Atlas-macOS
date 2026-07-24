//
//  AgentCardView.swift
//  Agent 组件卡 —— 唯一的 AI 产物形态。虚线边框 + sparkle，一眼可辨"未作数"。
//  四去向：采纳 / 改写 / 存备注 / 扫掉。
//

import SwiftUI

struct AgentCardView: View {
    @Bindable var card: AgentCard
    @ObservedObject var agent: AgentController

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous)

        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            // 头
            HStack(spacing: 6) {
                Image(systemName: card.kind.symbol).font(.system(size: 11, weight: .medium))
                Text("\(card.kind.rawValue)卡").font(AtlasFont.caption)
                Spacer()
                Image(systemName: "sparkle").font(.system(size: 9))
                Text("待确认").font(AtlasFont.monoSmall)
            }
            .foregroundStyle(AtlasColor.textTertiary)

            Text(card.title).font(AtlasFont.label).foregroundStyle(AtlasColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !card.options.isEmpty && !card.editing {
                VStack(spacing: 4) {
                    ForEach(Array(card.options.enumerated()), id: \.offset) { i, opt in
                        Button { card.chosenOption = i } label: {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: card.chosenOption == i ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 11)).padding(.top, 1)
                                Text(opt).font(AtlasFont.body).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(card.chosenOption == i ? AtlasColor.textPrimary : AtlasColor.textSecondary)
                            .padding(AtlasSpacing.s)
                            .background(card.chosenOption == i ? Color.white.opacity(0.06) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if card.editing {
                TextEditor(text: $card.body)
                    .font(AtlasFont.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 84)
                    .padding(6)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
            } else {
                Text(card.body).font(AtlasFont.body).foregroundStyle(AtlasColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(AtlasColor.borderSubtle)

            HStack(spacing: AtlasSpacing.xs) {
                Button { agent.adopt(card) } label: { AtlasButtonLabel(title: "采纳", systemImage: "checkmark") }
                    .buttonStyle(.atlas(.primary))
                Button { agent.rewrite(card) } label: { AtlasButtonLabel(title: "改写", systemImage: "pencil") }
                    .buttonStyle(.atlas(.glass))
                Spacer()
                Button { agent.keepAsNote(card) } label: { Image(systemName: "note.text") }
                    .buttonStyle(.atlas(.ghost))
                Button { agent.dismiss(card) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.atlas(.ghost))
            }
        }
        .padding(AtlasSpacing.m)
        .frame(width: 264)
        .atlasGlass(shape)
        .overlay(shape.stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .foregroundStyle(AtlasColor.borderStrong))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }
}
