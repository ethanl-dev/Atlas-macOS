//
//  EventTime.swift
//  事件卡的「时间元素」—— 双层模型（用户 2026-07-24 确认）：
//    · 阶段(phase)：必有。把事件挂在叙事进程的某个阶段上，保证时间线总能排布。
//    · 世界内日期(date)：可选。填了就精排、显示；没填就退回阶段内排布。
//
//  黑白系统：阶段/日期都用文字 + 亮度表达，不用色相。
//

import SwiftUI

// MARK: - 叙事阶段（相对时间，有序）

enum StoryPhase: Int, CaseIterable, Identifiable, Comparable {
    case prologue   // 序幕
    case setup      // 铺垫
    case rising     // 发展
    case climax     // 高潮
    case aftermath  // 余波

    var id: Int { rawValue }
    var order: Int { rawValue }

    var title: String {
        switch self {
        case .prologue:  return "序幕"
        case .setup:     return "铺垫"
        case .rising:    return "发展"
        case .climax:    return "高潮"
        case .aftermath: return "余波"
        }
    }

    /// 时间线上该阶段带的相对亮度（高潮最亮）。
    var emphasis: Double {
        switch self {
        case .prologue:  return 0.42
        case .setup:     return 0.52
        case .rising:    return 0.66
        case .climax:    return 0.95
        case .aftermath: return 0.58
        }
    }

    static func < (lhs: StoryPhase, rhs: StoryPhase) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - 世界内日期（虚构历法，标签 + 可选排序键）

struct WorldDate: Hashable, Codable {
    /// 展示用的历法标签，如「极光纪 三年·望」。
    var label: String
    /// 精排用的数值键（可无）。越小越早。填了才参与阶段内精确排序。
    var sortKey: Double?

    var isEmpty: Bool { label.trimmingCharacters(in: .whitespaces).isEmpty && sortKey == nil }
}

// MARK: - 事件时间（阶段 + 可选日期）

struct EventTime: Hashable, Codable {
    var phase: StoryPhase
    var date: WorldDate?

    init(phase: StoryPhase = .rising, date: WorldDate? = nil) {
        self.phase = phase
        self.date = date
    }

    /// 排序权重：先阶段，后日期 sortKey（无则视为该阶段末尾）。
    var rank: Double {
        let base = Double(phase.order) * 1000
        return base + (date?.sortKey ?? 999)
    }

    /// 卡片/时间线上显示的短标签。
    var shortLabel: String {
        if let d = date, !d.label.trimmingCharacters(in: .whitespaces).isEmpty {
            return "\(phase.title) · \(d.label)"
        }
        return phase.title
    }
}

extension StoryPhase: Codable {}

// MARK: - 时间 chip（卡片体上的小标签：钟表图标 + 阶段·日期）

struct TimeChip: View {
    var time: EventTime
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: compact ? 8 : 9, weight: .medium))
            Text(time.shortLabel)
                .font(AtlasFont.monoSmall)
                .lineLimit(1)
        }
        .foregroundStyle(AtlasColor.textSecondary.opacity(0.5 + 0.5 * time.phase.emphasis))
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle, lineWidth: 1))
    }
}

// MARK: - 详情卡里的「时间」区（阶段必填 + 世界内日期可选）

struct EventTimeSection: View {
    @Binding var time: EventTime

    /// 日期标签的直接绑定。
    private var dateLabel: Binding<String> {
        Binding(
            get: { time.date?.label ?? "" },
            set: { newValue in
                let trimmed = newValue
                if trimmed.isEmpty && (time.date?.sortKey == nil) {
                    time.date = nil
                } else {
                    var d = time.date ?? WorldDate(label: "", sortKey: nil)
                    d.label = trimmed
                    time.date = d
                }
            }
        )
    }

    /// 精排数值键的字符串绑定（可空）。
    private var sortKeyText: Binding<String> {
        Binding(
            get: { time.date?.sortKey.map { String(format: "%g", $0) } ?? "" },
            set: { newValue in
                let key = Double(newValue.trimmingCharacters(in: .whitespaces))
                if (time.date?.label.isEmpty ?? true) && key == nil {
                    time.date = nil
                } else {
                    var d = time.date ?? WorldDate(label: "", sortKey: nil)
                    d.sortKey = key
                    time.date = d
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.s) {
            HStack(spacing: 5) {
                Image(systemName: "clock").font(.system(size: 10))
                Text("时间").font(AtlasFont.caption)
            }
            .foregroundStyle(AtlasColor.textTertiary)

            Text("叙事阶段").font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
            PhasePicker(phase: $time.phase)

            HStack(spacing: AtlasSpacing.s) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("世界内日期 · 可选").font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                    TextField("如：极光纪 三年·望", text: dateLabel)
                        .textFieldStyle(.plain)
                        .font(AtlasFont.body)
                        .foregroundStyle(AtlasColor.textPrimary)
                        .padding(.horizontal, AtlasSpacing.s).padding(.vertical, 6)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("精排键").font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                    TextField("数字", text: sortKeyText)
                        .textFieldStyle(.plain)
                        .font(AtlasFont.mono)
                        .foregroundStyle(AtlasColor.textPrimary)
                        .frame(width: 56)
                        .padding(.horizontal, AtlasSpacing.s).padding(.vertical, 6)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: AtlasRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.control).stroke(AtlasColor.borderSubtle))
                }
            }
            Text("填了日期就沿时间轴精排；只填阶段则在阶段泳道内排布。")
                .font(AtlasFont.monoSmall).foregroundStyle(AtlasColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 阶段分段选择器（详情卡里用；黑白，选中填白）

struct PhasePicker: View {
    @Binding var phase: StoryPhase

    var body: some View {
        HStack(spacing: 2) {
            ForEach(StoryPhase.allCases) { p in
                Button {
                    phase = p
                } label: {
                    Text(p.title)
                        .font(AtlasFont.caption)
                        .foregroundStyle(phase == p ? AtlasColor.inverse : AtlasColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if phase == p { Capsule().fill(Color.white) }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderSubtle))
    }
}

