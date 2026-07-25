import Foundation

struct AtlasCharacterProfile: Identifiable, Hashable {
    struct Permission: Identifiable, Hashable {
        enum State: String { case allowed = "允许", confirm = "需确认", forbidden = "禁止" }
        let id = UUID()
        var title: String
        var state: State
    }

    let id: String
    var name: String
    var owner: String
    var role: String
    var location: String
    var organization: String
    var summary: String
    var symbol: String
    var dos: [String]
    var donts: [String]
    var permissions: [Permission]

    static let samples: [AtlasCharacterProfile] = [
        .init(
            id: "char-cen", name: "岑", owner: "@cen", role: "档案修复师",
            location: "雾港 · 白塔档案室", organization: "白塔邮政局",
            summary: "负责修复被潮水浸没的远航记录，对失声海域中反复出现的坐标保持警惕。",
            symbol: "doc.text.magnifyingglass",
            dos: ["档案调查、共同解谜与日常互动", "可以引用公开的远航记录", "可以邀请参与非致命冲突"],
            donts: ["未经确认改变失声经历", "代写角色的关键立场选择", "建立永久关系或造成不可逆伤害"],
            permissions: [
                .init(title: "二次创作", state: .allowed),
                .init(title: "肢体接触", state: .confirm),
                .init(title: "剧情代入", state: .allowed),
                .init(title: "永久关系", state: .confirm)
            ]
        ),
        .init(
            id: "char-elai", name: "伊莱", owner: "@daylight", role: "夜航领航员",
            location: "第七码头", organization: "夜航守望",
            summary: "能从鲸歌里辨认旧航线，但从不解释自己为什么知道那些已经消失的地名。",
            symbol: "sailboat",
            dos: ["航海、调查、争论与临时合作", "允许描写公开能力", "欢迎围绕旧航线递交互动"],
            donts: ["揭示身世真相", "替角色承诺阵营立场", "未经确认描写重伤或死亡"],
            permissions: [
                .init(title: "二次创作", state: .allowed),
                .init(title: "肢体接触", state: .confirm),
                .init(title: "剧情代入", state: .confirm),
                .init(title: "致命冲突", state: .forbidden)
            ]
        ),
        .init(
            id: "char-lin", name: "林语", owner: "@forest", role: "潮汐研究员",
            location: "瞭望塔 · 档案室", organization: "回声测绘局",
            summary: "记录稳定元素在雾海中的分布，并怀疑白塔隐瞒了第一次远航的真实年份。",
            symbol: "waveform.path.ecg",
            dos: ["研究协作、样本交换与公开辩论", "可以共同撰写调查报告"],
            donts: ["篡改研究结论", "越过作者决定情感关系"],
            permissions: [
                .init(title: "二次创作", state: .allowed),
                .init(title: "共同研究", state: .allowed),
                .init(title: "情感关系", state: .confirm)
            ]
        ),
        .init(
            id: "char-daylight", name: "白昼", owner: "@daylight", role: "外来调查者",
            location: "第七码头", organization: "自由调查组",
            summary: "从企划外部来到雾港，正在追查一批从未抵达收件人的旧信，并把每次退潮当作重新校准线索的机会。",
            symbol: "magnifyingglass",
            dos: ["共同调查公开线索与城市传闻", "允许描写一般行动与非致命冲突", "欢迎邀请参与短期合作"],
            donts: ["替角色确认最终归属", "未经确认公开私人调查笔记", "造成永久伤害或强制阵营变化"],
            permissions: [
                .init(title: "二次创作", state: .allowed),
                .init(title: "剧情代入", state: .allowed),
                .init(title: "阵营变化", state: .confirm),
                .init(title: "永久伤害", state: .forbidden)
            ]
        ),
        .init(
            id: "char-afra", name: "阿芙拉", owner: "@northwind", role: "雾海信使",
            location: "北岸灯塔", organization: "潮间邮路",
            summary: "沿着只在低潮时出现的邮路送信，熟悉雾海中每一处短暂显露的礁石，却拒绝谈论自己从哪里取得收件地址。",
            symbol: "envelope",
            dos: ["送信、航路协作与公开场景互动", "允许引用公开携带的信件", "欢迎围绕北岸展开短篇创作"],
            donts: ["拆阅未公开信件内容", "替角色决定真实出身", "未经确认建立永久亲密关系"],
            permissions: [
                .init(title: "二次创作", state: .allowed),
                .init(title: "信件引用", state: .confirm),
                .init(title: "剧情代入", state: .allowed),
                .init(title: "永久关系", state: .confirm)
            ]
        )
    ]
}

struct InteractionVenue: Identifiable, Hashable {
    let id: String
    var name: String
    var subtitle: String
    var rule: String
    var hook: String
    var symbol: String
    var activeCount: Int

    static let samples: [InteractionVenue] = [
        .init(id: "tavern", name: "潮声酒馆", subtitle: "自由闲聊与角色社交", rule: "请以角色行动回应，并留下至少一个可回应点。", hook: "第一杯免费，第二杯开始要用故事交换。", symbol: "mug", activeCount: 12),
        .init(id: "plaza", name: "中央广场", subtitle: "公告与公共交流", rule: "公共事件和开放互动优先在这里发生。", hook: "钟声响起时，人群同时望向了白塔。", symbol: "building.columns", activeCount: 8),
        .init(id: "forest", name: "失声海岸", subtitle: "隐秘情报与暗线交流", rule: "只有获得潮汐通行证的角色可以深入海岸。", hook: "退潮后，沙滩上多出一串没有来路的脚印。", symbol: "water.waves", activeCount: 5),
        .init(id: "market", name: "委托布告板", subtitle: "任务承接与合作招募", rule: "委托必须注明目标、截止时间和可回应方式。", hook: "一张没有署名的委托正在渗出海水。", symbol: "pin", activeCount: 6),
        .init(id: "tower", name: "瞭望塔", subtitle: "探索报告与情报汇总", rule: "报告需标明样本来源，推测与事实分开记录。", hook: "今晚的极光比航海日志记载早了七分钟。", symbol: "binoculars", activeCount: 3),
        .init(id: "docks", name: "第七码头", subtitle: "新人报到与航线集结", rule: "新人可在此登记角色并领取第一条互动线索。", hook: "一艘没有船名的邮船申请靠岸。", symbol: "ferry", activeCount: 7)
    ]
}

struct VenuePost: Identifiable, Hashable {
    let id: String
    var venueID: String
    var author: String
    var characterID: String
    var title: String
    var body: String
    var hook: String
    var replies: Int
    var featured: Bool

    static let samples: [VenuePost] = [
        .init(id: "post-1", venueID: "tavern", author: "酒保 NPC", characterID: "char-elai", title: "今晚特调：北境霜焰", body: "酒保仍在擦同一只玻璃杯。他说第一杯免费，但下一杯必须用一段没人听过的故事来换。", hook: "坐到吧台前，讲一个故事；或者询问昨夜来过的戴兜帽客人。", replies: 14, featured: true),
        .init(id: "post-1b", venueID: "tavern", author: "岑", characterID: "char-cen", title: "1 号桌 · 夜航队临时集结", body: "墙角那张被磨得发亮的桌子已经空出了两个座位。桌面的每一道刻痕都代表一次有人受伤的远航。", hook: "坐下来自我介绍，或拿出你发现的异常航线。", replies: 7, featured: true),
        .init(id: "post-2", venueID: "plaza", author: "企划管理", characterID: "char-cen", title: "白塔封锁临时公告", body: "潮汐异常期间，白塔上层暂停开放。已有档案修复师在入口处记录目击证词。", hook: "提交你的角色目击到的异常，或质疑封锁理由。", replies: 9, featured: true),
        .init(id: "post-3", venueID: "forest", author: "伊莱", characterID: "char-elai", title: "失声海岸的旧坐标", body: "伊莱把一张浸水航图压在礁石上，图上的坐标指向现在不存在的岛。", hook: "带一件能证明旧岛存在的物品来交换信息。", replies: 6, featured: false)
        ,.init(id: "post-4", venueID: "market", author: "白昼", characterID: "char-elai", title: "委托 #001 · 完善鲸歌航路", body: "需要整理三段旧鲸歌与现行航线的对应关系，可两人合作完成。", hook: "回帖认领委托，或提交一段你听见的鲸歌。", replies: 4, featured: true)
        ,.init(id: "post-5", venueID: "tower", author: "林语", characterID: "char-lin", title: "稳定元素分布报告", body: "样本浓度沿旧河道递减。这意味着失声海域可能并非自然形成。", hook: "携带地质或生物样本来档案室交叉比对。", replies: 12, featured: true)
        ,.init(id: "post-6", venueID: "docks", author: "企划管理", characterID: "char-cen", title: "第七码头 · 新人登记台", body: "请留下角色名、职业、一句话介绍，以及希望参与的互动类型。", hook: "新人登记；老成员可以在回复中向新人递出第一条互动。", replies: 22, featured: true)
    ]
}

struct ForumReply: Identifiable, Hashable {
    let id: String
    var postID: String
    var author: String
    var characterID: String
    var body: String
    var time: String

    static let samples: [ForumReply] = [
        .init(id: "reply-1", postID: "post-1", author: "岑", characterID: "char-cen", body: "[岑] @ 吧台前：把一封没有落款的信推到酒保面前。“昨晚送来这封信的人，也喝了这杯酒吗？”", time: "1 小时前"),
        .init(id: "reply-2", postID: "post-1", author: "酒保 NPC", characterID: "char-elai", body: "[酒保] @ 吧台后：倒酒的手没有停。“先讲你的故事，然后我再决定回答多少。”", time: "58 分钟前"),
        .init(id: "reply-3", postID: "post-2", author: "林语", characterID: "char-lin", body: "[林语] @ 公告板前：封锁前七分钟，我在上层记录到了不属于潮汐的震动。", time: "昨天"),
        .init(id: "reply-4", postID: "post-5", author: "伊莱", characterID: "char-elai", body: "[伊莱] @ 瞭望塔楼梯口：我有一块从旧航线带回来的结晶，也许能作为第四个样本。", time: "5 小时前")
    ]
}

struct CharacterApproval: Identifiable {
    let id: String
    var characterName: String
    var requester: String
    var summary: String
    var permissionConcern: String
    var submission: AtlasSubmission

    static let samples: [CharacterApproval] = [
        .init(
            id: "CHAR-REV-1", characterName: "岑", requester: "白昼",
            summary: "临时同盟：第七码头的交换",
            permissionConcern: "作品建立了临时同盟关系，符合公开互动范围，但需要你确认岑的关键回应。",
            submission: .init(
                id: "SUB-CHAR-1",
                title: "第七码头的交换",
                author: "白昼 / 岑",
                state: .pending,
                destination: "角色共同经历",
                affectedObjects: ["岑", "伊莱", "第七码头"],
                wikiObjectID: nil,
                wikiChangeKind: .confirmedRelationship,
                authorCredits: [
                    .init(name: "白昼", avatarSeed: 3, timestamp: "7 月 24 日 15:12 确认", order: 0),
                    .init(name: "岑", avatarSeed: 1, timestamp: "等待确认", order: 1)
                ]
            )
        )
    ]
}
