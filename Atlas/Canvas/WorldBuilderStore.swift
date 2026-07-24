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
    case map, location, character, org, event, rule, item, work, note

    var id: String { rawValue }

    /// 右键新建菜单里展示的顺序（地图排最前，因为它是特殊的底盘卡）。
    static var creatable: [BuilderKind] { allCases }

    var title: String {
        switch self {
        case .map: return "地图"
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
        case .map: return "map.fill"
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

    /// 类型 = 形状（黑白系统不靠颜色，靠形状 + 图标）。详情卡头部用。
    var shape: BuilderShape {
        switch self {
        case .location: return .pin
        case .character: return .circle
        case .org: return .hexagon
        case .event: return .diamond
        case .map, .rule, .item, .work: return .square
        case .note: return .note
        }
    }

    var hint: String {
        switch self {
        case .map: return "世界底盘的预览"
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

    /// 每类卡片的默认尺寸。地图卡是预览视图，天生大一些。
    var defaultSize: CGSize {
        switch self {
        case .map:       return CGSize(width: 360, height: 250)
        case .character: return CGSize(width: 220, height: 150)
        case .note:      return CGSize(width: 200, height: 130)
        default:         return CGSize(width: 240, height: 150)
        }
    }

    var minSize: CGSize {
        switch self {
        case .map: return CGSize(width: 240, height: 165)
        default:   return CGSize(width: 150, height: 96)
        }
    }
}

enum BuilderShape { case pin, circle, hexagon, diamond, square, note }

// MARK: - 世界对象

struct BuilderObject: Identifiable {
    let id: String
    var kind: BuilderKind
    var name: String
    var summary: String
    var position: CGPoint      // 画布世界坐标（卡片中心）
    var size: CGSize           // 卡片尺寸（世界坐标，可拉角改变）
    var aiAssisted: Bool = false
}

// MARK: - 关系线

struct BuilderRelation: Identifiable {
    let id: String
    var sourceID: String
    var targetID: String
    var label: String
    /// 关联所在的字段名（结构性 link 的语义锚点）；正文 @ 提及用 "提及"。
    var fieldKey: String = ""
    /// 关系性 link 的子标签（盟友/敌对/对抗…），结构性为 nil。
    var subtag: String? = nil
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
    @Published var selectedIDs: Set<String> = []
    @Published var projection: BuilderProjection = .map

    /// 单选便捷入口：恰好选中一个时返回它，否则 nil（详情卡只在单选时出现）。
    var selectedID: String? {
        get { selectedIDs.count == 1 ? selectedIDs.first : nil }
        set { selectedIDs = newValue.map { [$0] } ?? [] }
    }

    private var groupDragAnchors: [String: CGPoint]?
    @Published var showMapBase = false      // 全画布地图底盘 underlay（地图现在主要以卡片存在，默认关）
    @Published var mapMade = false          // 是否已经绘制过地图底盘
    @Published var saved = true

    private var counter = 0

    init(worldName: String = "未命名世界", seeded: Bool = false) {
        self.worldName = worldName
        if seeded {
            self.objects = [
                .init(id: "map-seed", kind: .map, name: "世界底盘",
                      summary: "",
                      position: CGPoint(x: 470, y: 330), size: BuilderKind.map.defaultSize),
                .init(id: "loc-seed", kind: .location, name: "雾港",
                      summary: "声音会在退潮时被海水带走。",
                      position: CGPoint(x: 780, y: 250), size: BuilderKind.location.defaultSize),
                .init(id: "chr-seed", kind: .character, name: "守望者·岑",
                      summary: "白塔档案室的守夜人。",
                      position: CGPoint(x: 800, y: 470), size: BuilderKind.character.defaultSize)
            ]
            self.mapMade = true
        } else {
            self.objects = []
        }
    }

    var selected: BuilderObject? {
        guard let id = selectedID else { return nil }
        return objects.first { $0.id == id }
    }

    func binding(for id: String) -> Binding<BuilderObject>? {
        guard objects.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: {
                self.objects.first(where: { $0.id == id }) ?? BuilderObject(
                    id: id, kind: .note, name: "", summary: "",
                    position: .zero, size: .zero
                )
            },
            set: {
                if let index = self.objects.firstIndex(where: { $0.id == id }) {
                    self.objects[index] = $0
                    self.saved = false
                }
            }
        )
    }

    @discardableResult
    func add(_ kind: BuilderKind, at position: CGPoint) -> String {
        counter += 1
        let id = "\(kind.rawValue)-\(counter)-\(Int(Date().timeIntervalSince1970))"
        let object = BuilderObject(
            id: id, kind: kind, name: "",
            summary: "", position: position, size: kind.defaultSize
        )
        objects.append(object)
        if kind == .map { mapMade = true }
        selectedID = id
        saved = false
        return id
    }

    func move(_ id: String, to position: CGPoint) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        objects[index].position = position
        saved = false
    }

    func resize(_ id: String, size: CGSize, center: CGPoint) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        objects[index].size = size
        objects[index].position = center
        saved = false
    }

    func bringToFront(_ id: String) {
        guard let index = objects.firstIndex(where: { $0.id == id }), index != objects.count - 1 else { return }
        let object = objects.remove(at: index)
        objects.append(object)
    }

    func delete(_ id: String) {
        objects.removeAll { $0.id == id }
        relations.removeAll { $0.sourceID == id || $0.targetID == id }
        selectedIDs.remove(id)
        saved = false
    }

    // MARK: - 选择

    func selectOnly(_ id: String) { selectedIDs = [id] }
    func toggle(_ id: String) { if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) } }
    func clearSelection() { selectedIDs = [] }

    /// 框选：选中中心落在矩形内、或与矩形相交的卡片（世界坐标）。
    func selectInRect(_ rect: CGRect, additive: Bool) {
        let hits = objects.filter { obj in
            let frame = CGRect(x: obj.position.x - obj.size.width / 2,
                               y: obj.position.y - obj.size.height / 2,
                               width: obj.size.width, height: obj.size.height)
            return frame.intersects(rect)
        }.map(\.id)
        selectedIDs = additive ? selectedIDs.union(hits) : Set(hits)
    }

    // MARK: - 多选整体拖动

    func beginGroupDrag() {
        groupDragAnchors = Dictionary(uniqueKeysWithValues:
            objects.filter { selectedIDs.contains($0.id) }.map { ($0.id, $0.position) })
    }

    func groupDrag(by delta: CGSize) {
        guard let anchors = groupDragAnchors else { return }
        for index in objects.indices {
            if let anchor = anchors[objects[index].id] {
                objects[index].position = CGPoint(x: anchor.x + delta.width, y: anchor.y + delta.height)
            }
        }
        saved = false
    }

    func endGroupDrag() { groupDragAnchors = nil }

    func displayName(_ object: BuilderObject) -> String {
        object.name.trimmingCharacters(in: .whitespaces).isEmpty ? "未命名\(object.kind.title)" : object.name
    }
}
