//
//  MentionTextEditor.swift
//  正文编辑器 + 自由 link（@ 提及）。
//
//  自由 link（对应《Atlas 卡片字段规格》第 5 节第三层）：正文里 @ 一张已存在的卡，
//  只建立"提及"弱关联，不带强语义。
//
//  原生约束：SwiftUI TextEditor 是纯文本，无法在流动文字中嵌行内视图（那需 NSTextView + 附件）。
//  这里的取舍：打 @ + 输入 → 选中后把 "@query" 从正文里消费掉，转成下方一枚单色 chip。
//  —— 既满足"@ 完成后不留 @ 符号、渲染成特殊格式"，也保持正文是干净散文，且提及是可用的图数据。
//
//  黑白单色：提及 chip 复用 LinkChip，靠 SF Symbol 区分类型，无强调色。
//

import SwiftUI

struct MentionTextEditor: View {
    @Binding var text: String
    /// 已提及对象的 id 列表（弱关联）
    @Binding var mentions: [String]
    var placeholder: String = "正文…  打 @ 提及世界里已有的对象"
    /// 不可被自己提及（编辑既有对象时传入其 id）
    var excludeID: String? = nil

    // 当前正在输入的 @token（位于正文末尾、其后无空格时才激活）
    private var activeQuery: (range: Range<String.Index>, text: String)? {
        guard let atIdx = text.lastIndex(of: "@") else { return nil }
        let after = text[text.index(after: atIdx)...]
        if after.contains(where: { $0 == " " || $0 == "\n" }) { return nil }
        return (atIdx..<text.endIndex, String(after))
    }

    private var candidates: [WorldObject] {
        guard let q = activeQuery?.text else { return [] }
        return WorldObject.samples.filter { obj in
            obj.id != excludeID
            && !mentions.contains(obj.id)
            && (q.isEmpty || obj.name.localizedCaseInsensitiveContains(q))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            editor

            // @ 建议面板（正文下方浮层；无光标坐标，锚定编辑器底部）
            if activeQuery != nil, !candidates.isEmpty {
                suggestionPanel
            }

            // 提及 chip 区（渲染成特殊格式的"@"结果）
            if !mentions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "at").font(.system(size: 9))
                        Text("提及").font(AtlasFont.caption)
                    }
                    .foregroundStyle(AtlasColor.textTertiary)

                    LinkFlowLayout(spacing: 6) {
                        ForEach(mentions, id: \.self) { id in
                            LinkChip(
                                link: WorldLink(sourceID: "__body__", fieldKey: "提及", targetID: id),
                                onRemove: { mentions.removeAll { $0 == id } }
                            )
                        }
                    }
                }
            }
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(AtlasFont.body)
                .scrollContentBackground(.hidden)
                .padding(AtlasSpacing.s)
                .frame(height: 150)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))

            if text.isEmpty {
                Text(placeholder)
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textDisabled)
                    .padding(.horizontal, AtlasSpacing.s + 5)
                    .padding(.vertical, AtlasSpacing.s + 8)
                    .allowsHitTesting(false)
            }
        }
    }

    private var suggestionPanel: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: "at").font(.system(size: 9)).foregroundStyle(AtlasColor.textTertiary)
                Text("提及 · @\(activeQuery?.text ?? "")")
                    .font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
            }
            .padding(.horizontal, AtlasSpacing.s).padding(.top, 4).padding(.bottom, 2)

            ForEach(candidates.prefix(6)) { obj in
                MentionRow(object: obj) { insert(obj) }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous).stroke(AtlasColor.borderSubtle))
    }

    private func insert(_ obj: WorldObject) {
        if let range = activeQuery?.range {
            text.removeSubrange(range)   // 消费掉 "@query"，不在正文里留 @ 符号
        }
        if !mentions.contains(obj.id) { mentions.append(obj.id) }
    }
}

private struct MentionRow: View {
    var object: WorldObject
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: object.type.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AtlasColor.textPrimary)
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                Text(object.name).font(AtlasFont.label).foregroundStyle(AtlasColor.textPrimary).lineLimit(1)
                Spacer(minLength: 4)
                Text(object.type.rawValue).font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, AtlasSpacing.s).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.07 : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
