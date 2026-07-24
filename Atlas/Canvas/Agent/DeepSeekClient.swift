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

    /// 单轮请求，返回 choices[0].message 字典。
    private func request(messages: [[String: Any]]) async throws -> [String: Any] {
        let url = URL(string: "\(AgentConfig.baseURL)/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(AgentConfig.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": AgentConfig.model,
            "messages": messages,
            "tools": AgentToolSchema.tools(),
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
