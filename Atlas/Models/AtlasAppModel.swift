import SwiftUI

enum AtlasDestination: String, CaseIterable, Identifiable {
    case discover = "星图"
    case worlds = "我的世界"
    case overview = "企划总览"
    case canvas = "World Canvas"
    case wiki = "Wiki"
    case assets = "资产库"
    case tasks = "任务与互动"
    case review = "审核队列"
    case publicPreview = "公开预览"
    case inbox = "收件箱"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .discover: return "sparkles"
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

enum AtlasSheet: String, Identifiable {
    case createWorld
    case submitWork
    case publish
    case application
    case newTask
    case objectEditor

    var id: String { rawValue }
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

    let id: String
    var title: String
    var author: String
    var state: State
    var destination: String
    var affectedObjects: [String]
}

@MainActor
final class AtlasAppModel: ObservableObject {
    @Published var destination: AtlasDestination = .discover
    @Published var accessMode: ProjectAccessMode = .participate
    @Published var activeWorldID = "mist-letters"
    @Published var selectedObjectID = "LOC-014"
    @Published var selectedTaskID: String?
    @Published var activeSheet: AtlasSheet?
    @Published var toast: String?
    @Published var creationCompleted = false
    @Published var joinedTaskIDs: Set<String> = []

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

    let tasks: [AtlasTask] = [
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
              affectedObjects: ["雾港", "夜航路线", "伊莱"]),
        .init(id: "SUB-042", title: "失声海域速写", author: "白昼",
              state: .pending, destination: "角色作品集",
              affectedObjects: ["失声海域"]),
        .init(id: "SUB-043", title: "岑与伊莱：临时同盟", author: "岑 / 伊莱",
              state: .shared, destination: "角色关系",
              affectedObjects: ["岑", "伊莱", "夜航守望"])
    ]

    var activeWorld: AtlasWorld {
        worlds.first(where: { $0.id == activeWorldID }) ?? worlds[0]
    }

    var selectedObject: WorldObject {
        WorldObject.samples.first(where: { $0.id == selectedObjectID }) ?? WorldObject.samples[0]
    }

    func openWorld(_ world: AtlasWorld, mode: ProjectAccessMode = .participate) {
        activeWorldID = world.id
        accessMode = mode
        destination = .overview
    }

    func switchMode(_ mode: ProjectAccessMode) {
        accessMode = mode
        if mode == .publicPreview {
            destination = .publicPreview
        } else if mode == .participate && destination == .review {
            destination = .overview
        } else if destination == .publicPreview {
            destination = .overview
        }
    }

    func joinTask(_ task: AtlasTask) {
        joinedTaskIDs.insert(task.id)
        selectedTaskID = task.id
        showToast("已用当前角色加入「\(task.title)」")
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

    func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast == message { toast = nil }
        }
    }
}
