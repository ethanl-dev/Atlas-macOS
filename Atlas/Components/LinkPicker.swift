//
//  LinkPicker.swift
//  关联选择器 —— 「+ 关联」触发的浮层。
//
//  两阶段：
//   ① 候选列表：只列出画布上「已存在」且类型匹配、且未关联过的对象。
//      —— 连不了不存在的东西；无候选时给空状态并引导去新建。
//   ② 若字段是关系性 link，选定目标后追加一步「子标签」选择。
//
//  黑白玻璃：浮层用 atlasGlass，行 hover 用极淡白，无强调色。
//

import SwiftUI

struct LinkPicker: View {
    var source: WorldObject
    var field: LinkFieldDef
    var store: LinkStore
    /// 完成或取消后关闭 popover
    var onClose: () -> Void

    @State private var query = ""
    /// 关系性 link 选定后暂存的目标，进入子标签步骤
    @State private var pendingTarget: WorldObject?

    private var candidates: [WorldObject] {
        WorldObject.samples.filter { obj in
            field.accepts.contains(obj.type)
            && obj.id != source.id
            && !store.isLinked(source: source.id, field: field.key, target: obj.id)
            && (query.isEmpty || obj.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            if let target = pendingTarget {
                subtagStep(target)
            } else {
                candidateStep
            }
        }
        .padding(AtlasSpacing.m)
        .frame(width: 240)
        .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous).stroke(AtlasColor.borderSubtle))
    }

    // MARK: 阶段①候选

    private var candidateStep: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            HStack(spacing: 5) {
                Text("关联到")
                    .font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                Text(field.semantic)
                    .font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textSecondary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Color.white.opacity(0.05), in: Capsule())
            }

            if candidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("画布上还没有可关联的「\(field.acceptLabel)」")
                        .font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
                    Text("先新建一张，再回来连它。")
                        .font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
            } else {
                ForEach(candidates) { obj in
                    CandidateRow(object: obj) { pick(obj) }
                }
            }
        }
    }

    // MARK: 阶段②子标签（仅关系性 link）

    private func subtagStep(_ target: WorldObject) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            HStack(spacing: 4) {
                Button { pendingTarget = nil } label: {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(AtlasColor.textTertiary)
                Text("\(source.name) 与 \(target.name) 的关系")
                    .font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }

            FlowChips(tags: field.relationalTags) { tag in
                store.add(source: source.id, field: field.key, target: target.id, subtag: tag)
                onClose()
            }
        }
    }

    private func pick(_ obj: WorldObject) {
        if field.isRelational {
            pendingTarget = obj
        } else {
            store.add(source: source.id, field: field.key, target: obj.id)
            onClose()
        }
    }
}

// MARK: - 候选行：自持 hover 高光（ButtonStyle 里放 @State 不生效，故独立成 View）

private struct CandidateRow: View {
    var object: WorldObject
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: object.type.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AtlasColor.textPrimary)
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(object.name).font(AtlasFont.label).foregroundStyle(AtlasColor.textPrimary).lineLimit(1)
                    Text(object.type.rawValue).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer(minLength: 4)
                Text(object.id).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, AtlasSpacing.s)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.07 : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - 检查器里的「关联区」：列出该对象每个关联字段 + 已连 chip + ＋关联入口

struct LinkSection: View {
    var object: WorldObject
    var store: LinkStore

    var body: some View {
        let fields = LinkRules.fields(for: object.type)
        if !fields.isEmpty {
            VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                HStack {
                    Text("关联").font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                    Spacer()
                    Text("\(store.count(for: object.id))")
                        .font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                }
                ForEach(fields) { field in
                    LinkFieldRow(object: object, field: field, store: store)
                }
            }
        }
    }
}

/// 单个关联字段行；自持 popover 状态，避免 ForEach 内共享绑定导致的多重弹出。
private struct LinkFieldRow: View {
    var object: WorldObject
    var field: LinkFieldDef
    var store: LinkStore
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // 字段名 + 分层锁标记 + 自动语义
            HStack(spacing: 5) {
                Text(field.key)
                    .font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary).tracking(0.5)
                if let lock = field.layer.symbol {
                    Image(systemName: lock).font(.system(size: 8))
                        .foregroundStyle(AtlasColor.textDisabled)
                }
                Text("→ \(field.semantic)")
                    .font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textDisabled)
            }

            FlowLayout(spacing: 6) {
                ForEach(store.links(for: object.id, field: field.key)) { link in
                    LinkChip(link: link) { store.remove(link) }
                }
                Button { showPicker = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 9, weight: .semibold))
                        Text("关联\(field.acceptLabel)").font(AtlasFont.caption)
                    }
                    .foregroundStyle(AtlasColor.textSecondary)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .overlay(Capsule().stroke(AtlasColor.borderDefault, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPicker, arrowEdge: .leading) {
                    LinkPicker(source: object, field: field, store: store) { showPicker = false }
                }
            }
        }
    }
}

// MARK: - 极简流式布局（变宽 chip 自动换行）

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(maxWidth: maxWidth, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = maxWidth.isFinite ? maxWidth : (rows.map(\.width).max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []; var cur = Row(); var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !cur.items.isEmpty {
                rows.append(cur); cur = Row(); x = 0
            }
            cur.items.append(index)
            x += size.width + spacing
            cur.width = max(cur.width, x)
            cur.height = max(cur.height, size.height)
        }
        if !cur.items.isEmpty { rows.append(cur) }
        return rows
    }
}

// MARK: - 子标签流式排布

private struct FlowChips: View {
    var tags: [String]
    var onPick: (String) -> Void

    var body: some View {
        // 子标签数量少，简单 wrap 两列即可
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Button { onPick(tag) } label: {
                    Text(tag)
                        .font(AtlasFont.caption)
                        .foregroundStyle(AtlasColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05), in: Capsule())
                        .overlay(Capsule().stroke(AtlasColor.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
