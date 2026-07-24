//
//  LinkChip.swift
//  单色关联 chip —— 完成关联后，字段里不显示「@名字」，而是这枚 chip。
//  黑白系统：靠 目标类型 SF Symbol + 名称 区分，不靠颜色。
//

import SwiftUI

/// 通过 id 查目标对象（当前数据源沿用 WorldObject.samples）。
enum WorldObjectLookup {
    static func object(_ id: String) -> WorldObject? {
        WorldObject.samples.first { $0.id == id }
    }
}

struct LinkChip: View {
    var link: WorldLink
    /// 传 nil 表示只读（不显示移除按钮）
    var onRemove: (() -> Void)? = nil

    var body: some View {
        let target = WorldObjectLookup.object(link.targetID)
        HStack(spacing: 5) {
            Image(systemName: target?.type.symbol ?? "questionmark.circle")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AtlasColor.textSecondary)

            Text(target?.name ?? "已失效")
                .font(AtlasFont.caption)
                .foregroundStyle(target == nil ? AtlasColor.textDisabled : AtlasColor.textPrimary)
                .strikethrough(target == nil, color: AtlasColor.textDisabled)
                .lineLimit(1)

            if let sub = link.subtag {
                Text(sub)
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
                    .padding(.leading, 5)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(AtlasColor.borderSubtle).frame(width: 1, height: 11)
                    }
            }

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle, lineWidth: 1))
    }
}
