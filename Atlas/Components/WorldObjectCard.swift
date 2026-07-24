//
//  WorldObjectCard.swift
//  Atlas 领域组件 —— 世界对象卡。
//  结构：类型图标 + 等宽 ID + 名称 + 摘要 + 元数据行（状态/版本/关联/AI 标注）。
//  类型与状态一律靠 图标 + 文案 + 亮度 区分，不靠颜色。
//

import SwiftUI

struct WorldObjectCard: View {
    var object: WorldObject
    var selected: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous)

        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            // 头部：图标 + 类型 + ID
            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: object.type.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AtlasColor.textPrimary)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(object.type.rawValue)
                    .font(AtlasFont.caption)
                    .foregroundStyle(AtlasColor.textSecondary)

                Spacer()

                Text(object.id)
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }

            // 名称
            Text(object.name)
                .font(AtlasFont.heading)
                .foregroundStyle(AtlasColor.textPrimary)
                .lineLimit(1)

            // 摘要
            Text(object.summary)
                .font(AtlasFont.body)
                .foregroundStyle(AtlasColor.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(AtlasColor.borderSubtle)

            // 元数据行
            HStack(spacing: AtlasSpacing.m) {
                StatusChip(status: object.status)

                MetaItem(symbol: "arrow.triangle.branch", text: "v\(object.version)")
                MetaItem(symbol: "link", text: "\(object.linkCount)")

                Spacer()

                if object.aiAssisted {
                    // AI 辅助必须透明标注（Atlas 红线）
                    HStack(spacing: 3) {
                        Image(systemName: "sparkle").font(.system(size: 9))
                        Text("AI 辅助").font(AtlasFont.monoSmall)
                    }
                    .foregroundStyle(AtlasColor.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(Capsule().stroke(AtlasColor.borderSubtle, lineWidth: 1))
                }
            }
        }
        .padding(AtlasSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .atlasGlass(shape)
        .overlay(
            shape.stroke(selected ? AtlasColor.borderStrong : AtlasColor.borderSubtle,
                         lineWidth: selected ? 1.5 : 1)
        )
    }
}

private struct StatusChip: View {
    var status: WorldObjectStatus
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbol).font(.system(size: 9.5, weight: .medium))
            Text(status.rawValue).font(AtlasFont.caption)
        }
        .foregroundStyle(Color(white: status.emphasis))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle, lineWidth: 1))
    }
}

private struct MetaItem: View {
    var symbol: String
    var text: String
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9.5))
            Text(text).font(AtlasFont.monoSmall)
        }
        .foregroundStyle(AtlasColor.textTertiary)
    }
}
