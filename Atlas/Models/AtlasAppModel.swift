import SwiftUI

enum AtlasDestination: String, CaseIterable, Identifiable {
    case discover = "星图"
    case profile = "个人主页"
    case worlds = "我的世界"
    case overview = "企划总览"
    case canvas = "World Canvas"
    case wiki = "Wiki"
    case assets = "资产库"
    case tasks = "活动与互动"
    case review = "审核队列"
    case publicPreview = "公开预览"
    case inbox = "收件箱"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .discover: return "sparkles"
        case .profile: return "person.crop.circle"
        case .worlds: return "square.stack.3d.up"
        case .overview: return "circle.grid.2x2"
        case .canvas: return "map"
        case .wiki: return "books.vertical"
        case .assets: return "square.stack"
        case .tasks: return "bolt.horizontal"
        case .review: return "checklist"
        case .publicPreview: return "rectangle.on.rectangle.angled"
        case .inbox: return "tray"
        }
    }

    var isProjectDestination: Bool {
        switch self {
        case .overview, .canvas, .wiki, .assets, .tasks, .review, .publicPreview:
            return true
        default:
            return false
        }
    }
}

enum ProjectAccessMode: String, CaseIterable, Identifiable {
    case participate = "参与"
    case manage = "管理"
    case publicPreview = "公开"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .participate: return "person.2"
        case .manage: return "slider.horizontal.3"
        case .publicPreview: return "eye"
        }
    }
}

/// 身份属于“用户 × 企划”，同一用户在不同企划中可以拥有不同身份。
enum ProjectRole: String, CaseIterable, Identifiable {
    case owner = "企主"
    case participant = "参企者"
    case visitor = "游客"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .owner: return "crown"
        case .participant: return "person.2"
        case .visitor: return "sparkles"
        }
    }

    var accessMode: ProjectAccessMode {
        switch self {
        case .owner: return .manage
        case .participant: return .participate
        case .visitor: return .publicPreview
        }
    }

    var landingDestination: AtlasDestination {
        .publicPreview
    }
}

enum AtlasSheet: String, Identifiable {
    case createWorld
    case submitWork
    case publish
    case application
    case newTask
    case objectEditor
    case characterCard
    case interactionInvite
    case publicPageEditor

    var id: String { rawValue }
}

enum WorldCreationStage {
    case story
    case map
}

enum WorldCollection: String {
    case managed = "我管理的世界"
    case joined = "我加入的世界"
}

enum AtlasContributionModule: String, CaseIterable, Codable {
    case writing = "文字"
    case illustration = "绘画"
    case video = "影像"
    case model3D = "3D"
    case craft = "手工"
    case music = "音乐"
    case program = "程序"
    case organization = "组织"
}

/// 一条可审计的企划内贡献记录。分数只在 `worldID` 内汇总，不进入用户的全局账户。
struct AtlasContributionEvent: Identifiable, Hashable {
    let id: String
    let worldID: String
    let userID: String
    let displayName: String
    let avatarSeed: Int
    let module: AtlasContributionModule
    let targetID: String
    let sequenceForTarget: Int
    let scalePoints: Double
    let completionPoints: Double
    let specialtyPoints: Double
    let bonusPoints: Double
    let isPolished: Bool
    let isSeasonal: Bool
    var isOwner = false
    var isVoided = false

    var score: Double {
        guard !isVoided else { return 0 }
        let coefficients = [1.0, 0.7, 0.5, 0.3]
        guard sequenceForTarget > 0, sequenceForTarget <= coefficients.count else { return 0 }
        let base = scalePoints + completionPoints + specialtyPoints
        let decayed = base * coefficients[sequenceForTarget - 1] + bonusPoints
        let polished = isPolished ? decayed * 1.5 : decayed
        return isSeasonal ? polished * 2 : polished
    }
}

struct AtlasProjectContributor: Identifiable, Hashable {
    let id: String
    let displayName: String
    let avatarSeed: Int
    let isOwner: Bool
    let score: Double
    let moduleScores: [AtlasContributionModule: Double]
}

struct AtlasWorld: Identifiable, Hashable {
    let id: String
    var name: String
    var hook: String
    var status: String
    var members: Int
    var progress: Double
    var symbol: String
}

struct AtlasTask: Identifiable {
    enum State: String {
        case open = "招募中"
        case active = "进行中"
        case settling = "结算中"
    }

    let id: String
    var title: String
    var summary: String
    var state: State
    var participants: Int
    var capacity: Int?
    var objectIDs: [String]
}

struct AtlasSubmission: Identifiable {
    enum State: String {
        case pending = "待审核"
        case shared = "共同确认"
        case revision = "待修改"
        case accepted = "Wiki 候选"
    }

    enum WikiChangeKind: String {
        case newEntry = "新增条目"
        case revision = "修改既有条目"
        case confirmedRelationship = "双方确认关系"
    }

    struct AuthorCredit: Identifiable, Hashable {
        let id: String
        var name: String
        var avatarSeed: Int
        var timestamp: String
        var order: Int

        init(name: String, avatarSeed: Int, timestamp: String, order: Int) {
            self.id = "\(name)-\(order)-\(timestamp)"
            self.name = name
            self.avatarSeed = avatarSeed
            self.timestamp = timestamp
            self.order = order
        }
    }

    let id: String
    var title: String
    var author: String
    var state: State
    var destination: String
    var affectedObjects: [String]
    var wikiObjectID: String?
    var wikiChangeKind: WikiChangeKind
    var authorCredits: [AuthorCredit]

    init(
        id: String,
        title: String,
        author: String,
        state: State,
        destination: String,
        affectedObjects: [String],
        wikiObjectID: String? = nil,
        wikiChangeKind: WikiChangeKind = .newEntry,
        authorCredits: [AuthorCredit]? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.state = state
        self.destination = destination
        self.affectedObjects = affectedObjects
        self.wikiObjectID = wikiObjectID
        self.wikiChangeKind = wikiChangeKind
        self.authorCredits = authorCredits ?? [
            AuthorCredit(name: author, avatarSeed: abs(author.hashValue % 9), timestamp: "提交时", order: 0)
        ]
    }
}

@MainActor
final class AtlasAppModel: ObservableObject {
    let currentUserID = "user-cen"
    @Published var selectedProfileUserID = "user-cen"
    @Published var destination: AtlasDestination = .discover
    @Published var accessMode: ProjectAccessMode = .participate
    @Published var activeWorldID = "mist-letters"
    @Published var selectedObjectID = "LOC-014"
    @Published var selectedTaskID: String?
    @Published var selectedCharacterID = "char-cen"
    @Published var activeSheet: AtlasSheet?
    @Published var toast: String?
    @Published var creationCompleted = false
    /// 正在创建世界：全屏进入空白地图编辑器（取代旧的引导仪式流）。
    @Published var creatingWorld = false
    @Published var creationStage: WorldCreationStage = .story
    @Published var worldCollection: WorldCollection = .managed
    @Published private(set) var savedMapJSONByWorldID: [String: String] = [:]
    @Published var joinedTaskIDs: Set<String> = []
    @Published private(set) var rolesByWorldID: [String: ProjectRole] = [
        "mist-letters": .owner,
        "ninth-station": .participant,
        "echo-chart": .visitor,
        "glasshouse": .participant,
        "aurora-archive": .visitor,
        "stellar-echo": .participant,
        "white-tower": .owner,
        "salt-beacon": .owner
    ]

    let worlds: [AtlasWorld] = [
        .init(id: "mist-letters", name: "雾海来信",
              hook: "潮汐带走声音，白塔保存远航记录。",
              status: "进行中", members: 24, progress: 0.76,
              symbol: "water.waves"),
        .init(id: "ninth-station", name: "第九车站",
              hook: "每晚 23:59，一班不存在的末班车准时进站。",
              status: "招募中", members: 19, progress: 0.54,
              symbol: "tram"),
        .init(id: "echo-chart", name: "回声测绘局",
              hook: "他们把无法被保存的声音绘制成地图。",
              status: "预热", members: 8, progress: 0.31,
              symbol: "waveform.path"),
        .init(id: "glasshouse", name: "灰烬温室",
              hook: "植物学家培育的不是花，而是春天这个概念。",
              status: "已结企", members: 36, progress: 1,
              symbol: "leaf"),
        .init(id: "aurora-archive", name: "极光档案",
              hook: "每一次记录，都是对抗遗忘。",
              status: "招募中", members: 27, progress: 0.42,
              symbol: "archivebox"),
        .init(id: "stellar-echo", name: "群星回声",
              hook: "漂流舰队收到三百年前的自己的回信。",
              status: "进行中", members: 41, progress: 0.68,
              symbol: "dot.radiowaves.left.and.right"),
        .init(id: "fog-continent", name: "雾海大陆",
              hook: "雾每七年退一次，露出上一纪元的城。",
              status: "招募中", members: 33, progress: 0.36,
              symbol: "mountain.2"),
        .init(id: "white-tower", name: "白塔灯塔守",
              hook: "灯塔守世代不得离塔，直到有人把灯熄了一夜。",
              status: "进行中", members: 22, progress: 0.72,
              symbol: "light.beacon.max"),
        .init(id: "silent-sea", name: "失声海域",
              hook: "海拿走声音，是为了替谁保守秘密。",
              status: "预热", members: 8, progress: 0.18,
              symbol: "water.waves"),
        .init(id: "night-watch", name: "夜航守望",
              hook: "瞭望员负责替整座城市做梦。",
              status: "招募中", members: 14, progress: 0.33,
              symbol: "moon.stars"),
        .init(id: "platform-lockers", name: "月台寄存处",
              hook: "每个寄存柜都存着一件没人敢取走的人生。",
              status: "预热", members: 5, progress: 0.14,
              symbol: "shippingbox"),
        .init(id: "salt-beacon", name: "盐与信标",
              hook: "灯塔之间用盐通信，咸度是坐标，也是遗言。",
              status: "已结企", members: 29, progress: 1,
              symbol: "light.beacon.min"),
        .init(id: "deep-scavenger", name: "深空拾荒者",
              hook: "打捞者从不问船是怎么沉的。",
              status: "招募中", members: 12, progress: 0.28,
              symbol: "sparkles"),
        .init(id: "albatross-post", name: "信天翁邮局",
              hook: "给不存在的人写信，退信率为零。",
              status: "进行中", members: 25, progress: 0.63,
              symbol: "envelope"),
        .init(id: "seventh-greenhouse", name: "第七温室",
              hook: "这里的雪只在每周三落下。",
              status: "预热", members: 6, progress: 0.21,
              symbol: "camera.macro"),
        .init(id: "unlit-city", name: "无灯之城",
              hook: "城里禁止一切光源，因为光会让人想起自己。",
              status: "招募中", members: 31, progress: 0.39,
              symbol: "building.2")
    ]

    @Published var tasks: [AtlasTask] = [
        .init(id: "task-night-watch", title: "夜航守望",
              summary: "在潮声退去前点亮全部白塔，结果将改变雾港开放状态。",
              state: .open, participants: 6, capacity: 8,
              objectIDs: ["LOC-014", "EVT-009"]),
        .init(id: "task-testimony", title: "雾港证词",
              summary: "收集居民对潮汐异常的口述片段。",
              state: .open, participants: 4, capacity: nil,
              objectIDs: ["LOC-014"]),
        .init(id: "task-proofread", title: "白塔共同校对",
              summary: "两名档案系角色共同确认远航记录差异。",
              state: .active, participants: 2, capacity: 2,
              objectIDs: ["CHR-027", "LOC-014"]),
        .init(id: "task-first-act", title: "潮汐回响第一幕",
              summary: "十二份参与者回应正在等待世界状态结算。",
              state: .settling, participants: 12, capacity: nil,
              objectIDs: ["EVT-009"])
    ]

    @Published var submissions: [AtlasSubmission] = [
        .init(id: "SUB-041", title: "第七页日志背面坐标", author: "岑",
              state: .pending, destination: "主线 Wiki",
              affectedObjects: ["雾港", "夜航路线", "伊莱"], wikiObjectID: "LOC-014",
              wikiChangeKind: .revision),
        .init(id: "SUB-042", title: "失声海域速写", author: "白昼",
              state: .pending, destination: "角色作品集",
              affectedObjects: ["失声海域"], wikiObjectID: nil,
              wikiChangeKind: .newEntry),
        .init(id: "SUB-043", title: "岑与伊莱：临时同盟", author: "岑 / 伊莱",
              state: .shared, destination: "角色关系",
              affectedObjects: ["岑", "伊莱", "夜航守望"], wikiObjectID: nil,
              wikiChangeKind: .confirmedRelationship,
              authorCredits: [
                .init(name: "岑", avatarSeed: 1, timestamp: "7 月 24 日 14:18 确认", order: 0),
                .init(name: "伊莱", avatarSeed: 2, timestamp: "7 月 24 日 15:02 确认", order: 1)
              ])
    ]
    /// 企主同意后直接成为企划 Wiki 的正式收录；拒绝项不会保留在企划侧。
    @Published private(set) var wikiSubmissions: [AtlasSubmission] = []
    @Published private(set) var addedWikiObjects: [WorldObject] = []
    @Published var characterApprovals: [CharacterApproval] = CharacterApproval.samples
    /// 已归档认证的企划在当前账号会话中永久只读；值为链上交易哈希。
    @Published private(set) var certifiedWorldHashes: [String: String] = [:]
    @Published var contributionEvents: [AtlasContributionEvent] = [
        .init(id: "C-MIST-001", worldID: "mist-letters", userID: "user-cen",
              displayName: "岑", avatarSeed: 1, module: .writing, targetID: "CHR-027",
              sequenceForTarget: 1, scalePoints: 3, completionPoints: 3,
              specialtyPoints: 1, bonusPoints: 2, isPolished: true, isSeasonal: false,
              isOwner: true),
        .init(id: "C-MIST-002", worldID: "mist-letters", userID: "user-daylight",
              displayName: "白昼", avatarSeed: 4, module: .illustration, targetID: "CHR-CEN",
              sequenceForTarget: 1, scalePoints: 3, completionPoints: 5,
              specialtyPoints: 0, bonusPoints: 1, isPolished: false, isSeasonal: false),
        .init(id: "C-MIST-003", worldID: "mist-letters", userID: "user-eli",
              displayName: "伊莱", avatarSeed: 2, module: .video, targetID: "EVT-009",
              sequenceForTarget: 1, scalePoints: 2, completionPoints: 3,
              specialtyPoints: 1, bonusPoints: 2, isPolished: false, isSeasonal: true),
        .init(id: "C-MIST-004", worldID: "mist-letters", userID: "user-linwu",
              displayName: "林雾", avatarSeed: 5, module: .music, targetID: "LOC-014",
              sequenceForTarget: 1, scalePoints: 2, completionPoints: 3,
              specialtyPoints: 0, bonusPoints: 2, isPolished: true, isSeasonal: false),
        .init(id: "C-MIST-005", worldID: "mist-letters", userID: "user-autumn",
              displayName: "秋庭", avatarSeed: 3, module: .illustration, targetID: "CHR-027",
              sequenceForTarget: 2, scalePoints: 3, completionPoints: 4,
              specialtyPoints: 0, bonusPoints: 1, isPolished: false, isSeasonal: false),
        .init(id: "C-MIST-006", worldID: "mist-letters", userID: "user-island",
              displayName: "岛屿", avatarSeed: 6, module: .program, targetID: "WORLD-MIST",
              sequenceForTarget: 1, scalePoints: 2, completionPoints: 2,
              specialtyPoints: 0, bonusPoints: 2, isPolished: false, isSeasonal: false),
        .init(id: "C-NINTH-001", worldID: "ninth-station", userID: "user-cen",
              displayName: "岑", avatarSeed: 1, module: .writing, targetID: "CHR-N09",
              sequenceForTarget: 1, scalePoints: 2, completionPoints: 2,
              specialtyPoints: 1, bonusPoints: 1, isPolished: false, isSeasonal: false)
    ]

    var activeWorld: AtlasWorld {
        worlds.first(where: { $0.id == activeWorldID }) ?? worlds[0]
    }

    var activeRole: ProjectRole {
        role(in: activeWorldID)
    }

    var activeContributionScore: Double {
        contributionScore(worldID: activeWorldID, userID: currentUserID)
    }

    func contributionScore(worldID: String, userID: String) -> Double {
        contributionEvents
            .filter { $0.worldID == worldID && $0.userID == userID }
            .reduce(0) { $0 + $1.score }
    }

    func profileIdentity(for userID: String) -> (name: String, avatarSeed: Int) {
        if userID == currentUserID { return ("岑", 1) }
        if let event = contributionEvents.first(where: { $0.userID == userID }) {
            return (event.displayName, event.avatarSeed)
        }
        return ("创作者", 0)
    }

    func openContributorProfile(_ userID: String) {
        selectedProfileUserID = userID
        destination = .profile
    }

    func openCurrentUserProfile() {
        selectedProfileUserID = currentUserID
        destination = .profile
    }

    func contributors(in worldID: String) -> [AtlasProjectContributor] {
        let grouped = Dictionary(grouping: contributionEvents.filter {
            $0.worldID == worldID && !$0.isVoided
        }, by: \.userID)

        var contributors: [AtlasProjectContributor] = grouped.compactMap { entry in
            let (userID, events) = entry
            guard let first = events.first else { return nil }
            let modules = Dictionary(grouping: events, by: \.module)
                .mapValues { $0.reduce(0) { $0 + $1.score } }
            return AtlasProjectContributor(
                id: userID,
                displayName: first.displayName,
                avatarSeed: first.avatarSeed,
                isOwner: events.contains(where: { $0.isOwner }),
                score: events.reduce(0) { $0 + $1.score },
                moduleScores: modules
            )
        }

        if !contributors.contains(where: { $0.isOwner }) {
            let owner = ownerIdentity(in: worldID)
            contributors.append(
                AtlasProjectContributor(
                    id: owner.id,
                    displayName: owner.name,
                    avatarSeed: owner.seed,
                    isOwner: true,
                    score: contributionScore(worldID: worldID, userID: owner.id),
                    moduleScores: [:]
                )
            )
        }

        return contributors
        .sorted {
            if $0.isOwner != $1.isOwner { return $0.isOwner }
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.displayName.localizedCompare($1.displayName) == .orderedAscending
        }
    }

    private func ownerIdentity(in worldID: String) -> (id: String, name: String, seed: Int) {
        if role(in: worldID) == .owner {
            return (currentUserID, "岑", 1)
        }
        switch worldID {
        case "ninth-station": return ("owner-nine", "站长", 7)
        case "glasshouse": return ("owner-glass", "温室记录员", 8)
        case "stellar-echo": return ("owner-stellar", "引航者", 9)
        default: return ("owner-\(worldID)", "企主", abs(worldID.hashValue) % 10)
        }
    }

    var isActiveWorldArchived: Bool {
        activeWorld.status == "已结企" || certifiedWorldHashes[activeWorld.id] != nil
    }

    var canWriteActiveWorld: Bool {
        !isActiveWorldArchived
    }

    func certifyWorld(_ worldID: String, transactionHash: String) {
        guard role(in: worldID) == .owner,
              worlds.first(where: { $0.id == worldID })?.status == "已结企" else { return }
        certifiedWorldHashes[worldID] = transactionHash
    }

    var selectedObject: WorldObject {
        allWikiObjects.first(where: { $0.id == selectedObjectID }) ?? WorldObject.samples[0]
    }

    var allWikiObjects: [WorldObject] {
        WorldObject.samples + addedWikiObjects
    }

    func wikiContributions(for objectID: String) -> [AtlasSubmission] {
        wikiSubmissions.filter { $0.wikiObjectID == objectID }
    }

    func wikiAuthorCredits(for objectID: String) -> [AtlasSubmission.AuthorCredit] {
        let contributions = wikiContributions(for: objectID)
        guard !contributions.isEmpty else {
            return [.init(name: "岑", avatarSeed: 1, timestamp: "原始档案", order: 0)]
        }

        var credits: [AtlasSubmission.AuthorCredit] = []
        for contribution in contributions {
            if contribution.wikiChangeKind == .revision,
               !credits.contains(where: { $0.name == "岑" }) {
                credits.append(.init(name: "岑", avatarSeed: 1, timestamp: "原始档案", order: -1))
            }
            for credit in contribution.authorCredits.sorted(by: { $0.order < $1.order })
            where !credits.contains(where: { $0.name == credit.name }) {
                credits.append(credit)
            }
        }
        return credits
    }

    func role(in worldID: String) -> ProjectRole {
        rolesByWorldID[worldID] ?? .visitor
    }

    func canAccess(_ destination: AtlasDestination) -> Bool {
        guard destination.isProjectDestination else { return true }
        switch activeRole {
        case .owner:
            return true
        case .participant:
            return destination != .review
        case .visitor:
            return destination == .publicPreview ||
                destination == .canvas ||
                destination == .wiki ||
                destination == .assets ||
                destination == .tasks
        }
    }

    func navigate(to destination: AtlasDestination) {
        guard canAccess(destination) else {
            showToast("当前企划身份无权访问该页面")
            self.destination = activeRole.landingDestination
            return
        }
        self.destination = destination
    }

    /// World Canvas 是所有企划身份的共同首入口；权限差异只体现在画布内部是否可编辑。
    func enterCanvas() {
        destination = .canvas
    }

    /// Opens an in-project destination from a cross-project surface such as Inbox.
    /// The active project and access mode must be resolved before the permission check.
    func openProject(worldID: String, destination target: AtlasDestination) {
        activeWorldID = worldID
        let resolvedRole = role(in: worldID)
        accessMode = isActiveWorldArchived ? .publicPreview : resolvedRole.accessMode
        let name = activeWorld.name

        guard canAccess(target) else {
            destination = resolvedRole.landingDestination
            showToast("已进入《\(name)》，当前身份无权访问该页面，已跳转公开预览")
            return
        }
        destination = target
        showToast("已进入《\(name)》· \(target.rawValue)")
    }

    func openWorld(_ world: AtlasWorld) {
        activeWorldID = world.id
        let resolvedRole = role(in: world.id)
        accessMode = world.status == "已结企" ? .publicPreview : resolvedRole.accessMode
        destination = .publicPreview
    }

    func returnToRoleExperience() {
        accessMode = isActiveWorldArchived ? .publicPreview : activeRole.accessMode
        destination = .publicPreview
    }

    func registerCreatedWorld(_ worldID: String) {
        rolesByWorldID[worldID] = .owner
    }

    func savedMapJSON(for worldID: String) -> String? {
        if let cached = savedMapJSONByWorldID[worldID] {
            return cached
        }
        guard let data = try? Data(contentsOf: mapFileURL(for: worldID)) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func saveMapJSON(_ json: String, for worldID: String) {
        guard !json.isEmpty else { return }
        savedMapJSONByWorldID[worldID] = json
        let url = mapFileURL(for: worldID)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? json.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    func beginWorldCreation() {
        creationStage = .story
        creatingWorld = true
    }

    func showWorldCollection(_ collection: WorldCollection) {
        worldCollection = collection
        let targetRole: ProjectRole = collection == .managed ? .owner : .participant
        if let firstWorld = worlds.first(where: { role(in: $0.id) == targetRole }) {
            activeWorldID = firstWorld.id
            accessMode = targetRole.accessMode
        }
        destination = .worlds
    }

    private func mapFileURL(for worldID: String) -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Atlas", isDirectory: true)
            .appendingPathComponent("Maps", isDirectory: true)
            .appendingPathComponent("\(worldID).json")
    }

    func joinTask(_ task: AtlasTask) {
        guard canWriteActiveWorld else {
            showToast("该企划已封存，不能再承接任务")
            return
        }
        joinedTaskIDs.insert(task.id)
        selectedTaskID = task.id
        showToast("已用当前角色加入「\(task.title)」")
    }

    func publishTask(title: String, summary: String, capacity: Int, objectIDs: [String]) {
        guard canWriteActiveWorld, activeRole == .owner else {
            showToast("当前状态不能发布任务")
            return
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanSummary.isEmpty else {
            showToast("请填写任务名称和说明")
            return
        }
        tasks.insert(
            AtlasTask(
                id: "task-\(UUID().uuidString.lowercased())",
                title: cleanTitle,
                summary: cleanSummary,
                state: .open,
                participants: 0,
                capacity: capacity,
                objectIDs: objectIDs
            ),
            at: 0
        )
        showToast("布告已贴到任务栏")
    }

    func review(_ submissionID: String, result: AtlasSubmission.State) {
        guard let index = submissions.firstIndex(where: { $0.id == submissionID }) else { return }
        submissions[index].state = result
        switch result {
        case .revision:
            showToast("已退回修改，并通知创作者补充说明")
        case .accepted:
            showToast("已进入 Wiki 候选，等待正式发布")
        default:
            showToast("审核状态已更新")
        }
    }

    func rejectSubmission(_ submissionID: String) {
        guard canWriteActiveWorld else {
            showToast("该企划已封存，审核操作已关闭")
            return
        }
        guard submissions.contains(where: { $0.id == submissionID }) else { return }
        submissions.removeAll { $0.id == submissionID }
        showToast("已拒绝；企划内不保留该提交")
    }

    func approveSubmission(_ submissionID: String) {
        guard canWriteActiveWorld else {
            showToast("该企划已封存，审核操作已关闭")
            return
        }
        guard let submission = submissions.first(where: { $0.id == submissionID }) else { return }
        var archived = submission
        if archived.wikiChangeKind == .revision {
            archived.wikiObjectID = archived.wikiObjectID ?? selectedObjectID
        } else {
            let prefix = archived.wikiChangeKind == .confirmedRelationship ? "REL" : "NEW"
            let objectID = "\(prefix)-\(String(format: "%03d", addedWikiObjects.count + 1))"
            let objectType: WorldObjectType =
                archived.wikiChangeKind == .confirmedRelationship ? .relationship : .work
            addedWikiObjects.append(
                WorldObject(
                    id: objectID,
                    type: objectType,
                    name: archived.title,
                    summary: archived.affectedObjects.isEmpty
                        ? archived.destination
                        : "关联：\(archived.affectedObjects.joined(separator: "、"))",
                    status: .official,
                    version: 1,
                    linkCount: archived.affectedObjects.count,
                    aiAssisted: false
                )
            )
            archived.wikiObjectID = objectID
            selectedObjectID = objectID
        }
        wikiSubmissions.append(archived)
        submissions.removeAll { $0.id == submissionID }
        showToast("已同意并写入 Wiki")
    }

    func approveCharacterInteraction(_ approvalID: String) {
        guard canWriteActiveWorld else {
            showToast("该企划已封存，互动确认已关闭")
            return
        }
        guard let approval = characterApprovals.first(where: { $0.id == approvalID }) else { return }
        var confirmedSubmission = approval.submission
        if let waitingIndex = confirmedSubmission.authorCredits.firstIndex(where: {
            $0.timestamp == "等待确认"
        }) {
            confirmedSubmission.authorCredits[waitingIndex].name = approval.characterName
            confirmedSubmission.authorCredits[waitingIndex].timestamp = "刚刚确认"
        }
        submissions.insert(confirmedSubmission, at: 0)
        characterApprovals.removeAll { $0.id == approvalID }
        showToast("角色确认已通过，内容进入企主审核")
    }

    func rejectCharacterInteraction(_ approvalID: String) {
        guard canWriteActiveWorld else {
            showToast("该企划已封存，互动确认已关闭")
            return
        }
        characterApprovals.removeAll { $0.id == approvalID }
        showToast("已拒绝该角色互动；不会写入企划记录")
    }

    func submitWorkForReview(_ submission: AtlasSubmission, requiresCharacterApproval: Bool) {
        guard canWriteActiveWorld else {
            showToast("该企划已封存，不能再提交作品")
            return
        }
        if requiresCharacterApproval {
            characterApprovals.insert(
                CharacterApproval(
                    id: "CHAR-REV-\(characterApprovals.count + 1)",
                    characterName: "伊莱",
                    requester: submission.author,
                    summary: submission.title,
                    permissionConcern: "涉及角色关系与共同经历，需要角色拥有者确认。",
                    submission: submission
                ),
                at: 0
            )
            showToast("已发送给关联角色拥有者确认")
        } else {
            submissions.insert(submission, at: 0)
            showToast("提交已进入企主审核")
        }
    }

    func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast == message { toast = nil }
        }
    }
}
