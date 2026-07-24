import Foundation

/// 无模型时的确定性建档解析器。独立于界面，供降级路径与基准测试共同使用。
enum CanvasIntentParser {
    static func parseBatchDrafts(from text: String) -> [CanvasDraftProposal] {
        let normalized = text
            .replacingOccurrences(of: "；", with: "\n")
            .replacingOccurrences(of: ";", with: "\n")
        return normalized
            .components(separatedBy: .newlines)
            .flatMap { line in line.components(separatedBy: "、") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(parseDraftLine)
    }

    private static func parseDraftLine(_ line: String) -> CanvasDraftProposal {
        if let intent = parseExplicitCreateIntent(line) { return intent }

        // 先拿走“地点：/角色：”这类类型前缀，再解析名称与说明；否则冒号会把“地点”误当名称。
        let prefixed = explicitKindPrefix(in: line)
        if let kind = prefixed.kind {
            let parts = splitNameAndSummary(prefixed.name)
            return CanvasDraftProposal(kind: kind, name: parts.name.isEmpty ? kind.title : parts.name, summary: parts.summary)
        }

        let parts = splitNameAndSummary(line)
        return CanvasDraftProposal(kind: inferKind(from: line), name: parts.name, summary: parts.summary)
    }

    private static func explicitKindPrefix(in name: String) -> (kind: BuilderKind?, name: String) {
        for (prefix, kind) in kindPairs where name.hasPrefix(prefix) {
            return (kind, String(name.dropFirst(prefix.count)).trimmingCharacters(in: CharacterSet(charactersIn: " ：:-")))
        }
        return (nil, name)
    }

    private static func splitNameAndSummary(_ line: String) -> (name: String, summary: String) {
        for separator in ["：", ":", " - ", " — ", "，", ","] {
            if let range = line.range(of: separator) {
                return (
                    String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines),
                    String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }
        return (line, "")
    }

    private static func parseExplicitCreateIntent(_ line: String) -> CanvasDraftProposal? {
        let createWords = ["新建", "创建", "新增", "添加", "生成", "建一个", "做一个"]
        guard createWords.contains(where: { line.contains($0) }), let kind = explicitKind(in: line) else { return nil }
        let name = explicitName(in: line) ?? line
            .replacingOccurrences(of: "帮我", with: "")
            .replacingOccurrences(of: "请", with: "")
            .replacingOccurrences(of: "新建", with: "")
            .replacingOccurrences(of: "创建", with: "")
            .replacingOccurrences(of: "新增", with: "")
            .replacingOccurrences(of: "添加", with: "")
            .replacingOccurrences(of: "生成", with: "")
            .replacingOccurrences(of: "一个", with: "")
            .replacingOccurrences(of: kind.title, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ：:-，,。 "))
        return CanvasDraftProposal(kind: kind, name: name.isEmpty ? kind.title : name, summary: "")
    }

    private static func explicitKind(in text: String) -> BuilderKind? {
        kindPairs.first { text.contains($0.0) }?.1
    }

    private static func explicitName(in text: String) -> String? {
        for marker in ["命名为", "名称为", "名字为", "叫做", "叫", "名为"] {
            guard let range = text.range(of: marker) else { continue }
            let tail = String(text[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: " ：:-，,。 "))
            if !tail.isEmpty { return tail }
        }
        return nil
    }

    private static func inferKind(from text: String) -> BuilderKind {
        func has(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        if has(["组织", "阵营", "势力", "公会", "军团", "教会", "家族", "帮", "同盟", "议会"]) { return .org }
        if has(["事件", "祭", "战", "典礼", "仪式", "风暴", "叛乱", "会战", "节日"]) { return .event }
        if has(["规则", "禁令", "律法", "法则", "边界", "限制", "政策"]) { return .rule }
        if has(["角色", "守望", "者", "先生", "小姐", "师", "国王", "客", "队长", "匠"]) { return .character }
        if has(["物件", "长剑", "灯", "书", "钥匙", "印记", "符文", "器物"]) { return .item }
        if has(["作品", "画作", "手稿", "曲", "诗"]) { return .work }
        return .location
    }

    private static let kindPairs: [(String, BuilderKind)] = [
        ("地图", .map), ("地点", .location), ("角色", .character), ("组织", .org),
        ("阵营", .org), ("事件", .event), ("规则", .rule), ("物件", .item),
        ("作品", .work), ("便签", .note)
    ]
}
