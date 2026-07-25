//
//  CanvasOrganizer.swift
//  Agent「整理」通道的编排器：自然语言 → DeepSeek 工具调用 → 待采纳的整理方案。
//
//  流程（用户确认的边界）：提案 → 幽灵预览 → 作者采纳/撤销。
//  · 只动布局与关系，绝不改卡片正文。
//  · 未配置 Key 时退回本地启发式 MockOrganizer，交互照样跑通。
//

import SwiftUI

// MARK: - 待采纳的整理方案

struct OrganizePlan {
    var ops: [CanvasOp] = []
    var summaries: [String] = []
    var ghostPositions: [String: CGPoint] = [:]                       // 卡片 → 提议新位置
    var proposedLinks: [(source: String, target: String, subtag: String?)] = []
    var removedRelationIDs: [String] = []
    var note: String = ""

    var isEmpty: Bool { ops.isEmpty }
    var moveCount: Int { ops.filter { if case .move = $0 { return true }; return false }.count }
    var linkCount: Int { proposedLinks.count }
    var unlinkCount: Int { removedRelationIDs.count }
}

// MARK: - 编排器

@MainActor
final class CanvasOrganizer: ObservableObject {
    @Published var isThinking = false
    @Published var plan: OrganizePlan?
    @Published var errorText: String?

    var hasPreview: Bool { plan != nil }

    // MARK: 提案

    func propose(instruction: String, store: WorldBuilderStore) {
        let text = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isThinking = true; errorText = nil; plan = nil
        let snap = Self.snapshot(store)

        Task { @MainActor in
            do {
                let actions: [AgentAction]
                var note: String
                if AgentConfig.isConfigured {
                    do {
                        let reply = try await DeepSeekClient().organize(instruction: text, snapshot: snap)
                        actions = reply.actions
                        note = reply.assistantText.isEmpty
                            ? "依据当前对象类型与关系生成。"
                            : reply.assistantText
                    } catch DeepSeekError.timedOut {
                        // 常见布局与关系指令可以在本地继续完成，超时不应让用户空等后什么也看不到。
                        actions = MockOrganizer.actions(for: text, store: store)
                        note = "模型响应超时，已使用本地布局规则生成可预览方案。"
                    }
                } else {
                    actions = MockOrganizer.actions(for: text, store: store)
                    note = "本地演示 · 未配置 DeepSeek Key"
                }
                var p = buildPlan(from: actions, store: store)
                p.note = note
                isThinking = false
                if p.isEmpty {
                    errorText = "没找到可整理的动作。换个说法，或先往画布上放些卡片。"
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { plan = p }
                }
            } catch {
                isThinking = false
                errorText = error.localizedDescription
            }
        }
    }

    // MARK: 采纳 / 撤销

    func adopt(into store: WorldBuilderStore) {
        guard let p = plan else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            for op in p.ops {
                switch op {
                case .move(let id, let to):
                    store.place(id, at: to)
                case .link(let s, let t, let sub, let note, let strength):
                    store.createRelation(source: s, target: t, subtag: sub,
                                         title: "", narrative: note, strength: strength, proposed: false)
                case .unlink(let r):
                    store.removeLink(r)
                }
            }
        }
        plan = nil
    }

    func discard() {
        withAnimation(.easeOut(duration: 0.2)) { plan = nil; errorText = nil }
    }

    // MARK: 把动作解析成方案（含幽灵预览坐标）

    private func buildPlan(from actions: [AgentAction], store: WorldBuilderStore) -> OrganizePlan {
        var plan = OrganizePlan()
        func name(_ id: String) -> String { store.object(withID: id).map(store.displayName) ?? id }

        for action in actions {
            switch action {
            case .move(let id, let x, let y):
                guard store.object(withID: id) != nil else { continue }
                let p = CGPoint(x: x, y: y)
                plan.ops.append(.move(id: id, to: p))
                plan.ghostPositions[id] = p
                plan.summaries.append("移动「\(name(id))」")

            case .cluster(let ids, let label):
                let map = CanvasArrange.cluster(ids: ids, objects: store.objects)
                for (id, p) in map {
                    plan.ops.append(.move(id: id, to: p)); plan.ghostPositions[id] = p
                }
                if !map.isEmpty {
                    plan.summaries.append("聚拢 \(map.count) 张卡片\(label.map { "（\($0)）" } ?? "")")
                }

            case .arrange(let strategy):
                let map = arrangement(strategy, store: store)
                for (id, p) in map {
                    plan.ops.append(.move(id: id, to: p)); plan.ghostPositions[id] = p
                }
                if !map.isEmpty { plan.summaries.append("按「\(strategyTitle(strategy))」重排 \(map.count) 张卡片") }

            case .link(let s, let t, let relation, let note, let strengthStr):
                guard store.object(withID: s) != nil, store.object(withID: t) != nil, s != t else { continue }
                let strength = Self.parseStrength(strengthStr)
                plan.ops.append(.link(source: s, target: t, subtag: relation,
                                      note: note ?? "", strength: strength))
                plan.proposedLinks.append((s, t, relation))
                plan.summaries.append("连接「\(name(s))」→「\(name(t))」\(relation.map { "（\($0)）" } ?? "")")

            case .unlink(let relID):
                guard store.relations.contains(where: { $0.id == relID }) else { continue }
                plan.ops.append(.unlink(relationID: relID))
                plan.removedRelationIDs.append(relID)
                plan.summaries.append("移除一条关系")
            }
        }
        return plan
    }

    private func arrangement(_ strategy: String, store: WorldBuilderStore) -> [String: CGPoint] {
        switch strategy {
        case "by_type":  return CanvasArrange.byType(objects: store.objects)
        case "grid":     return CanvasArrange.grid(objects: store.objects)
        case "radial":   return CanvasArrange.radial(objects: store.objects, relations: store.relations)
        case "timeline": return CanvasArrange.timeline(objects: store.objects)
        default:         return CanvasArrange.grid(objects: store.objects)
        }
    }

    private func strategyTitle(_ s: String) -> String {
        switch s {
        case "by_type": return "按类型分列"
        case "grid": return "紧凑网格"
        case "radial": return "以关系中心成环"
        case "timeline": return "时间线雏形"
        default: return s
        }
    }

    static func parseStrength(_ s: String?) -> RelationStrength {
        switch s {
        case "weak": return .weak
        case "strong": return .strong
        default: return .medium
        }
    }

    // MARK: 画布快照（给模型看的 id 表）

    static func snapshot(_ store: WorldBuilderStore) -> String {
        var lines: [String] = ["对象："]
        if store.objects.isEmpty { lines.append("（空）") }
        for o in store.objects {
            var line = "- \(o.id) · \(o.kind.title) · \(store.displayName(o))"
            if o.kind == .event, let t = o.time { line += "（\(t.shortLabel)）" }
            lines.append(line)
        }
        lines.append("关系：")
        if store.relations.isEmpty { lines.append("（无）") }
        for r in store.relations {
            let s = store.object(withID: r.sourceID).map(store.displayName) ?? r.sourceID
            let t = store.object(withID: r.targetID).map(store.displayName) ?? r.targetID
            let tag = r.subtag ?? r.label
            lines.append("- \(r.id): \(s) →\(tag.isEmpty ? "" : "（\(tag)）") \(t)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - 本地启发式（无 Key 时的演示兜底）

enum MockOrganizer {
    @MainActor
    static func actions(for instruction: String, store: WorldBuilderStore) -> [AgentAction] {
        let s = instruction
        func has(_ words: [String]) -> Bool { words.contains { s.contains($0) } }

        // 关系类：句中出现两个已存在对象名 → 提议连接
        let mentioned = store.objects.filter { !$0.name.isEmpty && s.contains($0.name) }
        if mentioned.count >= 2 {
            let a = mentioned[0], b = mentioned[1]
            let tag = relationTag(in: s)
            return [.link(source: a.id, target: b.id, relation: tag, note: nil,
                          strength: has(["深", "紧密", "强"]) ? "strong" : nil)]
        }

        if has(["时间", "时间线", "时序", "先后"]) { return [.arrange(strategy: "timeline")] }
        if has(["类型", "归类", "分类", "分组", "按类"]) { return [.arrange(strategy: "by_type")] }
        if has(["环", "中心", "放射", "辐射"]) { return [.arrange(strategy: "radial")] }
        if has(["整理", "摆整齐", "对齐", "排布", "收拾", "整齐", "网格"]) { return [.arrange(strategy: "grid")] }

        // 默认：按类型整理（最常见的"帮我整理一下"）
        return store.objects.isEmpty ? [] : [.arrange(strategy: "by_type")]
    }

    private static func relationTag(in s: String) -> String? {
        let tags = ["盟友", "敌对", "师徒", "亲属", "对抗", "协作", "涉及", "发生于", "隶属", "持有"]
        return tags.first { s.contains($0) }
    }
}
