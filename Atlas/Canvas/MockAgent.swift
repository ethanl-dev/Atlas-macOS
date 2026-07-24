//
//  MockAgent.swift
//  本地模拟 Agent —— 只产文字组件卡，把交互链路跑通。
//  真实推理（端侧 Foundation Models / 云端）后续替换此文件，接口不变。
//  纪律：永远返回"卡"，永远文字，永远待作者确认。
//

import Foundation

enum MockAgent {

    static func card(for action: QuickAction, object: WorldObject) -> AgentCard {
        switch action.kind {
        case .inspiration: return inspiration(object)
        case .fill:        return fill(object, field: action.targetField ?? "字段")
        case .tidy:        return tidy(object)
        case .copywriting: return copywriting(object, field: action.targetField ?? "公开简介")
        case .review:      return review(object)
        case .conflict:    return conflictCard(object)
        }
    }

    static func freeform(text: String, object: WorldObject) -> AgentCard {
        AgentCard(
            kind: .inspiration,
            anchorObjectID: object.id,
            title: "关于「\(text)」",
            body: "围绕「\(object.name)」的几个方向，供你挑或改——我只提供线索，落不落笔你定。",
            options: [
                "把「\(text)」变成只有当地人知道的禁忌。",
                "让「\(text)」成为两个组织争夺的原因。",
                "把「\(text)」藏进一件会说谎的旧物里。",
            ]
        )
    }

    // MARK: 各类卡

    static func inspiration(_ o: WorldObject) -> AgentCard {
        AgentCard(
            kind: .inspiration,
            anchorObjectID: o.id,
            title: "给「\(o.name)」的三个 what-if",
            body: "选一个我就帮你落成便签；都不喜欢就扫掉，不留痕。",
            options: [
                "如果\(o.name)保存的记录会随潮汐悄悄篡改自己？",
                "如果只有失去声音的人才能真正进入\(o.name)？",
                "如果\(o.name)其实是某个更古老事物的复制品？",
            ]
        )
    }

    static func fill(_ o: WorldObject, field: String) -> AgentCard {
        AgentCard(
            kind: .fill,
            anchorObjectID: o.id,
            title: "为「\(o.name)」补：\(field)",
            body: "草案（采纳后进草稿字段，非正式设定）：\n需持有守林人许可，且在新月之夜由月纹兔引路，方可抵达深处；违者会被雾气引回入口。",
            targetField: field
        )
    }

    static func tidy(_ o: WorldObject) -> AgentCard {
        AgentCard(
            kind: .tidy,
            anchorObjectID: o.id,
            title: "整理「\(o.name)」的散记",
            body: "把零散便签归纳为：\n· 地理：终年薄雾、荧光孢子\n· 机制：树木保存声音、夜里复述\n· 门禁：守林人许可制\n采纳后作为草稿结构存入。"
        )
    }

    static func copywriting(_ o: WorldObject, field: String) -> AgentCard {
        AgentCard(
            kind: .copywriting,
            anchorObjectID: o.id,
            title: "把「\(o.name)」写成招募语言",
            body: "在这里，森林会记住每一个经过者的声音。若你愿意成为守林人，请先学会倾听雾。——采纳后进公开页草稿。",
            targetField: field
        )
    }

    static func review(_ o: WorldObject) -> AgentCard {
        AgentCard(
            kind: .review,
            anchorObjectID: o.id,
            title: "「\(o.name)」的审核问题清单",
            body: "1. 与森林议会的关系是否已获设主确认？\n2. “自动补全的旧地图”是否触及世界级设定，需主催批准？\n3. 当前目标与既有事件线是否冲突？"
        )
    }

    static func conflictCard(_ o: WorldObject) -> AgentCard {
        AgentCard(
            kind: .conflict,
            anchorObjectID: o.id,
            title: "「\(o.name)」的设定冲突",
            body: "检测到：本对象的时间点晚于事件「夜航守望」设定的开放时间。\n建议：调整其一，或标注为有意的时间悖论。采纳后我把此判断存为草稿备注。"
        )
    }
}
