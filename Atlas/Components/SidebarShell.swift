//
//  SidebarShell.swift
//  Atlas App 壳 —— 玻璃侧栏导航 + 内容区。
//  侧栏用 NavigationSplitView，玻璃底板浮在世界画布之上。
//

import SwiftUI

enum AtlasSection: String, CaseIterable, Identifiable {
    case world    = "世界"
    case canvas   = "World Canvas"
    case wiki     = "Wiki 对象库"
    case events   = "事件"
    case review   = "审核队列"
    case publicP  = "公开页"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .world:   return "globe.asia.australia"
        case .canvas:  return "map"
        case .wiki:    return "books.vertical"
        case .events:  return "bolt.horizontal"
        case .review:  return "checklist"
        case .publicP: return "rectangle.on.rectangle.angled"
        }
    }
}

struct SidebarShell<Detail: View>: View {
    @Binding var selection: AtlasSection
    var detail: Detail

    init(selection: Binding<AtlasSection>, @ViewBuilder detail: () -> Detail) {
        self._selection = selection
        self.detail = detail()
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 208, ideal: 224, max: 260)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AtlasCanvasBackground())
        }
        .navigationTitle("")
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            // 品牌
            HStack(spacing: AtlasSpacing.s) {
                brandMark
                VStack(alignment: .leading, spacing: 0) {
                    Text("ATLAS").font(.system(size: 15, weight: .bold)).tracking(2)
                        .foregroundStyle(AtlasColor.textPrimary)
                    Text("企划共创平台").font(AtlasFont.monoSmall)
                        .foregroundStyle(AtlasColor.textTertiary)
                }
            }
            .padding(.top, AtlasSpacing.s)

            // 导航项
            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                ForEach(AtlasSection.allCases) { section in
                    NavItem(section: section, selected: selection == section) {
                        selection = section
                    }
                }
            }

            Spacer()

            // 底部：当前企划
            currentProject
        }
        .padding(AtlasSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(AtlasColor.subtle.opacity(0.6))
        .background(AtlasCanvasBackground())
    }

    private var brandMark: some View {
        // 极简单色四点标记
        Grid(horizontalSpacing: 2.5, verticalSpacing: 2.5) {
            GridRow { dot; dot }
            GridRow { dot; dot }
        }
        .padding(6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    private var dot: some View {
        Circle().fill(AtlasColor.textPrimary).frame(width: 5, height: 5)
    }

    private var currentProject: some View {
        HStack(spacing: AtlasSpacing.s) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: "globe.asia.australia").font(.system(size: 13)).foregroundStyle(AtlasColor.textSecondary))
            VStack(alignment: .leading, spacing: 1) {
                Text("雾海来信").font(AtlasFont.label).foregroundStyle(AtlasColor.textPrimary)
                Text("第二幕 · 招募中").font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
            }
            Spacer()
        }
        .padding(AtlasSpacing.s)
        .atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous))
    }
}

private struct NavItem: View {
    var section: AtlasSection
    var selected: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AtlasSpacing.s) {
                Image(systemName: section.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(section.rawValue).font(AtlasFont.label)
                Spacer()
            }
            .foregroundStyle(selected ? AtlasColor.textPrimary : AtlasColor.textSecondary)
            .padding(.horizontal, AtlasSpacing.s)
            .padding(.vertical, AtlasSpacing.s - 1)
            .background {
                if selected {
                    Color.clear.atlasGlass(RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous))
                } else if hovering {
                    RoundedRectangle(cornerRadius: AtlasRadius.control, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
