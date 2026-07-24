//
//  BuilderLink.swift
//  「创建世界」画布(WorldBuilderCanvas)上的对象关联(link)。
//
//  三层语义模型(对应《Atlas 卡片字段规格》第5节)，落在 BuilderObject / BuilderRelation 上：
//   1. 结构性 link —— 语义由字段决定，自动不问用户。
//   2. 关系性 link —— 自动给大类，用户补一个子标签。
//   3. 自由 link   —— 详情卡正文里 @ 提及(见 BuilderMentionEditor)。
//
//  黑白单色：靠目标对象的 SF Symbol 区分类型，不靠颜色。候选只来自画布上已存在的对象。
//  复用 LinkModel.swift 的 LinkLayer、以及 LinkPicker.swift 的 FlowLayout。
//

import SwiftUI

// MARK: - 链接字段定义（按 BuilderKind）

struct BuilderLinkField: Identifiable, Hashable {
    var id: String { key }
    var key: String
    var accepts: [BuilderKind]
    var semantic: String
    var relationalTags: [String]
    var layer: LinkLayer

    var isRelational: Bool { !relationalTags.isEmpty }
    var acceptLabel: String { accepts.map(\.title).joined(separator: " / ") }
}

enum BuilderLinkRules {
    static func fields(for kind: BuilderKind) -> [BuilderLinkField] {
        switch kind {
        case .character:
            return [
                .init(key: "阵营归属", accepts: [.org], semantic: "隶属", relationalTags: [], layer: .pub),
                .init(key: "能力边界", accepts: [.rule], semantic: "受约束", relationalTags: [], layer: .pub),
                .init(key: "关系网", accepts: [.character], semantic: "人际",
                      relationalTags: ["盟友", "敌对", "师徒", "亲属"], layer: .reveal),
            ]
        case .location:
            return [
                .init(key: "所在地图", accepts: [.map], semantic: "定位于", relationalTags: [], layer: .pub),
                .init(key: "关联", accepts: [.org, .event], semantic: "掌控 / 发生地", relationalTags: [], layer: .pub),
            ]
        case .org:
            return [
                .init(key: "对外关系", accepts: [.org], semantic: "势力关系",
                      relationalTags: ["对抗", "协作", "中立"], layer: .reveal),
            ]
        case .event:
            return [
                .init(key: "涉及角色", accepts: [.character], semantic: "卷入", relationalTags: [], layer: .pub),
                .init(key: "触发地点", accepts: [.location], semantic: "发生于", relationalTags: [], layer: .pub),
            ]
        case .item:
            return [
                .init(key: "载体逻辑", accepts: [.rule], semantic: "遵循", relationalTags: [], layer: .pub),
                .init(key: "归属", accepts: [.character, .org], semantic: "持有于", relationalTags: [], layer: .reveal),
            ]
        case .work:
            return [
                .init(key: "关联世界", accepts: [.location, .event, .character], semantic: "关于",
                      relationalTags: [], layer: .pub),
            ]
        case .map, .rule, .note:
            return []
        }
    }
}

// MARK: - Store 关联操作

extension WorldBuilderStore {
    func object(withID id: String) -> BuilderObject? {
        objects.first { $0.id == id }
    }

    func links(for source: String, field: String) -> [BuilderRelation] {
        relations.filter { $0.sourceID == source && $0.fieldKey == field }
    }

    func isLinked(source: String, field: String, target: String) -> Bool {
        relations.contains { $0.sourceID == source && $0.fieldKey == field && $0.targetID == target }
    }

    @discardableResult
    func addLink(source: String, field: String, target: String, subtag: String? = nil) -> Bool {
        guard !isLinked(source: source, field: field, target: target) else { return false }
        relations.append(
            BuilderRelation(id: "rel-\(UUID().uuidString.prefix(8))",
                            sourceID: source, targetID: target,
                            label: field, fieldKey: field, subtag: subtag)
        )
        saved = false
        return true
    }

    func removeLink(_ id: String) {
        relations.removeAll { $0.id == id }
        if selectedRelationID == id { selectedRelationID = nil }
        saved = false
    }

    func linkCount(for source: String) -> Int {
        relations.filter { $0.sourceID == source }.count
    }

    // MARK: - Agent「整理」通道用的操作（不触碰卡片正文；只动布局与关系）

    /// 直接把一张卡移到世界坐标（Agent 采纳整理方案时用）。
    func place(_ id: String, at position: CGPoint) {
        guard let i = objects.firstIndex(where: { $0.id == id }) else { return }
        objects[i].position = position
        saved = false
    }

    /// 无字段语义地新建一条关系（Agent 提议 / 采纳时用）。返回新关系 id。
    @discardableResult
    func createRelation(source: String, target: String,
                        subtag: String? = nil, title: String = "",
                        narrative: String = "", strength: RelationStrength = .medium,
                        proposed: Bool = false) -> String? {
        guard source != target,
              objects.contains(where: { $0.id == source }),
              objects.contains(where: { $0.id == target }) else { return nil }
        let id = "rel-\(UUID().uuidString.prefix(8))"
        relations.append(
            BuilderRelation(id: id, sourceID: source, targetID: target,
                            label: subtag ?? title, fieldKey: "关系",
                            subtag: subtag, title: title,
                            strength: strength, narrative: narrative, proposed: proposed)
        )
        saved = false
        return id
    }
}

// MARK: - 单色关联 chip

struct BuilderLinkChip: View {
    var relation: BuilderRelation
    @ObservedObject var store: WorldBuilderStore
    var onRemove: (() -> Void)? = nil

    var body: some View {
        let target = store.object(withID: relation.targetID)
        HStack(spacing: 5) {
            Image(systemName: target?.kind.symbol ?? "questionmark.circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AtlasColor.textSecondary)
            Text(target.map { store.displayName($0) } ?? "已失效")
                .font(AtlasFont.label)
                .foregroundStyle(target == nil ? AtlasColor.textDisabled : AtlasColor.textPrimary)
                .strikethrough(target == nil, color: AtlasColor.textDisabled)
                .lineLimit(1)
            if let sub = relation.subtag {
                Text(sub).font(AtlasFont.mono).foregroundStyle(AtlasColor.textTertiary)
                    .padding(.leading, 5)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(AtlasColor.borderSubtle).frame(width: 1, height: 12)
                    }
            }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AtlasColor.textTertiary)
                }
                .buttonStyle(.plain).padding(.leading, 1)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle, lineWidth: 1))
    }
}

// MARK: - 详情卡里的关联区

struct BuilderLinkSection: View {
    var object: BuilderObject
    @ObservedObject var store: WorldBuilderStore

    var body: some View {
        let fields = BuilderLinkRules.fields(for: object.kind)
        if !fields.isEmpty {
            VStack(alignment: .leading, spacing: AtlasSpacing.m) {
                HStack {
                    Text("关联").font(AtlasFont.label).foregroundStyle(AtlasColor.textSecondary)
                    Spacer()
                    Text("\(store.linkCount(for: object.id))")
                        .font(AtlasFont.mono).foregroundStyle(AtlasColor.textTertiary)
                }
                ForEach(fields) { field in
                    BuilderLinkFieldRow(object: object, field: field, store: store)
                }
            }
        }
    }
}

private struct BuilderLinkFieldRow: View {
    var object: BuilderObject
    var field: BuilderLinkField
    @ObservedObject var store: WorldBuilderStore
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Text(field.key).font(AtlasFont.mono).foregroundStyle(AtlasColor.textSecondary).tracking(0.5)
                if let lock = field.layer.symbol {
                    Image(systemName: lock).font(.system(size: 9)).foregroundStyle(AtlasColor.textTertiary)
                }
                Text("→ \(field.semantic)").font(AtlasFont.mono).foregroundStyle(AtlasColor.textTertiary)
            }

            FlowLayout(spacing: 6) {
                ForEach(store.links(for: object.id, field: field.key)) { rel in
                    BuilderLinkChip(relation: rel, store: store) { store.removeLink(rel.id) }
                }
                Button { showPicker = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                        Text("关联\(field.acceptLabel)").font(AtlasFont.label)
                    }
                    .foregroundStyle(AtlasColor.textSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .overlay(Capsule().stroke(AtlasColor.borderDefault, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPicker, arrowEdge: .leading) {
                    BuilderLinkPicker(source: object, field: field, store: store) { showPicker = false }
                }
            }
        }
    }
}

// MARK: - 关联选择器（候选 → 关系性子标签）

private struct BuilderLinkPicker: View {
    var source: BuilderObject
    var field: BuilderLinkField
    @ObservedObject var store: WorldBuilderStore
    var onClose: () -> Void

    @State private var pendingTarget: BuilderObject?

    private var candidates: [BuilderObject] {
        store.objects.filter { obj in
            field.accepts.contains(obj.kind)
            && obj.id != source.id
            && !store.isLinked(source: source.id, field: field.key, target: obj.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            if let target = pendingTarget {
                subtagStep(target)
            } else {
                candidateStep
            }
        }
        .padding(AtlasSpacing.m)
        .frame(width: 240)
        .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous))
    }

    private var candidateStep: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            HStack(spacing: 5) {
                Text("关联到").font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                Text(field.semantic).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textSecondary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Color.white.opacity(0.05), in: Capsule())
            }
            if candidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("画布上还没有可关联的「\(field.acceptLabel)」")
                        .font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
                    Text("先放一张到画布上，再回来连它。")
                        .font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                }
                .fixedSize(horizontal: false, vertical: true).padding(.vertical, 6)
            } else {
                ForEach(candidates) { obj in
                    BuilderCandidateRow(object: obj, store: store) { pick(obj) }
                }
            }
        }
    }

    private func subtagStep(_ target: BuilderObject) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            HStack(spacing: 4) {
                Button { pendingTarget = nil } label: {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(AtlasColor.textTertiary)
                Text("\(store.displayName(source)) 与 \(store.displayName(target)) 的关系")
                    .font(AtlasFont.caption).foregroundStyle(AtlasColor.textSecondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(field.relationalTags, id: \.self) { tag in
                    Button {
                        store.addLink(source: source.id, field: field.key, target: target.id, subtag: tag)
                        onClose()
                    } label: {
                        Text(tag).font(AtlasFont.caption).foregroundStyle(AtlasColor.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(Color.white.opacity(0.05), in: Capsule())
                            .overlay(Capsule().stroke(AtlasColor.borderSubtle, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pick(_ obj: BuilderObject) {
        if field.isRelational {
            pendingTarget = obj
        } else {
            store.addLink(source: source.id, field: field.key, target: obj.id)
            onClose()
        }
    }
}

private struct BuilderCandidateRow: View {
    var object: BuilderObject
    @ObservedObject var store: WorldBuilderStore
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: object.kind.symbol)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(AtlasColor.textPrimary)
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(store.displayName(object)).font(AtlasFont.label).foregroundStyle(AtlasColor.textPrimary).lineLimit(1)
                    Text(object.kind.title).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                }
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, AtlasSpacing.s).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous)
                .fill(Color.white.opacity(hovering ? 0.07 : 0)))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - 正文编辑器 + @ 自由提及（弱关联，存为 fieldKey "提及"）

struct BuilderMentionEditor: View {
    @Binding var object: BuilderObject
    @ObservedObject var store: WorldBuilderStore

    private let field = "提及"

    private var activeQuery: (range: Range<String.Index>, text: String)? {
        let s = object.summary
        guard let atIdx = s.lastIndex(of: "@") else { return nil }
        let after = s[s.index(after: atIdx)...]
        if after.contains(where: { $0 == " " || $0 == "\n" }) { return nil }
        return (atIdx..<s.endIndex, String(after))
    }

    private var candidates: [BuilderObject] {
        guard let q = activeQuery?.text else { return [] }
        return store.objects.filter { obj in
            obj.id != object.id
            && !store.isLinked(source: object.id, field: field, target: obj.id)
            && (q.isEmpty || store.displayName(obj).localizedCaseInsensitiveContains(q))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $object.summary)
                    .font(AtlasFont.body).foregroundStyle(AtlasColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(height: 120).padding(AtlasSpacing.s)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
                if object.summary.isEmpty {
                    Text("补充这个\(object.kind.title)的设定……  打 @ 提及画布上的对象")
                        .font(AtlasFont.body).foregroundStyle(AtlasColor.textTertiary)
                        .padding(AtlasSpacing.s).padding(.top, 2).allowsHitTesting(false)
                }
            }

            if activeQuery != nil, !candidates.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(candidates.prefix(6)) { obj in
                        BuilderCandidateRow(object: obj, store: store) { insert(obj) }
                    }
                }
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .atlasP1Glass(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
            }

            let mentions = store.links(for: object.id, field: field)
            if !mentions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "at").font(.system(size: 9))
                        Text("提及").font(AtlasFont.caption)
                    }
                    .foregroundStyle(AtlasColor.textTertiary)
                    FlowLayout(spacing: 6) {
                        ForEach(mentions) { rel in
                            BuilderLinkChip(relation: rel, store: store) { store.removeLink(rel.id) }
                        }
                    }
                }
            }
        }
    }

    private func insert(_ obj: BuilderObject) {
        if let range = activeQuery?.range {
            object.summary.removeSubrange(range)   // 消费 "@query"，不在正文留 @ 符号
        }
        store.addLink(source: object.id, field: field, target: obj.id)
    }
}
