//
//  TimelineLayout.swift
//  时间线投影的排布算法。
//
//  输入：画布上的事件卡（带 EventTime）。输出：世界坐标下的排布——
//   · X 轴 = 时间。按 time.rank（阶段→日期 sortKey）升序把「同刻事件」聚成一列。
//   · Y 轴 = 泳道。同一列里的并发事件上下错开避让，撑开非线性/多线叙事。
//   · 阶段带：把列按阶段分组，画分隔与阶段标题。
//   · 刻度：有日期的列在轴上打标签，无日期的列只归入阶段带。
//
//  纯函数，不改任何卡片的地图坐标——只在 .timeline 投影里作为位置覆盖使用。
//

import SwiftUI

struct TimelineLayout {
    struct Column: Identifiable {
        let id = UUID()
        var x: CGFloat
        var phase: StoryPhase
        var dateLabel: String        // 有日期才非空
        var eventIDs: [String]
    }
    struct PhaseBand: Identifiable {
        let id = UUID()
        var phase: StoryPhase
        var xStart: CGFloat
        var xEnd: CGFloat
        var labelX: CGFloat
    }

    var positions: [String: CGPoint] = [:]   // 事件卡中心（世界坐标）
    var columns: [Column] = []
    var bands: [PhaseBand] = []
    var baselineY: CGFloat = 0
    var minX: CGFloat = 0
    var maxX: CGFloat = 0
    var isEmpty: Bool { positions.isEmpty }

    // 世界坐标常量（与地图投影同一坐标系，pan/zoom 照常生效）
    static let originX: CGFloat = 360
    static let baselineY: CGFloat = 430
    static let columnSpacing: CGFloat = 300

    /// 由事件卡算出时间线排布。非事件卡不参与（在投影里被淡化）。
    static func make(events: [BuilderObject]) -> TimelineLayout {
        var layout = TimelineLayout()
        layout.baselineY = baselineY
        guard !events.isEmpty else { return layout }

        // 1. 排序：阶段 → 日期 sortKey（无日期视为该阶段末尾）。
        func time(_ o: BuilderObject) -> EventTime { o.time ?? EventTime(phase: .rising) }
        let sorted = events.sorted { time($0).rank < time($1).rank }

        // 2. 按 rank 聚列：rank 相同的事件是「同刻/同阶段无日期」，并入一列并排上下堆叠。
        var buckets: [(rank: Double, items: [BuilderObject])] = []
        for e in sorted {
            let r = time(e).rank
            if let last = buckets.last, abs(last.rank - r) < 0.0001 {
                buckets[buckets.count - 1].items.append(e)
            } else {
                buckets.append((r, [e]))
            }
        }

        // 3. 逐列铺 X（按各列最宽卡推进）；列内按各卡真实高度累加、居中于基线，避免重叠。
        let interColGutter: CGFloat = 96
        let laneVGutter: CGFloat = 40
        var cursorX = originX
        for bucket in buckets {
            let items = bucket.items
            let colW = items.map { $0.size.width }.max() ?? 240
            let centerX = cursorX + colW / 2

            let totalH = items.map { $0.size.height }.reduce(0, +)
                + CGFloat(max(0, items.count - 1)) * laneVGutter
            var y = baselineY - totalH / 2
            for e in items {
                layout.positions[e.id] = CGPoint(x: centerX, y: y + e.size.height / 2)
                y += e.size.height + laneVGutter
            }

            let t = time(items[0])
            layout.columns.append(
                Column(x: centerX, phase: t.phase,
                       dateLabel: t.date?.label ?? "",
                       eventIDs: items.map(\.id))
            )
            cursorX += colW + interColGutter
        }

        layout.minX = layout.columns.first?.x ?? originX
        layout.maxX = layout.columns.last?.x ?? originX

        // 4. 阶段带：把列按阶段分组。
        var i = 0
        while i < layout.columns.count {
            let phase = layout.columns[i].phase
            var j = i
            while j + 1 < layout.columns.count && layout.columns[j + 1].phase == phase { j += 1 }
            let xs = layout.columns[i].x - columnSpacing / 2
            let xe = layout.columns[j].x + columnSpacing / 2
            layout.bands.append(
                PhaseBand(phase: phase, xStart: xs, xEnd: xe, labelX: (xs + xe) / 2)
            )
            i = j + 1
        }
        return layout
    }
}
