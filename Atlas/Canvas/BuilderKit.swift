//
//  BuilderKit.swift
//  模板库 —— 一键成套生成预连关系的空态卡片。
//
//  入口：创建世界后画布为空时的中央浮层(TemplateStart)。
//  生成：流式依次生长(节点逐张浮现，关系随后连上)，呼应"骨架流式加载"的首次打动。
//  空态卡：只连好关系、留通用占位名(角色 1 / 地点 1…)与空字段——给结构不给内容，
//         把"填什么"的创作权留给作者，呼应把创作权从 AI 手里夺回来。
//
//  布局：不手摆坐标。KitLayout 按类型分「泳道」——同类归拢成一列，
//        列序按世界逻辑「规则(设定源)→组织→角色→地图→地点→事件→物件→作品→便签」从左到右，
//        避免所有元素混作一团。
//
//  黑白单色：Kit 卡靠 SF Symbol + 排版区分，无强调色。
//

import SwiftUI

// MARK: - Kit 规格（只声明"有哪些节点、谁连谁"，坐标交给 KitLayout）

struct KitNode {
    let ref: String            // kit 内部引用名，用于连边
    let kind: BuilderKind
}

struct KitEdge {
    let from: String
    let field: String          // 必须与 BuilderLinkRules 的字段名一致
    let to: String
    var subtag: String? = nil
}

struct BuilderKit: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let nodes: [KitNode]
    let edges: [KitEdge]

    /// 概览：本 Kit 会生成哪些类型各几张（用于卡片上的小标，按泳道顺序）
    var kindTally: [(BuilderKind, Int)] {
        var count: [BuilderKind: Int] = [:]
        for n in nodes { count[n.kind, default: 0] += 1 }
        return KitLayout.laneOrder.compactMap { kind in
            count[kind].map { (kind, $0) }
        }
    }

    static let all: [BuilderKit] = [explore, minimal, blank]

    // 参考企划 EXPLORE-2450 的骨架（通用占位，内容留空）
    static let explore = BuilderKit(
        id: "explore-2450", title: "完整世界骨架",
        subtitle: "9 张卡 · 关系预连", symbol: "square.grid.3x3.topleft.filled",
        nodes: [
            .init(ref: "map",   kind: .map),
            .init(ref: "loc1",  kind: .location),
            .init(ref: "loc2",  kind: .location),
            .init(ref: "org1",  kind: .org),
            .init(ref: "org2",  kind: .org),
            .init(ref: "chr1",  kind: .character),
            .init(ref: "chr2",  kind: .character),
            .init(ref: "rule1", kind: .rule),
            .init(ref: "evt1",  kind: .event),
        ],
        edges: [
            // 角色 → 所属组织（结构性）
            .init(from: "chr1", field: "阵营归属", to: "org1"),
            .init(from: "chr2", field: "阵营归属", to: "org2"),
            // 角色 → 能力受某规则约束
            .init(from: "chr1", field: "能力边界", to: "rule1"),
            // 地图不参与关系图谱：地点不再连向地图（地图仅作底盘）。
            // 事件 ↔ 角色 / 地点
            .init(from: "evt1", field: "涉及角色", to: "chr1"),
            .init(from: "evt1", field: "触发地点", to: "loc1"),
            // 地点 → 事件在此发生
            .init(from: "loc1", field: "关联",     to: "evt1"),
            // 组织之间：关系性 link（预置子标签）
            .init(from: "org2", field: "对外关系", to: "org1", subtag: "对抗"),
        ]
    )

    // 教学用最小三件套
    static let minimal = BuilderKit(
        id: "minimal", title: "最小叙事单元",
        subtitle: "地点 · 角色 · 事件", symbol: "triangle",
        nodes: [
            .init(ref: "loc",   kind: .location),
            .init(ref: "chr",   kind: .character),
            .init(ref: "evt",   kind: .event),
        ],
        edges: [
            .init(from: "evt", field: "涉及角色", to: "chr"),
            .init(from: "evt", field: "触发地点", to: "loc"),
        ]
    )

    // 从零开始：给一张便签作为落脚点
    static let blank = BuilderKit(
        id: "blank", title: "空白世界",
        subtitle: "一张便签，自由开始", symbol: "note.text",
        nodes: [.init(ref: "note", kind: .note)],
        edges: []
    )
}

// MARK: - 布局：类型分泳道

enum KitLayout {
    /// 泳道从左到右的世界逻辑顺序：设定源 → 行动者 → 空间 → 结果 → 附属。
    static let laneOrder: [BuilderKind] = [.rule, .org, .character, .map, .location, .event, .item, .work, .note]

    private static let laneGap: CGFloat = 320   // 列间距（够放下 360 宽的地图卡）
    private static let rowGap:  CGFloat = 190   // 同类卡的行间距
    private static let center = CGPoint(x: 600, y: 380)

    /// 给一组节点算出各自的画布世界坐标：同类同列、按 laneOrder 从左到右、每列竖向居中堆叠。
    static func positions(for nodes: [KitNode]) -> [String: CGPoint] {
        var byKind: [BuilderKind: [KitNode]] = [:]
        for n in nodes { byKind[n.kind, default: []].append(n) }

        let lanes = laneOrder.filter { byKind[$0] != nil }
        let totalWidth = CGFloat(max(0, lanes.count - 1)) * laneGap

        var result: [String: CGPoint] = [:]
        for (laneIndex, kind) in lanes.enumerated() {
            let x = center.x - totalWidth / 2 + CGFloat(laneIndex) * laneGap
            let group = byKind[kind] ?? []
            let totalHeight = CGFloat(max(0, group.count - 1)) * rowGap
            for (rowIndex, node) in group.enumerated() {
                let y = center.y - totalHeight / 2 + CGFloat(rowIndex) * rowGap
                result[node.ref] = CGPoint(x: x, y: y)
            }
        }
        return result
    }
}

// MARK: - 流式生成

extension WorldBuilderStore {
    func spawn(_ kit: BuilderKit) async {
        selectedIDs = []
        let positions = KitLayout.positions(for: kit.nodes)

        // 通用占位名：同类多张时编号（地点 1 / 地点 2），仅一张时用类型名（地图）。
        var totals: [BuilderKind: Int] = [:]
        for n in kit.nodes { totals[n.kind, default: 0] += 1 }
        var seen: [BuilderKind: Int] = [:]
        var map: [String: String] = [:]

        for node in kit.nodes {
            seen[node.kind, default: 0] += 1
            let name = (totals[node.kind] ?? 1) > 1
                ? "\(node.kind.title) \(seen[node.kind] ?? 1)"
                : node.kind.title
            let pos = positions[node.ref] ?? KitLayout.positions(for: [node])[node.ref] ?? CGPoint(x: 600, y: 380)
            let id = "kit-\(UUID().uuidString.prefix(8))"
            withAnimation(.snappy(duration: 0.34)) {
                objects.append(
                    BuilderObject(id: id, kind: node.kind, name: name,
                                  summary: "", position: pos, size: node.kind.defaultSize)
                )
                if node.kind == .map { mapMade = true }
            }
            map[node.ref] = id
            saved = false
            try? await Task.sleep(for: .seconds(0.12))
        }

        for edge in kit.edges {
            if let s = map[edge.from], let t = map[edge.to] {
                withAnimation(.easeInOut(duration: 0.25)) {
                    addLink(source: s, field: edge.field, target: t, subtag: edge.subtag)
                }
            }
            try? await Task.sleep(for: .seconds(0.06))
        }
        selectedIDs = []
    }
}

// MARK: - 空态浮层：从模板开始

struct TemplateStart: View {
    @ObservedObject var store: WorldBuilderStore

    var body: some View {
        VStack(spacing: AtlasSpacing.xl) {
            VStack(spacing: AtlasSpacing.s) {
                Text("一块空白的世界")
                    .font(AtlasFont.serifTitle)
                    .foregroundStyle(AtlasColor.textSecondary)
                Text("从一个模板开始，或右键画布任意处从零新建")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textTertiary)
            }

            HStack(spacing: AtlasSpacing.l) {
                ForEach(BuilderKit.all) { kit in
                    KitCard(kit: kit) { Task { await store.spawn(kit) } }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // 透明区不拦截：右键新建/平移仍可用
    }
}

private struct KitCard: View {
    let kit: BuilderKit
    var onPick: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                HStack {
                    Image(systemName: kit.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AtlasColor.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(kit.title).font(AtlasFont.serifHeading).foregroundStyle(AtlasColor.textPrimary)
                    Text(kit.subtitle).font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                }

                // 类型小标：会生成哪些卡
                HStack(spacing: 5) {
                    ForEach(Array(kit.kindTally.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 3) {
                            Image(systemName: item.0.symbol).font(.system(size: 8))
                            if item.1 > 1 { Text("\(item.1)").font(AtlasFont.monoSmall) }
                        }
                        .foregroundStyle(AtlasColor.textTertiary)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.white.opacity(0.05), in: Capsule())
                    }
                }
            }
            .padding(AtlasSpacing.m)
            .frame(width: 190, height: 150, alignment: .topLeading)
            .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous), interactive: true)
            .overlay(
                RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous)
                    .stroke(hovering ? AtlasColor.borderStrong : AtlasColor.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
