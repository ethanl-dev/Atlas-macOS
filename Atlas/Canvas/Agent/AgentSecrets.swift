//
//  AgentSecrets.swift
//  本地密钥。⚠️ 不要提交到公开仓库——建议加进 .gitignore。
//  优先级：环境变量 DEEPSEEK_API_KEY > 设置页(UserDefaults) > 这里的默认值。
//

import Foundation

enum AgentSecrets {
    /// DeepSeek API Key。从环境变量读取，不写死在代码里。
    static let deepSeekAPIKey: String = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
}
