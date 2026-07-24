//
//  GlassPanel.swift
//  Atlas 通用玻璃面板 —— 卡片/侧栏/详情区的统一容器。
//  可选标题栏 + 尾部动作；内容自定义。
//

import SwiftUI

struct GlassPanel<Content: View, Trailing: View>: View {
    var title: String?
    var subtitle: String?
    var clear: Bool
    @ViewBuilder var content: Content
    @ViewBuilder var trailing: Trailing

    init(
        title: String? = nil,
        subtitle: String? = nil,
        clear: Bool = false,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.clear = clear
        self.content = content()
        self.trailing = trailing()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AtlasRadius.panel, style: .continuous)

        VStack(alignment: .leading, spacing: AtlasSpacing.m) {
            if title != nil || subtitle != nil {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let title {
                            Text(title).font(AtlasFont.heading).foregroundStyle(AtlasColor.textPrimary)
                        }
                        if let subtitle {
                            Text(subtitle).font(AtlasFont.caption).foregroundStyle(AtlasColor.textTertiary)
                        }
                    }
                    Spacer(minLength: AtlasSpacing.s)
                    trailing
                }
            }
            content
        }
        .padding(AtlasSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .atlasGlass(shape, clear: clear)
        .overlay(shape.stroke(AtlasColor.borderSubtle, lineWidth: 1))
    }
}
