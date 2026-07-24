//
//  RelationDetail.swift
//  关系作为「一等对象」的呈现层（用户 2026-07-24 确认方向）。
//
//  连线表达不了复杂关系——有的关系需要一整段文字/故事去阐述。
//  所以：画布上连线仍在，但连线中点长出可点选的 chip；点开进入右侧「关系详情卡」，
//  在那里给关系起名、标强度、并写一段自由长文叙事。黑白单色：强度靠线宽+亮度。
//

import SwiftUI

// MARK: - 连线中点的可点选 chip

struct RelationChip: View {
    var relation: BuilderRelation
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if relation.hasNarrative {
                    Image(systemName: "text.alignleft").font(.system(size: 8, weight: .bold))
                }
                Text(relation.chipLabel.isEmpty ? "关系" : relation.chipLabel)
                    .font(AtlasFont.monoSmall).lineLimit(1)
            }
            .foregroundStyle(selected ? AtlasColor.inverse : AtlasColor.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background {
                if selected { Capsule().fill(Color.white) }
                else { Capsule().fill(AtlasP1Glass.darkFill) }
            }
            .overlay(Capsule().stroke(AtlasColor.borderSubtle))
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

// MARK: - 强度选择器（黑白分段）

struct StrengthPicker: View {
    @Binding var strength: RelationStrength

    var body: some View {
        HStack(spacing: 2) {
            ForEach(RelationStrength.allCases) { s in
                Button { strength = s } label: {
                    HStack(spacing: 5) {
                        Capsule()
                            .fill(strength == s ? AtlasColor.inverse : AtlasColor.textSecondary)
                            .frame(width: 16, height: s.lineWidth)
                        Text(s.rawValue).font(AtlasFont.caption)
                    }
                    .foregroundStyle(strength == s ? AtlasColor.inverse : AtlasColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background { if strength == s { Capsule().fill(Color.white) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle))
    }
}

// MARK: - 右侧关系详情卡

struct RelationDetailCard: View {
    @Binding var relation: BuilderRelation
    @ObservedObject var store: WorldBuilderStore
    var onDelete: () -> Void

    var body: some View {
        let src = store.object(withID: relation.sourceID)
        let tgt = store.object(withID: relation.targetID)

        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 12))
                    Text("关系").font(AtlasFont.caption)
                }
                .foregroundStyle(AtlasColor.textSecondary)
                Spacer()
                Button { store.selectRelation(nil) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(AtlasColor.textSecondary)
            }

            // 两端端点
            HStack(spacing: AtlasSpacing.s) {
                endpoint(src)
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 11)).foregroundStyle(AtlasColor.textTertiary)
                endpoint(tgt)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: AtlasSpacing.l) {
                    // 关系名
                    VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                        Text("关系名 · 可选").font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                        TextField("如：十年之约", text: $relation.title)
                            .textFieldStyle(.plain)
                            .font(AtlasFont.serifHeading)
                            .foregroundStyle(AtlasColor.textPrimary)
                            .padding(AtlasSpacing.s)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                            .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
                    }

                    if let sub = relation.subtag, !sub.isEmpty {
                        HStack(spacing: 5) {
                            Text("类别").font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                            Text(sub).font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.white.opacity(0.06), in: Capsule())
                                .overlay(Capsule().stroke(AtlasColor.borderSubtle))
                        }
                    }

                    VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                        Text("强度").font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                        StrengthPicker(strength: $relation.strength)
                    }

                    // 长文叙事：连线表达不了的，写在这里
                    VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                        HStack(spacing: 5) {
                            Image(systemName: "text.alignleft").font(.system(size: 10))
                            Text("这段关系的故事").font(AtlasFont.caption)
                        }
                        .foregroundStyle(AtlasColor.textTertiary)
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $relation.narrative)
                                .font(AtlasFont.body).foregroundStyle(AtlasColor.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(height: 168).padding(AtlasSpacing.s)
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                                .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
                            if relation.narrative.isEmpty {
                                Text("有的关系一句话说不清——恩怨、旧约、背叛的来龙去脉，都写在这里。")
                                    .font(AtlasFont.body).foregroundStyle(AtlasColor.textTertiary)
                                    .padding(AtlasSpacing.s).padding(.top, 2).allowsHitTesting(false)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            Spacer(minLength: AtlasSpacing.s)

            Button(role: .destructive) { onDelete() } label: {
                AtlasButtonLabel(title: "移除这条关系", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.atlas(.glass))
        }
        .padding(AtlasSpacing.l)
        .frame(maxHeight: .infinity, alignment: .top)
        .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
    }

    private func endpoint(_ o: BuilderObject?) -> some View {
        HStack(spacing: 6) {
            if let o {
                NodeGlyph(shape: o.kind.shape, symbol: o.kind.symbol, size: 20)
                Text(store.displayName(o)).font(AtlasFont.label)
                    .foregroundStyle(AtlasColor.textPrimary).lineLimit(1)
            } else {
                Image(systemName: "questionmark.circle").foregroundStyle(AtlasColor.textDisabled)
                Text("已失效").font(AtlasFont.label).foregroundStyle(AtlasColor.textDisabled)
            }
        }
        .padding(.horizontal, AtlasSpacing.s).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
    }
}
