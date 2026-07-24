//
//  CanvasModels.swift
//  Agent 机制的数据类型：草稿字段 / 组件卡（有限枚举）。
//  节点沿用既有 WorldObject + MapObjectNode，不另立模型。
//

import SwiftUI
import Observation

// MARK: - 草稿字段（Agent 采纳后落入，永不直接进正式设定）

struct DraftField: Identifiable, Hashable {
    let id = UUID()
    var label: String
    var value: String
    var aiAssisted: Bool
}

// MARK: - Agent 组件卡（唯一 AI 产物形态；类型是有限枚举）

enum AgentCardKind: String {
    case inspiration = "灵感"
    case fill        = "补全"
    case tidy        = "整理"
    case conflict    = "冲突"
    case copywriting = "文案"
    case review      = "审核"

    var symbol: String {
        switch self {
        case .inspiration: return "lightbulb"
        case .fill:        return "text.badge.plus"
        case .tidy:        return "list.bullet.rectangle"
        case .conflict:    return "exclamationmark.triangle"
        case .copywriting: return "textformat"
        case .review:      return "checklist"
        }
    }
}

@Observable
final class AgentCard: Identifiable {
    let id = UUID().uuidString
    var kind: AgentCardKind
    var anchorObjectID: String
    var title: String
    /// 主体文字；灵感卡用 options 承载多个 what-if
    var body: String
    var options: [String]
    var chosenOption: Int?
    /// 采纳时写入的目标字段名（补全/文案卡用）
    var targetField: String?
    var editing: Bool = false

    init(kind: AgentCardKind, anchorObjectID: String, title: String,
         body: String = "", options: [String] = [], targetField: String? = nil) {
        self.kind = kind
        self.anchorObjectID = anchorObjectID
        self.title = title
        self.body = body
        self.options = options
        self.targetField = targetField
    }
}
