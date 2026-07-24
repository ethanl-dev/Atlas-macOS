//
//  AgentActions.swift
//  Agent「整理」通道的指令集（= 用户说的"命令行工具"）与解析/几何。
//
//  纪律（用户 2026-07-24 确认）：整理 ≠ 编辑卡片内容。
//  这些工具只动【布局】与【关系】，绝不改卡片的 name / summary / 时间等正文。
//  所以工具清单里没有任何写正文的函数。内容仍走既有「递卡→采纳」通道。
//

import SwiftUI

// MARK: - 模型可调用的工具（function-calling schema）

enum AgentToolSchema {
    /// 传给 DeepSeek `tools` 字段的数组。
    static func tools() -> [[String: Any]] {
        [
            fn("arrange_canvas",
               "把整块画布按某种策略重新排布。用于'帮我把画布整理一下 / 按类型归类 / 摆整齐'这类请求。",
               ["type": "object",
                "properties": [
                    "strategy": ["type": "string",
                                 "enum": ["by_type", "grid", "radial", "timeline"],
                                 "description": "by_type=按对象类型分列；grid=紧凑网格；radial=以关系最多的对象为中心成环；timeline=事件按阶段排成时间线雏形"]
                ],
                "required": ["strategy"]]),

            fn("cluster_cards",
               "把指定的一组卡片聚拢到一起、摆整齐（不改内容）。用于'把这几个角色放一块 / 把某组织相关的都聚拢'。",
               ["type": "object",
                "properties": [
                    "ids": ["type": "array", "items": ["type": "string"],
                            "description": "要聚拢的卡片 id 列表（用画布快照里的 id）"],
                    "label": ["type": "string", "description": "这组的可选说明，仅用于人类阅读"]
                ],
                "required": ["ids"]]),

            fn("move_card",
               "把单张卡片移动到画布坐标 (x,y)。一般不需要，除非用户明确要求精确位置。",
               ["type": "object",
                "properties": [
                    "id": ["type": "string"],
                    "x": ["type": "number"],
                    "y": ["type": "number"]
                ],
                "required": ["id", "x", "y"]]),

            fn("link_objects",
               "在两个对象之间建立一条关系（比如'涉及角色''盟友''敌对'）。这是提议，作者需采纳。可带一句关系说明，但这属于关系本身、不是卡片正文。",
               ["type": "object",
                "properties": [
                    "source": ["type": "string", "description": "关系起点 id"],
                    "target": ["type": "string", "description": "关系终点 id"],
                    "relation": ["type": "string", "description": "关系类别短标签，如 盟友/敌对/师徒/涉及/发生于"],
                    "note": ["type": "string", "description": "可选：一句话说明这段关系（写到关系卡，不写卡片正文）"],
                    "strength": ["type": "string", "enum": ["weak", "medium", "strong"]]
                ],
                "required": ["source", "target"]]),

            fn("unlink",
               "移除一条已存在的关系。",
               ["type": "object",
                "properties": ["relation_id": ["type": "string"]],
                "required": ["relation_id"]])
        ]
    }

    private static func fn(_ name: String, _ desc: String, _ params: [String: Any]) -> [String: Any] {
        ["type": "function",
         "function": ["name": name, "description": desc, "parameters": params]]
    }
}

// MARK: - 从模型工具调用解析出的动作

enum AgentAction {
    case move(id: String, x: Double, y: Double)
    case cluster(ids: [String], label: String?)
    case arrange(strategy: String)
    case link(source: String, target: String, relation: String?, note: String?, strength: String?)
    case unlink(relationID: String)

    /// 从 tool_call 的 name + arguments(JSON 字符串) 解析。
    static func from(name: String, argumentsJSON: String) -> AgentAction? {
        let data = argumentsJSON.data(using: .utf8) ?? Data()
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        switch name {
        case "move_card":
            guard let id = obj["id"] as? String,
                  let x = (obj["x"] as? NSNumber)?.doubleValue,
                  let y = (obj["y"] as? NSNumber)?.doubleValue else { return nil }
            return .move(id: id, x: x, y: y)
        case "cluster_cards":
            guard let ids = obj["ids"] as? [String], !ids.isEmpty else { return nil }
            return .cluster(ids: ids, label: obj["label"] as? String)
        case "arrange_canvas":
            guard let s = obj["strategy"] as? String else { return nil }
            return .arrange(strategy: s)
        case "link_objects":
            guard let s = obj["source"] as? String, let t = obj["target"] as? String else { return nil }
            return .link(source: s, target: t,
                         relation: obj["relation"] as? String,
                         note: obj["note"] as? String,
                         strength: obj["strength"] as? String)
        case "unlink":
            guard let r = obj["relation_id"] as? String else { return nil }
            return .unlink(relationID: r)
        default:
            return nil
        }
    }
}

// MARK: - 采纳后落到画布的具体操作（布局 + 关系；永不动正文）

enum CanvasOp: Identifiable {
    case move(id: String, to: CGPoint)
    case link(source: String, target: String, subtag: String?, note: String, strength: RelationStrength)
    case unlink(relationID: String)

    var id: String {
        switch self {
        case .move(let id, let p):        return "mv-\(id)-\(Int(p.x))-\(Int(p.y))"
        case .link(let s, let t, _, _, _): return "lk-\(s)-\(t)"
        case .unlink(let r):              return "ul-\(r)"
        }
    }
}

// MARK: - 排布几何（cluster / arrange 在 Swift 侧算出坐标，模型只需给策略或分组）
//
// 尺寸感知：所有排布都读每张卡的真实 size，按「列最大宽 + 行内累加高 + gutter」摆放，
// 卡片在各自单元格内居中——不同面积/形状的卡也不会重叠。返回值是卡片中心坐标。

enum CanvasArrange {
    static let gutter: CGFloat = 56
    static let originX: CGFloat = 260
    static let originY: CGFloat = 200

    /// 列式堆叠：给定「列 → [对象]」，按各列最大宽、列内按各卡真实高累加排布。
    private static func packColumns(_ columns: [[BuilderObject]]) -> [String: CGPoint] {
        var out: [String: CGPoint] = [:]
        var x = originX
        for col in columns {
            guard !col.isEmpty else { continue }
            let colW = col.map { $0.size.width }.max() ?? 200
            var y = originY
            for obj in col {
                out[obj.id] = CGPoint(x: x + colW / 2, y: y + obj.size.height / 2)
                y += obj.size.height + gutter
            }
            x += colW + gutter
        }
        return out
    }

    /// 按类型分列：每种 kind 一列，列内竖排（尺寸感知）。
    static func byType(objects: [BuilderObject]) -> [String: CGPoint] {
        var grouped: [BuilderKind: [BuilderObject]] = [:]
        for o in objects { grouped[o.kind, default: []].append(o) }
        let columns = BuilderKind.allCases.compactMap { kind -> [BuilderObject]? in
            let items = grouped[kind] ?? []
            return items.isEmpty ? nil : items
        }
        return packColumns(columns)
    }

    /// 紧凑网格：近似正方形，但每列宽取该列最宽卡、每行高取该行最高卡，逐卡居中，绝不重叠。
    static func grid(objects: [BuilderObject]) -> [String: CGPoint] {
        guard !objects.isEmpty else { return [:] }
        let cols = max(1, Int(ceil(sqrt(Double(objects.count)))))
        let rows = Int(ceil(Double(objects.count) / Double(cols)))

        var colW = [CGFloat](repeating: 0, count: cols)
        var rowH = [CGFloat](repeating: 0, count: rows)
        for (i, o) in objects.enumerated() {
            let r = i / cols, c = i % cols
            colW[c] = max(colW[c], o.size.width)
            rowH[r] = max(rowH[r], o.size.height)
        }

        var colX = [CGFloat](repeating: 0, count: cols)
        var acc = originX
        for c in 0..<cols { colX[c] = acc; acc += colW[c] + gutter }
        var rowY = [CGFloat](repeating: 0, count: rows)
        acc = originY
        for r in 0..<rows { rowY[r] = acc; acc += rowH[r] + gutter }

        var out: [String: CGPoint] = [:]
        for (i, o) in objects.enumerated() {
            let r = i / cols, c = i % cols
            out[o.id] = CGPoint(x: colX[c] + colW[c] / 2, y: rowY[r] + rowH[r] / 2)
        }
        return out
    }

    /// 把一组 id 聚拢：先按 grid 摆好，再整体平移，使包围盒中心 = 原质心。
    static func cluster(ids: [String], objects: [BuilderObject]) -> [String: CGPoint] {
        let picked = objects.filter { ids.contains($0.id) }
        guard !picked.isEmpty else { return [:] }
        let laid = grid(objects: picked)
        guard !laid.isEmpty else { return [:] }
        let cx0 = picked.map { $0.position.x }.reduce(0, +) / CGFloat(picked.count)
        let cy0 = picked.map { $0.position.y }.reduce(0, +) / CGFloat(picked.count)
        let xs = laid.values.map { $0.x }, ys = laid.values.map { $0.y }
        let cx1 = (xs.min()! + xs.max()!) / 2, cy1 = (ys.min()! + ys.max()!) / 2
        let dx = cx0 - cx1, dy = cy0 - cy1
        return laid.mapValues { CGPoint(x: $0.x + dx, y: $0.y + dy) }
    }

    /// 以关系最多的对象为中心，其余成环。半径按卡片尺寸与数量放大，避免环上/与中心重叠。
    static func radial(objects: [BuilderObject], relations: [BuilderRelation]) -> [String: CGPoint] {
        guard !objects.isEmpty else { return [:] }
        var degree: [String: Int] = [:]
        for r in relations { degree[r.sourceID, default: 0] += 1; degree[r.targetID, default: 0] += 1 }
        let center = objects.max { (degree[$0.id] ?? 0) < (degree[$1.id] ?? 0) } ?? objects[0]
        let ring = objects.filter { $0.id != center.id }
        let cx: CGFloat = 720, cy: CGFloat = 470
        var out: [String: CGPoint] = [center.id: CGPoint(x: cx, y: cy)]
        guard !ring.isEmpty else { return out }

        let maxRingExtent = ring.map { max($0.size.width, $0.size.height) }.max() ?? 200
        let centerHalf = max(center.size.width, center.size.height) / 2
        // 周长需容纳所有环上卡片；且中心与环之间要留避让。
        let circumferenceNeed = Double(ring.count) * Double(maxRingExtent + gutter) / (2 * .pi)
        let clearanceNeed = Double(centerHalf + maxRingExtent / 2 + gutter)
        let radius = CGFloat(max(circumferenceNeed, clearanceNeed, 320))
        for (i, obj) in ring.enumerated() {
            let a = Double(i) / Double(ring.count) * 2 * .pi
            out[obj.id] = CGPoint(x: cx + cos(a) * radius, y: cy + sin(a) * radius)
        }
        return out
    }

    /// 时间线雏形：事件按 TimelineLayout 排；非事件保持原位。
    static func timeline(objects: [BuilderObject]) -> [String: CGPoint] {
        TimelineLayout.make(events: objects.filter { $0.kind == .event }).positions
    }
}
