//
//  WorldObject.swift
//  Atlas 世界对象模型（对应 PRD 02 的对象底层）。
//
//  Atlas 的底层不是"页面"，而是"世界对象"：地点/角色/组织/事件/规则/物件/作品……
//  对象类型必须靠 图标 + 标签 + 结构 区分，而不是靠颜色（黑白系统的硬约束）。
//

import SwiftUI

enum WorldObjectType: String, CaseIterable, Identifiable {
    case world        = "世界"
    case location     = "地点"
    case character    = "角色"
    case organization = "组织"
    case event        = "事件"
    case rule         = "规则"
    case artifact     = "物件"
    case work         = "作品"
    case relationship = "关系"

    var id: String { rawValue }

    /// 单色 SF Symbol —— 区分靠形状不靠色。
    var symbol: String {
        switch self {
        case .world:        return "globe.asia.australia"
        case .location:     return "mappin.and.ellipse"
        case .character:    return "person.crop.circle"
        case .organization: return "building.columns"
        case .event:        return "bolt.horizontal.circle"
        case .rule:         return "scroll"
        case .artifact:     return "shippingbox"
        case .work:         return "paintbrush.pointed"
        case .relationship: return "person.line.dotted.person"
        }
    }
}

/// 对象状态（PRD 02 状态机）。黑白系统里用文案 + 图标 + 亮度表达，不用色相。
enum WorldObjectStatus: String {
    case draft     = "草稿"
    case pending   = "待确认"
    case official  = "正式设定"
    case published = "已公开"
    case archived  = "已归档"

    var symbol: String {
        switch self {
        case .draft:     return "pencil.line"
        case .pending:   return "hourglass"
        case .official:  return "checkmark.seal"
        case .published: return "eye"
        case .archived:  return "archivebox"
        }
    }

    /// 亮度权重：越"正式/公开"越亮。
    var emphasis: Double {
        switch self {
        case .draft:     return 0.42
        case .pending:   return 0.58
        case .official:  return 0.92
        case .published: return 0.80
        case .archived:  return 0.34
        }
    }
}

struct WorldObject: Identifiable {
    let id: String            // 短 ID，等宽展示，如 LOC-014
    var type: WorldObjectType
    var name: String
    var summary: String
    var status: WorldObjectStatus
    var version: Int
    var linkCount: Int        // 关联对象数
    var aiAssisted: Bool      // 是否有 AI 辅助痕迹（需透明标注）

    static let samples: [WorldObject] = [
        .init(id: "WLD-001", type: .world, name: "雾海来信",
              summary: "潮汐带走声音，白塔保存远航记录。一片以鲸歌导航、以极光纪年的失声海域。",
              status: .published, version: 7, linkCount: 34, aiAssisted: false),
        .init(id: "LOC-014", type: .location, name: "魔法森林 · 青枝领",
              summary: "终年薄雾与荧光孢子。树木会保存经过者的声音，夜里沿银色溪流低声复述。",
              status: .official, version: 3, linkCount: 12, aiAssisted: false),
        .init(id: "CHR-027", type: .character, name: "守林人 · 艾琳娜",
              summary: "记录森林边界变化的年轻守林人，随身一本会自动补全路线的旧地图。",
              status: .official, version: 2, linkCount: 8, aiAssisted: true),
        .init(id: "ORG-005", type: .organization, name: "森林议会",
              summary: "维护青枝领边界秩序的七席合议体，第七席常年空缺。",
              status: .pending, version: 1, linkCount: 5, aiAssisted: false),
        .init(id: "EVT-009", type: .event, name: "夜航守望",
              summary: "新月之夜的限时事件：守望者需在潮声退去前点亮全部白塔。",
              status: .draft, version: 1, linkCount: 6, aiAssisted: true),
        .init(id: "RUL-003", type: .rule, name: "AI 使用边界",
              summary: "默认关闭一切图像生成与画风模仿；文本 Agent 仅可整理、检查、草拟，产出须经作者确认。",
              status: .official, version: 4, linkCount: 2, aiAssisted: false),
    ]
}
