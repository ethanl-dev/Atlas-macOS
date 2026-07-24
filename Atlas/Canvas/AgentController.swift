//
//  AgentController.swift
//  Canvas 里 Agent 的全部"手" —— 独立于 AtlasAppModel，按对象 ID 记账。
//  它只能：产卡、采纳后写【草稿】、标/清冲突徽章。碰不到正式设定。
//

import SwiftUI

/// 绑对象类型的快捷动作（Stitch 式编号芯片）。
struct QuickAction: Identifiable {
    let id = UUID()
    var title: String
    var kind: AgentCardKind
    var targetField: String?
}

@MainActor
final class AgentController: ObservableObject {
    /// 当前浮在画布上的待确认卡
    @Published var cards: [AgentCard] = []
    /// 采纳落下的草稿字段（objectID → fields）
    @Published var drafts: [String: [DraftField]] = [:]
    /// 存为备注（objectID → notes）
    @Published var notes: [String: [String]] = [:]
    /// 冲突徽章数（objectID → count）。种一个演示用冲突（事件「夜航守望」的时间冲突）。
    @Published var conflicts: [String: Int] = ["EVT-009": 1]
    /// 被 AI 辅助过的对象（用于节点/卡上的透明标注）
    @Published var aiAssisted: Set<String> = ["CHR-027"]

    // MARK: 快捷动作（按对象类型）

    func quickActions(for object: WorldObject) -> [QuickAction] {
        switch object.type {
        case .location:
            return [
                .init(title: "补进入条件", kind: .fill, targetField: "进入条件"),
                .init(title: "查关联角色", kind: .tidy, targetField: nil),
                .init(title: "生成公开简介", kind: .copywriting, targetField: "公开简介"),
                .init(title: "给我三个灵感", kind: .inspiration, targetField: nil),
            ]
        case .character:
            return [
                .init(title: "查角色卡缺项", kind: .fill, targetField: "身份"),
                .init(title: "建议可参与事件", kind: .tidy, targetField: nil),
                .init(title: "拟审核问题", kind: .review, targetField: nil),
                .init(title: "给我三个灵感", kind: .inspiration, targetField: nil),
            ]
        case .event:
            return [
                .init(title: "生成参与条件", kind: .fill, targetField: "参与条件"),
                .init(title: "检查时间冲突", kind: .conflict, targetField: nil),
                .init(title: "生成结算字段", kind: .fill, targetField: "结算方式"),
            ]
        case .organization:
            return [
                .init(title: "补权力结构", kind: .fill, targetField: "权力结构"),
                .init(title: "生成公开信息", kind: .copywriting, targetField: "公开信息"),
                .init(title: "给我三个灵感", kind: .inspiration, targetField: nil),
            ]
        default:
            return [
                .init(title: "整理成结构", kind: .tidy, targetField: nil),
                .init(title: "给我三个灵感", kind: .inspiration, targetField: nil),
            ]
        }
    }

    // MARK: 触发（本地 MockAgent）

    func run(_ action: QuickAction, object: WorldObject) {
        append(MockAgent.card(for: action, object: object))
    }

    func ask(_ text: String, object: WorldObject) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        append(MockAgent.freeform(text: text, object: object))
    }

    func revealConflict(object: WorldObject) {
        // 若该对象已有浮出的冲突卡则不重复
        guard !cards.contains(where: { $0.anchorObjectID == object.id && $0.kind == .conflict }) else { return }
        append(MockAgent.conflictCard(object))
    }

    private func append(_ card: AgentCard) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            cards.append(card)
        }
    }

    // MARK: 四去向

    func adopt(_ card: AgentCard) {
        let value = card.editing || card.chosenOption == nil
            ? card.body
            : card.options[card.chosenOption!]
        let field = card.targetField ?? card.kind.rawValue
        drafts[card.anchorObjectID, default: []].append(
            DraftField(label: field, value: value, aiAssisted: true)
        )
        aiAssisted.insert(card.anchorObjectID)
        if card.kind == .conflict { conflicts[card.anchorObjectID] = 0 }
        remove(card)
    }

    func rewrite(_ card: AgentCard) {
        if let c = card.chosenOption { card.body = card.options[c] }
        card.editing = true
    }

    func keepAsNote(_ card: AgentCard) {
        let value = card.editing ? card.body : (card.chosenOption.map { card.options[$0] } ?? card.body)
        notes[card.anchorObjectID, default: []].append(value)
        remove(card)
    }

    func dismiss(_ card: AgentCard) { remove(card) }

    private func remove(_ card: AgentCard) {
        withAnimation(.easeOut(duration: 0.2)) {
            cards.removeAll { $0.id == card.id }
        }
    }

    // MARK: 供 inspector 显示

    func draftCount(_ objectID: String) -> Int { drafts[objectID]?.count ?? 0 }
}
