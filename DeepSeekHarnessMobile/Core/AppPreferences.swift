import Foundation

protocol AppPreferences: AnyObject {
    var endpoint: String { get set }
    var selectedWorkspaceID: String? { get set }
    /// 小弟：是否语音播报助手回答。默认关 —— 语音输出很吵，让用户自己开。
    var speakRepliesEnabled: Bool { get set }
    /// Hestia：启动时是否自动连电脑（远程模式手动开 —— 用户 2026-10-09 明确要求：
    /// 没主动开远程时不要自己连、更不要弹"连接失败"）。默认关。
    var remoteAutoConnectEnabled: Bool { get set }

    func loadSessions() -> [SessionSummary]
    func saveSessions(_ sessions: [SessionSummary])
    func performMigrations()
}

final class UserDefaultsAppPreferences: AppPreferences {
    // Hestia：端口修正 —— 真实 mobile-gateway 在 3081（3080 是老配置，连了必失败）
    static let defaultEndpoint = "ws://127.0.0.1:3081/ws/mobile"

    private enum Key {
        static let endpoint = "gateway.endpoint"
        static let selectedWorkspaceID = "gateway.selectedWorkspaceId"
        static let sessions = "gateway.sessions"
        static let conversationScrollAnchors = "gateway.conversationScrollAnchors"
        static let manuallyPositionedSessionIDs = "gateway.manuallyPositionedSessionIds"
        // 小弟：播报开关。不注册默认值时不存在 → 用 false（关闭）兜底。
        static let speakRepliesEnabled = "xiaodi.speakRepliesEnabled"
        // Hestia：启动自动连接。默认 false —— 远程要用户主动开。
        static let remoteAutoConnectEnabled = "xiaodi.remoteAutoConnect"
    }

    private let userDefaults: UserDefaults
    private let namespace: String
    private func key(_ value: String) -> String { namespace + value }

    init(userDefaults: UserDefaults = .standard, gatewayID: String? = nil) {
        namespace = gatewayID.map { "host.\($0)." } ?? ""
        self.userDefaults = userDefaults
    }

    var endpoint: String {
        get { userDefaults.string(forKey: key(Key.endpoint)) ?? Self.defaultEndpoint }
        set { userDefaults.set(newValue, forKey: key(Key.endpoint)) }
    }

    var selectedWorkspaceID: String? {
        get { userDefaults.string(forKey: key(Key.selectedWorkspaceID)) }
        set {
            if let newValue {
                userDefaults.set(newValue, forKey: key(Key.selectedWorkspaceID))
            } else {
                userDefaults.removeObject(forKey: key(Key.selectedWorkspaceID))
            }
        }
    }

    var speakRepliesEnabled: Bool {
        get { userDefaults.bool(forKey: key(Key.speakRepliesEnabled)) }
        set { userDefaults.set(newValue, forKey: key(Key.speakRepliesEnabled)) }
    }

    var remoteAutoConnectEnabled: Bool {
        get { userDefaults.bool(forKey: key(Key.remoteAutoConnectEnabled)) }
        set { userDefaults.set(newValue, forKey: key(Key.remoteAutoConnectEnabled)) }
    }

    func loadSessions() -> [SessionSummary] {
        guard let data = userDefaults.data(forKey: key(Key.sessions)) else { return [] }
        return (try? JSONDecoder().decode([SessionSummary].self, from: data)) ?? []
    }

    func saveSessions(_ sessions: [SessionSummary]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        userDefaults.set(data, forKey: key(Key.sessions))
    }

    func performMigrations() {
        userDefaults.removeObject(forKey: key(Key.conversationScrollAnchors))
        userDefaults.removeObject(forKey: key(Key.manuallyPositionedSessionIDs))
    }
}

/// Hestia：消息字号倍数（1.0 = 标准）。
/// 刻意用全局 UserDefaults key、不走 gateway profile 命名空间 ——
/// Markdown 主题和 ConversationView 都直接读它，必须两边看到同一个值。
enum MessageFontScale {
    static let key = "xiaodi.messageFontScale"

    static var current: Double {
        let raw = UserDefaults.standard.double(forKey: key)
        return raw > 0 ? raw : 1.0
    }

    static func set(_ value: Double) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
