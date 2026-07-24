import Foundation
import OSLog

/// Agent 行为的最小埋点层。只记录产品决策所需的上下文，绝不上传用户指令或卡片正文。
enum AgentTelemetry {
    private static let logger = Logger(subsystem: "com.atlas.app", category: "agent")

    static func track(_ name: String, properties: [String: String] = [:]) {
        let safeProperties = properties
            .filter { !$0.key.contains("text") && !$0.key.contains("query") && !$0.key.contains("content") }
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ",")
        logger.notice("event=\(name, privacy: .public) \(safeProperties, privacy: .public)")
        NotificationCenter.default.post(
            name: .atlasAgentTelemetry,
            object: nil,
            userInfo: ["event": name, "properties": safeProperties]
        )
    }
}

extension Notification.Name {
    static let atlasAgentTelemetry = Notification.Name("atlas.agent.telemetry")
}
