//
//  AgentConfig.swift
//  DeepSeek 接入配置。用户 2026-07-24 确认：Swift 直连 DeepSeek API。
//
//  安全：不硬编码密钥。优先读环境变量 DEEPSEEK_API_KEY，其次读 UserDefaults
//  （由设置页写入）。没有 key 时 CanvasOrganizer 自动退回本地启发式 mock，
//  交互链路照样能跑通，方便先看效果。
//

import Foundation

enum AgentConfig {
    /// 环境变量 > 设置页(UserDefaults)。未配置时使用本地启发式整理。
    static var apiKey: String {
        if let k = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"],
           !k.trimmingCharacters(in: .whitespaces).isEmpty {
            return k
        }
        if let k = UserDefaults.standard.string(forKey: Self.keyDefaultsKey),
           !k.trimmingCharacters(in: .whitespaces).isEmpty {
            return k
        }
        return AgentSecrets.deepSeekAPIKey.trimmingCharacters(in: .whitespaces)
    }

    static let keyDefaultsKey = "atlas.deepseek.apiKey"

    /// DeepSeek OpenAI 兼容端点。
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "atlas.deepseek.baseURL") ?? "https://api.deepseek.com"
    }

    /// 模型串。默认使用适合画布交互的 DeepSeek v4 Flash。
    static var model: String {
        UserDefaults.standard.string(forKey: "atlas.deepseek.model") ?? "deepseek-v4-flash"
    }

    static var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 便捷写入（供设置页调用）。
    static func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: keyDefaultsKey)
    }
    static func setModel(_ model: String) {
        UserDefaults.standard.set(model, forKey: "atlas.deepseek.model")
    }
    static func setBaseURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "atlas.deepseek.baseURL")
    }
}
