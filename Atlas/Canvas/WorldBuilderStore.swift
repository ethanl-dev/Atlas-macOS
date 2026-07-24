import SwiftUI

//
//  WorldBuilderStore —— 创建世界画布的数据核心。
//
//  依据 03《World Canvas 元素体系》：画布不是"地图编辑器"，而是三层结构——
//  底盘（地图/关系/时间线，参照层）+ 一等世界对象（作者主权区）+ 工作层。
//  创建者从左侧组件库把"地点/角色/组织/事件/规则/物件/作品/便签"放上画布，
//  点击任意对象进入可编辑的详情卡。地图只是底盘之一。
//

// MARK: - 对象类型（组件库里的 kit）

enum BuilderKind: String, CaseIterable, Identifiable {
    case location, character, org, event, rule, item, work, note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location: return "地点"
        case .character: return "角色"
        case .org: return "组织"
        case .event: return "事件"
        case .rule: return "规则"
        case .item: return "物件"
        case .work: return "作品"
        case .note: return "便签"
        }
    }

    var symbol: String {
        switch self {
        case .location: return "mappin.and.ellipse"
        case .character: return "person.fill"
        case .org: return "building.2.fill"
        case .event: return "bolt.fill"
        case .rule: return "checkmark.shield.fill"
        case .item: return "shippingbox.fill"
        case .work: return "photo.artframe"
        case .note: return "note.text"
        }
    }

    /// 类型 = 形状（黑白系统不靠颜色，靠形状 + 图标）。
    var shape: BuilderShape {
        switch self {
        case .location: return .pin
        case .character: return .circle
        case .org: return .hexagon
        case .event: return .diamond
        case .rule, .item, .work: return .square
        case .note: return .note
        }
    }

    /// 是否空间对象（钉在画布坐标）。规则/物件/作品是非空间对象，但骨架阶段也允许落位。
    var isSpatial: Bool {
        switch self {
        case .rule, .item, .work: return false
        default: return true
        }
    }

    var hint: String {
        switch self {
        case .location: return "钉在坐标的地方"
        case .character: return "可驻留在地点的人"
        case .org: return "势力、阵营或组织"
        case .event: return "跨地点、有时间"
        case .rule: return "世界的规则与边界"
        case .item: return "关键物件"
        case .work: return "作品与素材"
        case .note: return "自由文本便签"
        }
    }
}

enum BuilderShape { case pin, circle, hexagon, diamond, square, note }

enum BuilderStatus: String, CaseIterable, Identifiable {
    case draft = "草稿"
    case official = "正式"
    var id: String { rawValue }
}

// MARK: - 世界对象

struct BuilderObject: Identifiable {
    let id: String
    var kind: BuilderKind
    var name: String
    var summary: String
    var status: BuilderStatus
    var position: CGPoint      // 画布世界坐标
    var aiAssisted: Bool = false
}

// MARK: - 关系线

struct BuilderRelation: Identifiable {
    let id: String
    var sourceID: String
    var targetID: String
    var label: String
}

// MARK: - 投影模式（同一批对象的三种排布，不是三块画布）

enum BuilderProjection: String, CaseIterable, Identifiable {
    case map = "地图"
    case relation = "关系"
    case timeline = "时间线"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .map: return "map"
        case .relation: return "point.3.connected.trianglepath.dotted"
        case .timeline: return "calendar.day.timeline.left"
        }
    }
}

// MARK: - Store

@MainActor
final class WorldBuilderStore: ObservableObject {
    @Published var worldName: String
    @Published var objects: [BuilderObject]
    @Published var relations: [BuilderRelation] = []
    @Published var selectedID: String?
    @Published var projection: BuilderProjection = .map
    @Published var showMapBase = true       // 地图底盘开关
    @Published var mapMade = false          // 是否已经绘制过地图底盘
    @Published var saved = true

    private var counter = 0

    init(worldName: String = "未命名世界", seeded: Bool = false) {
        self.worldName = worldName
        if seeded {
            self.objects = [
                .init(id: "loc-seed", kind: .location, name: "雾港",
                      summary: "声音会在退潮时被海水带走。", status: .draft,
                      position: CGPoint(x: 520, y: 360)),
                .init(id: "chr-seed", kind: .character, name: "守望者·岑",
                      summary: "白塔档案室的守夜人。", status: .draft,
                      position: CGPoint(x: 760, y: 300)),
                .init(id: "evt-seed", kind: .event, name: "夜航守望",
                      summary: "参与者的回应决定雾港是否开放。", status: .draft,
                      position: CGPoint(x: 620, y: 560))
            ]
        } else {
            self.objects = []
        }
    }

    var selected: BuilderObject? {
        guard let id = selectedID else { return nil }
        return objects.first { $0.id == id }
    }

    func binding(for id: String) -> Binding<BuilderObject>? {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.objects[index] },
            set: { self.objects[index] = $0; self.saved = false }
        )
    }

    @discardableResult
    func add(_ kind: BuilderKind, at position: CGPoint) -> String {
        counter += 1
        let id = "\(kind.rawValue)-\(counter)-\(Int(Date().timeIntervalSince1970))"
        let object = BuilderObject(
            id: id, kind: kind, name: "",
            summary: "", status: .draft, position: position
        )
        objects.append(object)
        selectedID = id
        saved = false
        return id
    }

    func move(_ id: String, to position: CGPoint) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        objects[index].position = position
        saved = false
    }

    func delete(_ id: String) {
        objects.removeAll { $0.id == id }
        relations.removeAll { $0.sourceID == id || $0.targetID == id }
        if selectedID == id { selectedID = nil }
        saved = false
    }

    func displayName(_ object: BuilderObject) -> String {
        object.name.trimmingCharacters(in: .whitespaces).isEmpty ? "未命名\(object.kind.title)" : object.name
    }
}
