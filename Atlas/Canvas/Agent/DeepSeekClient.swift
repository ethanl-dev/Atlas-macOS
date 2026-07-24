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
    case http(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "尚未配置 DeepSeek API Key"
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

    画布快照里给了每个对象的 id、类型、名称，以及关系的 id。引用对象/关系时必须用这些 id。
    """

    private static let creationSystemPrompt = """
    你是 Atlas 世界画布的「建档助手」。你的职责是把作者的自然语言解析成【待采纳的世界对象草稿】。

    你必须使用给定工具 propose_cards，不要直接用自然语言回答。

    可用技能：
    1. 批量新建：从列表、段落、企划设定里提取地点/角色/组织/事件/规则/物件/作品/便签。
    2. 命名解析：用户说「命名为 X / 叫 X / 名称为 X」时，name 必须只填 X。
    3. 类型识别：用户明确说地点/角色/组织/事件/规则等类型时，必须尊重明确类型。
    4. 摘要整理：只有当用户给了说明时，才把说明放进 summary；不要替作者扩写设定。

    边界：
    - 只提出草稿，不创建正式设定。
    - 不生成图片、不生成完整世界观。
    - 不凭空扩写超出用户提供的信息。

    输出类型 kind 必须是：map/location/character/org/event/rule/item/work/note。
    """

    private static let inspirationSystemPrompt = """
    你是 Atlas 世界创作平台的「真实灵感研究员」。你不是作者，也不把现实文化、历史或自然事实直接改写成设定。

    你只可根据用户提供的 sources 进行工作。每个灵感都必须绑定其中一个原始链接；资料不足时宁可少提或不提。事实与创作转译必须分开：fact 只写资料明示的内容，creative_angle 才能提出虚构世界的借鉴方向。

    对族群、地区习俗与宗教保持克制：避免概括、异化或将现实群体当作可挪用的素材。不要生成完整世界观、角色正文或图片。
    必须调用 propose_inspirations，不要直接用自然语言回答。
    """

    func organize(instruction: String, snapshot: String) async throws -> AgentReply {
        guard AgentConfig.isConfigured else { throw DeepSeekError.notConfigured }

        var messages: [[String: Any]] = [
            ["role": "system", "content": Self.systemPrompt],
            ["role": "user", "content": "作者的整理请求：\(instruction)\n\n当前画布快照：\n\(snapshot)"]
        ]

        var collected: [AgentAction] = []
        var finalText = ""

        for _ in 0..<4 {
            let message = try await request(messages: messages)

            let toolCalls = message["tool_calls"] as? [[String: Any]] ?? []
            if toolCalls.isEmpty {
                finalText = message["content"] as? String ?? ""
                break
            }

            // 记录 assistant 的 tool_calls（协议要求回带），再为每个调用补一条 tool 结果。
            messages.append(message)
            for call in toolCalls {
                let fn = call["function"] as? [String: Any] ?? [:]
                let name = fn["name"] as? String ?? ""
                let args = fn["arguments"] as? String ?? "{}"
                if let action = AgentAction.from(name: name, argumentsJSON: args) {
                    collected.append(action)
                }
                messages.append([
                    "role": "tool",
                    "tool_call_id": call["id"] as? String ?? "",
                    "content": "已加入待采纳的整理方案。"
                ])
            }
        }

        return AgentReply(actions: collected, assistantText: finalText)
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
        let message = try await request(messages: messages, tools: AgentToolSchema.inspirationTools())
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
        return cards.compactMap { card in
            guard let title = card["title"] as? String,
                  let fact = card["fact"] as? String,
                  let angle = card["creative_angle"] as? String,
                  let sourceURL = card["source_url"] as? String,
                  let source = sourcesByURL[sourceURL] else { return nil }
            return InspirationCard(title: title, fact: fact, creativeAngle: angle, source: source)
        }
    }

    /// 单轮请求，返回 choices[0].message 字典。
    private func request(messages: [[String: Any]], tools: [[String: Any]] = AgentToolSchema.tools()) async throws -> [String: Any] {
        let url = URL(string: "\(AgentConfig.baseURL)/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(AgentConfig.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": AgentConfig.model,
            "messages": messages,
            "tools": tools,
            "tool_choice": "auto",
            "temperature": 0.2,
            "stream": false
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
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
