//
//  LinkModel.swift
//  对象间关联（link）的数据模型与语义规则。
//
//  设计原则（对应《Atlas 卡片字段规格》第 5 节）：
//  link 的语义不由用户从长列表里挑，而由「所在字段 + 两端类型」承担，分三层：
//   1. 结构性 link —— 语义由字段决定，自动，不问用户（阵营归属 → 隶属）。
//   2. 关系性 link —— 自动给大类，用户补一个子标签（关系网 → 盟友/敌对/…）。
//   3. 自由 link   —— 正文里 @ 提及，仅弱关联，不带强语义（此文件不含，属正文编辑器）。
//
//  黑白单色约束：link 不靠颜色区分，靠 目标对象的 SF Symbol + 文案。
//

import SwiftUI
import Observation

// MARK: - 链接字段定义（每种对象类型暴露哪些「关联槽」）

struct LinkFieldDef: Identifiable, Hashable {
    /// 字段名在同一类型内唯一，直接作为稳定 id（避免每次生成新 UUID 破坏 ForEach 身份）。
    var id: String { key }
    /// 字段名，如「阵营归属」
    var key: String
    /// 该槽接受哪些目标类型
    var accepts: [WorldObjectType]
    /// 自动语义（结构性 link 直接采用；关系性 link 作为大类）
    var semantic: String
    /// 非空即为「关系性 link」：选定目标后需要补一个子标签
    var relationalTags: [String]
    /// 该字段属于哪一分层可见层（对应规格 0.1）
    var layer: LinkLayer

    var isRelational: Bool { !relationalTags.isEmpty }

    /// 「+ 关联X」按钮里的 X 文案
    var acceptLabel: String {
        accepts.map { $0.rawValue }.joined(separator: " / ")
    }
}

enum LinkLayer: String {
    case pub    = "公开"
    case reveal = "揭示"
    case truth  = "真相"

    /// 分层可见的锁标记图标（🔓/🔒 的 SF Symbol 版）
    var symbol: String? {
        switch self {
        case .pub:    return nil
        case .reveal: return "lock.open"
        case .truth:  return "lock"
        }
    }
}

// MARK: - 一条关联实例

struct WorldLink: Identifiable, Hashable {
    let id = UUID()
    /// 起点对象
    var sourceID: String
    /// 所在字段名
    var fieldKey: String
    /// 目标对象
    var targetID: String
    /// 关系性 link 的子标签（结构性为 nil）
    var subtag: String? = nil
}

// MARK: - 字段规则表（按真实 WorldObjectType 落地）
//  说明：模型枚举里没有独立的「地图 / 便签」类型，故位置→地图暂以 world 承载，
//  便签保持纯文本、无关联槽。等类型枚举扩展后再补。

enum LinkRules {
    static func fields(for type: WorldObjectType) -> [LinkFieldDef] {
        switch type {
        case .character:
            return [
                .init(key: "阵营归属", accepts: [.organization], semantic: "隶属",
                      relationalTags: [], layer: .pub),
                .init(key: "能力边界", accepts: [.rule], semantic: "受约束",
                      relationalTags: [], layer: .pub),
                .init(key: "关系网", accepts: [.character], semantic: "人际",
                      relationalTags: ["盟友", "敌对", "师徒", "亲属"], layer: .reveal),
            ]
        case .location:
            return [
                .init(key: "所属世界", accepts: [.world], semantic: "定位于",
                      relationalTags: [], layer: .pub),
                .init(key: "关联", accepts: [.organization, .event], semantic: "掌控 / 发生地",
                      relationalTags: [], layer: .pub),
            ]
        case .organization:
            return [
                .init(key: "对外关系", accepts: [.organization], semantic: "势力关系",
                      relationalTags: ["对抗", "协作", "中立"], layer: .reveal),
            ]
        case .event:
            return [
                .init(key: "涉及角色", accepts: [.character], semantic: "卷入",
                      relationalTags: [], layer: .pub),
                .init(key: "触发地点", accepts: [.location], semantic: "发生于",
                      relationalTags: [], layer: .pub),
            ]
        case .artifact:
            return [
                .init(key: "载体逻辑", accepts: [.rule], semantic: "遵循",
                      relationalTags: [], layer: .pub),
                .init(key: "归属", accepts: [.character, .organization], semantic: "持有于",
                      relationalTags: [], layer: .reveal),
            ]
        case .work:
            return [
                .init(key: "关联世界", accepts: [.location, .event, .character], semantic: "关于",
                      relationalTags: [], layer: .pub),
            ]
        case .world, .rule:
            return []
        }
    }
}

// MARK: - 关联存储（跨对象，画布内共享）

@Observable
final class LinkStore {
    /// sourceID → 该对象的所有关联
    private(set) var links: [String: [WorldLink]] = [:]

    func links(for sourceID: String, field: String) -> [WorldLink] {
        (links[sourceID] ?? []).filter { $0.fieldKey == field }
    }

    /// 某对象是否已在该字段关联了目标（避免重复）
    func isLinked(source: String, field: String, target: String) -> Bool {
        links(for: source, field: field).contains { $0.targetID == target }
    }

    @discardableResult
    func add(source: String, field: String, target: String, subtag: String? = nil) -> Bool {
        guard !isLinked(source: source, field: field, target: target) else { return false }
        links[source, default: []].append(
            WorldLink(sourceID: source, fieldKey: field, targetID: target, subtag: subtag)
        )
        return true
    }

    func remove(_ link: WorldLink) {
        links[link.sourceID]?.removeAll { $0.id == link.id }
    }

    /// 对象总关联数（用于卡片 meta 行的 linkCount 实时化）
    func count(for sourceID: String) -> Int {
        links[sourceID]?.count ?? 0
    }
}
