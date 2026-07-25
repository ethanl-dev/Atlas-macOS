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
        case .map: return "用户绘制的世界地图"
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

enum MapPlacementKind: String {
    case point = "设定点"
    case area = "范围影响"
}

// MARK: - 世界对象

struct BuilderObject: Identifiable {
    let id: String
    var kind: BuilderKind
    var name: String
    var summary: String
    var position: CGPoint      // 画布世界坐标（卡片中心）
    var size: CGSize           // 卡片尺寸（世界坐标，可拉角改变）
    var aiAssisted: Bool = false
    /// 对应地图标注的 id；为空表示这张 Canvas 卡片尚未定位到地图。
    var mapAnnotationID: String? = nil
    /// 事件卡的时间元素（阶段 + 可选世界内日期）。仅 .event 有意义；其它类型为 nil。
    var time: EventTime? = nil
}

// MARK: - 关系强度（黑白系统：用线宽 + 亮度表达，不用色）

enum RelationStrength: String, CaseIterable, Identifiable, Codable {
    case weak   = "淡"
    case medium = "常"
    case strong = "深"

    var id: String { rawValue }
    var lineWidth: CGFloat {
        switch self {
        case .weak:   return 1
        case .medium: return 1.8
        case .strong: return 3
        }
    }
    var opacity: Double {
        switch self {
        case .weak:   return 0.20
        case .medium: return 0.34
        case .strong: return 0.55
        }
    }
}

// MARK: - 关系线（升级为一等对象：可命名、可标强度、可写一段长文/故事）

struct BuilderRelation: Identifiable {
    let id: String
    var sourceID: String
    var targetID: String
    var label: String
    /// 关联所在的字段名（结构性 link 的语义锚点）；正文 @ 提及用 "提及"。
    var fieldKey: String = ""
    /// 关系性 link 的子标签（盟友/敌对/对抗…），结构性为 nil。
    var subtag: String? = nil

    // —— 一等对象升级字段 ——
    /// 关系的名字（可选，如「十年之约」）。空则用 subtag/label 兜底显示。
    var title: String = ""
    /// 关系强度（连线粗细 + 亮度）。
    var strength: RelationStrength = .medium
    /// 复杂关系的长文/故事。连线表达不了的，写在这里。
    var narrative: String = ""
    /// 是否由 Agent 提议、尚未被作者采纳（用于幽灵预览的虚线渲染）。
    var proposed: Bool = false

    /// 连线中点 chip 的短标签。
    var chipLabel: String {
        if !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        if let s = subtag, !s.isEmpty { return s }
        return label
    }
    var hasNarrative: Bool { !narrative.trimmingCharacters(in: .whitespaces).isEmpty }
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
    /// 选中的关系（一等对象）。与对象选择互斥：选关系时清空对象选择，反之亦然。
    @Published var selectedRelationID: String? = nil
    @Published var projection: BuilderProjection = .map

    /// 单选便捷入口：恰好选中一个时返回它，否则 nil（详情卡只在单选时出现）。
    var selectedID: String? {
        get { selectedIDs.count == 1 ? selectedIDs.first : nil }
        set {
            selectedIDs = newValue.map { [$0] } ?? []
            if newValue != nil { selectedRelationID = nil }   // 选对象即取消选关系
        }
    }

    /// 选中一条关系（清空对象选择）。
    func selectRelation(_ id: String?) {
        selectedRelationID = id
        if id != nil { selectedIDs = [] }
    }

    var selectedRelation: BuilderRelation? {
        guard let id = selectedRelationID else { return nil }
        return relations.first { $0.id == id }
    }

    /// 关系的可写绑定（供 RelationDetailCard 编辑标题/强度/叙事）。
    func relationBinding(for id: String) -> Binding<BuilderRelation>? {
        guard relations.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: {
                self.relations.first(where: { $0.id == id })
                    ?? BuilderRelation(id: id, sourceID: "", targetID: "", label: "")
            },
            set: {
                if let i = self.relations.firstIndex(where: { $0.id == id }) {
                    self.relations[i] = $0
                    self.saved = false
                }
            }
        )
    }

    private var groupDragAnchors: [String: CGPoint]?
    @Published var mapMade = false          // 是否已经绘制过地图底盘
    @Published var saved = true
    @Published var mapJSON: String?

    private var counter = 0

    init(worldName: String = "未命名世界", seeded: Bool = false) {
        self.worldName = worldName
        if seeded {
            self.objects = [
                .init(id: "map-seed", kind: .map, name: "世界地图",
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
        var object = BuilderObject(
            id: id, kind: kind, name: "",
            summary: "", position: position, size: kind.defaultSize
        )
        // 事件天生带时间元素：默认落在「发展」阶段，作者可在详情卡改。
        if kind == .event { object.time = EventTime(phase: .rising) }
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
        let dropped = relations.filter { $0.sourceID == id || $0.targetID == id }.map(\.id)
        objects.removeAll { $0.id == id }
        relations.removeAll { $0.sourceID == id || $0.targetID == id }
        selectedIDs.remove(id)
        if let sel = selectedRelationID, dropped.contains(sel) { selectedRelationID = nil }
        saved = false
    }

    // MARK: - 选择

    func selectOnly(_ id: String) { selectedIDs = [id]; selectedRelationID = nil }
    func toggle(_ id: String) { if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }; selectedRelationID = nil }
    func clearSelection() { selectedIDs = []; selectedRelationID = nil }

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

    var unlocatedObjects: [BuilderObject] {
        objects.filter { $0.kind != .map && $0.mapAnnotationID == nil }
    }

    func preferredMapPlacement(for object: BuilderObject) -> MapPlacementKind {
        object.kind == .event || object.kind == .rule ? .area : .point
    }

    func pendingMapPlacementsJSON() -> String? {
        let payload: [[String: String]] = unlocatedObjects.map { object in
            [
                "id": object.id,
                "name": displayName(object),
                "placement": preferredMapPlacement(for: object).rawValue,
                "category": mapCategory(for: object.kind),
                "color": mapCategoryColor(for: object.kind)
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }

    /// 地图是空间投影，Canvas 是内容主数据。地图保存后只补齐/更新对应卡片，
    /// 不删除 Canvas 中尚未定位的原创卡片。
    func synchronizeMap(_ json: String) {
        guard let data = json.data(using: .utf8),
              let archive = try? JSONDecoder().decode(MapArchive.self, from: data) else { return }
        mapJSON = json

        let spatial = archive.annotations.filter { $0.kind == "point" || $0.kind == "area" }
        let liveIDs = Set(spatial.map(\.id))

        for index in objects.indices {
            if let annotationID = objects[index].mapAnnotationID,
               !liveIDs.contains(annotationID) {
                objects[index].mapAnnotationID = nil
            }
        }

        for (offset, annotation) in spatial.enumerated() {
            let kind = builderKind(for: annotation)
            let fallback = annotation.kind == "area" ? "未命名范围影响" : "未命名\(kind.title)"
            if let index = objects.firstIndex(where: {
                $0.mapAnnotationID == annotation.id || $0.id == annotation.id
            }) {
                objects[index].mapAnnotationID = annotation.id
                objects[index].kind = kind
                objects[index].name = annotation.title?.nonEmpty ?? fallback
                objects[index].summary = annotation.description?.nonEmpty ?? objects[index].summary
            } else {
                let column = CGFloat(offset % 4)
                let row = CGFloat(offset / 4)
                objects.append(
                    BuilderObject(
                        id: "map-\(annotation.id)",
                        kind: kind,
                        name: annotation.title?.nonEmpty ?? fallback,
                        summary: annotation.description?.nonEmpty ?? "",
                        position: CGPoint(x: 620 + column * 280, y: 250 + row * 190),
                        size: kind.defaultSize,
                        mapAnnotationID: annotation.id,
                        time: kind == .event ? EventTime(phase: .rising) : nil
                    )
                )
            }
        }

        // 关系先落入统一数据模型；具体连线视觉由协作中的关系层继续负责。
        for annotation in archive.annotations where annotation.kind == "line" {
            guard let sourceMapID = annotation.sourceId,
                  let targetMapID = annotation.targetId,
                  let source = objects.first(where: { $0.mapAnnotationID == sourceMapID }),
                  let target = objects.first(where: { $0.mapAnnotationID == targetMapID }) else { continue }
            let relationID = "map-\(annotation.id)"
            let relation = BuilderRelation(
                id: relationID,
                sourceID: source.id,
                targetID: target.id,
                label: annotation.category ?? "关联",
                title: annotation.title ?? ""
            )
            if let index = relations.firstIndex(where: { $0.id == relationID }) {
                relations[index] = relation
            } else {
                relations.append(relation)
            }
        }

        mapMade = true
        saved = false
    }

    private func builderKind(for annotation: MapAnnotationArchive) -> BuilderKind {
        if annotation.kind == "area" {
            return annotation.category?.contains("规则") == true ? .rule : .event
        }
        switch annotation.category {
        case "地点": return .location
        case "NPC", "角色": return .character
        case "阵营", "组织": return .org
        case "物品", "物件": return .item
        case "作品": return .work
        default: return .note
        }
    }

    private func mapCategory(for kind: BuilderKind) -> String {
        switch kind {
        case .location: return "地点"
        case .character: return "角色"
        case .org: return "组织"
        case .item: return "物件"
        case .work: return "作品"
        case .event: return "范围影响"
        case .rule: return "规则"
        default: return "自定义类别"
        }
    }

    private func mapCategoryColor(for kind: BuilderKind) -> String {
        switch kind {
        case .location: return "#59C3A5"
        case .character: return "#F08A72"
        case .org: return "#7DA7FF"
        case .item: return "#E5B95C"
        case .work: return "#C58BFA"
        case .note: return "#AEB6C4"
        case .event: return "#FF8F5C"
        case .rule: return "#62D1D8"
        default: return "#AEB6C4"
        }
    }

    var mapCoastPaths: [[CGPoint]] {
        guard let mapJSON,
              let data = mapJSON.data(using: .utf8),
              let archive = try? JSONDecoder().decode(MapArchive.self, from: data) else { return [] }
        return archive.coasts.map { path in path.map { CGPoint(x: $0.x, y: $0.y) } }
    }
}

private struct MapArchive: Decodable {
    var annotations: [MapAnnotationArchive]
    var coasts: [[MapPointArchive]] = []
}

private struct MapPointArchive: Decodable {
    var x: Double
    var y: Double
}

private struct MapAnnotationArchive: Decodable {
    var id: String
    var kind: String
    var title: String?
    var category: String?
    var description: String?
    var sourceId: String?
    var targetId: String?
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return value
    }
}
