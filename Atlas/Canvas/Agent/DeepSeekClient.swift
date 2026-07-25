//
//  DeepSeekClient.swift
//  Swift 直连 DeepSeek（OpenAI 兼容）。用 function-calling 让模型调用「命令行工具」
//  （arrange_canvas / cluster_cards / move_card / link_objects / unlink），
//  本地把这些调用解析成 AgentAction 交给 CanvasOrganizer 预览。
//
//  模型只被允许整理布局与关系——system 提示明确禁止改写卡片正文。
//

import Foundation

struct AgentReply {
    var actions: [AgentAction]
    var assistantText: String
}

enum DeepSeekError: LocalizedError {
    case notConfigured
    case timedOut
    case http(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "尚未配置 DeepSeek API Key"
        case .timedOut: return "整理请求超时，已停止等待。请稍后重试。"
        case .http(let code, let msg): return "DeepSeek 请求失败（\(code)）：\(msg)"
        case .badResponse: return "DeepSeek 返回无法解析"
        }
    }
}

struct DeepSeekClient {

    private static let systemPrompt = """
    你是 Atlas 世界画布的「整理助手」。你的唯一职责是帮作者整理画布上卡片的【布局】与【关系】。

    铁律：
    1. 你绝不改写任何卡片的正文（名称、简介、设定、时间字段都不许动）。内容永远由作者自己写。
    2. 你只能通过给定的工具来动作：重新排布、聚拢卡片、移动卡片、在对象间建立/移除关系。
    3. 你不"生成设定"，只"整理已存在的东西"。若作者的话涉及角色关系（如"把艾琳娜和森林议会连起来"），用 link_objects 提议关系并给出简短类别。
    4. 一次尽量用最少的工具调用达成目标。整理整块画布优先用 arrange_canvas。
    5. 所有动作都是"提议"，最终由作者采纳。不要啰嗦解释，直接调用工具。
    6. assistantText 只写简洁、克制的中文说明：不用 emoji，不用 Markdown 标题，不用加粗符号，不复述工具清单，不使用“已为你”“以下是”“方案已提交”等汇报腔。最多 3 句。

    画布快照里给了每个对象的 id、类型、名称，以及关系的 id。引用对象/关系时必须用这些 id。
    """

    private static let creationSystemPrompt = """
    你是 Atlas 世界画布的「建档助手」。你的职责是把作者的自然语言解析成【待采纳的世界对象草稿】。

    你必须使用给定工具 propose_cards，不要直接用自然语言回答。

    可用技能：
    1. 批量新建：从列表、段落、企划设定里提取地点/角色/组织/事件/规则/物件/作品/便签。只为明确存在的世界对象建卡。
    2. 命名解析：用户说「命名为 X / 叫 X / 名称为 X」时，name 必须只填 X。
    3. 类型识别：用户明确说地点/角色/组织/事件/规则等类型时，必须尊重明确类型。
    4. 摘要整理：只有当用户给了说明时，才把说明放进 summary；不要替作者扩写设定。
    5. 不要把任务说明、列表标题、命令句或描述句当作对象名称。例如「根据下面设定创建画布卡片」永远不是卡片；「它建在会发光的盐沼上」「每次退潮后居民失声」是「雾港」的 summary，不是新的地点。
    6. 单对象保护：若用户只说「新建一个地点，命名为雾港；它建在会发光的盐沼上；每次退潮后居民失声」，cards 必须只有 1 张：{kind: location, name: 雾港, summary: 它建在会发光的盐沼上；每次退潮后居民失声}。只有明确列出多个命名对象、多个类型前缀或多条对象条目时才拆卡。
    7. 调用工具前在内部逐项自检：每个 name 是否是可独立指认的世界对象？如果不是，合并到最近一个对象的 summary 或忽略。

    边界：
    - 只提出草稿，不创建正式设定。
    - 不生成图片、不生成完整世界观。
    - 不凭空扩写超出用户提供的信息。

    输出类型 kind 必须是：map/location/character/org/event/rule/item/work/note。
    """

    private static let inspirationSystemPrompt = """
    你是 Atlas 世界创作平台的资料检索 Agent。你的角色是档案员与检索工具，不是作者。

    你只可根据用户提供的 sources 进行工作。每个灵感都必须绑定其中一个原始链接；资料不足时宁可少提或不提。事实与创作转译必须分开：fact 只写资料明示的内容，creative_angle 才能提出虚构世界的借鉴方向。

    对族群、地区习俗与宗教保持克制：避免概括、异化或将现实群体当作可挪用的素材。不要生成完整世界观、角色正文或图片。

    Atlas Agent 的输出边界：
    - 你只递「资料参照」和「可继续追问的问题」，供作者挑选；不替作者决定，不把建议写成既定设定。
    - 所有面向作者的 title、fact、creative_angle 必须使用简体中文。英文论文标题、摘要和术语要转述成自然中文；确有必要时可在中文术语后保留英文专名。
    - title 不超过 18 个汉字，直接指出资料中的现象或矛盾；不要照搬论文标题。
    - fact 是「资料参照」：只保留一条资料明确支持、与本次问题直接相关的事实，不照抄摘要，不重复标题，不超过 70 个汉字。
    - creative_angle 是「可继续追问」：写成一个开放问题，优先使用“如果……会怎样？”“可以追问：……”；不替作者命名，不直接写成世界设定，不超过 60 个汉字。
    - 像档案员递来的一张边注：准确、安静、具体，留出作者判断的空间。
    - 不用 emoji，不用 Markdown，不用“事实资料 / 创作转译 / 灵感启示”等报告标签，不用感叹号。
    - 多张卡片必须各自选择不同的信息焦点；若事实或转译实质重复，只保留其中一张。

    必须调用 propose_inspirations，不要直接用自然语言回答。
    """

    func organize(instruction: String, snapshot: String) async throws -> AgentReply {
        guard AgentConfig.isConfigured else { throw DeepSeekError.notConfigured }

        let messages: [[String: Any]] = [
            ["role": "system", "content": Self.systemPrompt],
            ["role": "user", "content": "作者的整理请求：\(instruction)\n\n当前画布快照：\n\(snapshot)"]
        ]

        // 整理结果完全由首轮 function calls 构成；不再为了获取一段补充文案
        // 继续等待最多四轮网络请求。一次响应可以包含多个工具调用。
        let message = try await request(messages: messages)
        let toolCalls = message["tool_calls"] as? [[String: Any]] ?? []
        let collected = toolCalls.compactMap { call -> AgentAction? in
            let function = call["function"] as? [String: Any] ?? [:]
            let name = function["name"] as? String ?? ""
            let arguments = function["arguments"] as? String ?? "{}"
            return AgentAction.from(name: name, argumentsJSON: arguments)
        }
        return AgentReply(
            actions: collected,
            assistantText: message["content"] as? String ?? ""
        )
    }

    func parseCanvasIntent(instruction: String, snapshot: String) async throws -> CanvasIntentReply {
        guard AgentConfig.isConfigured else { throw DeepSeekError.notConfigured }

        var messages: [[String: Any]] = [
            ["role": "system", "content": Self.creationSystemPrompt],
            ["role": "user", "content": "作者的画布指令：\(instruction)\n\n当前画布快照：\n\(snapshot)"]
        ]

        var drafts: [CanvasDraftProposal] = []
        var finalText = ""

        for _ in 0..<2 {
            let message = try await request(messages: messages, tools: AgentToolSchema.creationTools())
            let toolCalls = message["tool_calls"] as? [[String: Any]] ?? []
            if toolCalls.isEmpty {
                finalText = message["content"] as? String ?? ""
                break
            }

            messages.append(message)
            for call in toolCalls {
                let fn = call["function"] as? [String: Any] ?? [:]
                let name = fn["name"] as? String ?? ""
                let args = fn["arguments"] as? String ?? "{}"
                if name == "propose_cards" {
                    drafts.append(contentsOf: Self.parseDrafts(argumentsJSON: args))
                }
                messages.append([
                    "role": "tool",
                    "tool_call_id": call["id"] as? String ?? "",
                    "content": "已收到待采纳草稿。"
                ])
            }
            if !drafts.isEmpty { break }
        }

        return CanvasIntentReply(drafts: drafts, assistantText: finalText)
    }

    func proposeInspirations(query: String, sources: [ResearchSource]) async throws -> [InspirationCard] {
        guard AgentConfig.isConfigured else { throw DeepSeekError.notConfigured }
        let sourceText = sources.enumerated().map { index, source in
            "[\(index + 1)] title: \(source.title)\nprovider: \(source.provider)\nexcerpt: \(source.excerpt)\nsource_url: \(source.url.absoluteString)"
        }.joined(separator: "\n\n")
        let messages: [[String: Any]] = [
            ["role": "system", "content": Self.inspirationSystemPrompt],
            ["role": "user", "content": "作者正在寻找的方向：\(query)\n\n可用且已核验的资料：\n\(sourceText)"]
        ]
        let message = try await request(
            messages: messages,
            tools: AgentToolSchema.inspirationTools(),
            toolChoice: [
                "type": "function",
                "function": ["name": "propose_inspirations"]
            ]
        )
        let calls = message["tool_calls"] as? [[String: Any]] ?? []
        guard let call = calls.first,
              let function = call["function"] as? [String: Any],
              function["name"] as? String == "propose_inspirations",
              let arguments = function["arguments"] as? String else { return [] }
        return Self.parseInspirations(argumentsJSON: arguments, sources: sources)
    }

    static func parseDrafts(argumentsJSON: String) -> [CanvasDraftProposal] {
        let data = argumentsJSON.data(using: .utf8) ?? Data()
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let cards = obj["cards"] as? [[String: Any]] ?? []
        return cards.compactMap { card in
            guard let rawKind = card["kind"] as? String,
                  let kind = BuilderKind(rawValue: rawKind) else { return nil }
            let name = (card["name"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let summary = (card["summary"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return CanvasDraftProposal(kind: kind, name: name, summary: summary)
        }
    }

    static func parseInspirations(argumentsJSON: String, sources: [ResearchSource]) -> [InspirationCard] {
        let data = argumentsJSON.data(using: .utf8) ?? Data()
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let cards = object["cards"] as? [[String: Any]] ?? []
        let sourcesByURL = Dictionary(uniqueKeysWithValues: sources.map { ($0.url.absoluteString, $0) })
        var seen = Set<String>()
        return cards.compactMap { card in
            guard let title = card["title"] as? String,
                  let fact = card["fact"] as? String,
                  let angle = card["creative_angle"] as? String,
                  let sourceURL = card["source_url"] as? String,
                  let source = sourcesByURL[sourceURL] else { return nil }
            let cleanTitle = Self.cleanModelText(title, limit: 36)
            let cleanFact = Self.cleanModelText(fact, limit: 140)
            let cleanAngle = Self.cleanModelText(angle, limit: 120)
            let fingerprint = "\(cleanTitle)|\(cleanFact)"
                .lowercased()
                .components(separatedBy: .punctuationCharacters)
                .joined()
                .filter { !$0.isWhitespace }
            guard Self.containsChinese(cleanTitle),
                  Self.containsChinese(cleanFact),
                  Self.containsChinese(cleanAngle),
                  seen.insert(fingerprint).inserted else { return nil }
            return InspirationCard(
                title: cleanTitle,
                fact: cleanFact,
                creativeAngle: cleanAngle,
                source: source
            )
        }
    }

    static func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
        }
    }

    private static func cleanModelText(_ text: String, limit: Int) -> String {
        let withoutEmoji = text.filter { character in
            !character.unicodeScalars.contains {
                $0.properties.isEmojiPresentation || $0.value == 0xFE0F
            }
        }
        let withoutMarkdown = withoutEmoji
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(withoutMarkdown.prefix(limit))
    }

    /// 单轮请求，返回 choices[0].message 字典。
    private func request(
        messages: [[String: Any]],
        tools: [[String: Any]] = AgentToolSchema.tools(),
        toolChoice: [String: Any]? = nil
    ) async throws -> [String: Any] {
        let url = URL(string: "\(AgentConfig.baseURL)/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 24
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(AgentConfig.apiKey)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "model": AgentConfig.model,
            "messages": messages,
            "tools": tools,
            "temperature": 0.2,
            "stream": false
        ]
        if let toolChoice {
            body["tool_choice"] = toolChoice
        } else {
            body["tool_choice"] = "auto"
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let error as URLError where error.code == .timedOut {
            throw DeepSeekError.timedOut
        }
        guard let http = response as? HTTPURLResponse else { throw DeepSeekError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw DeepSeekError.http(http.statusCode, String(msg.prefix(300)))
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            throw DeepSeekError.badResponse
        }
        return message
    }
}
