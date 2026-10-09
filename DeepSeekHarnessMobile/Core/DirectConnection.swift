//
//  朱小姐 · 直连模式（P0-1）
//  ─────────────────────────────────────────────────────────────
//  App 自己调 OpenAI 兼容端点跑对话（自带中转 key），
//  无电脑也能聊 —— 用户拍板的「直连 + 远程」双模式之一。
//
//  · 非敏感配置（开关/地址/模型）→ UserDefaults
//  · API Key → iOS Keychain（与网关设备 token 同一套做法，绝不落明文）
//  · SSE 流式解析按 OpenAI 兼容规范：data: {...} / data: [DONE]
//

import Foundation
import Security

// MARK: - 配置

struct DirectConnectionConfig: Codable, Equatable {
    var enabled: Bool
    /// OpenAI 兼容 base URL，例：https://api.deepseek.com/v1
    var baseURL: String
    var model: String

    static let defaultsKey = "xiaodi.directConfig"
    static let `default` = DirectConnectionConfig(
        enabled: false,
        baseURL: "https://api.deepseek.com/v1",
        model: "deepseek-chat"
    )

    static var saved: DirectConnectionConfig {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode(DirectConnectionConfig.self, from: data) else {
            return .default
        }
        return value
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    /// 组装出完整接口地址（允许用户只填到域名）
    var endpoint: URL? {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        return URL(string: base + "/chat/completions")
    }
}

// MARK: - Keychain 里的 API Key

enum DirectAPIKeyStore {
    private static let service = "com.clark.dshmobile.direct-openai-key"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "default",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else { return nil }
        return value
    }

    static func save(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(trimmed.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "default",
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw DirectKeychainError(addStatus) }
        } else {
            guard status == errSecSuccess else { throw DirectKeychainError(status) }
        }
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "default",
        ]
        SecItemDelete(query as CFDictionary)
    }

    private struct DirectKeychainError: LocalizedError {
        let status: OSStatus
        init(_ status: OSStatus) { self.status = status }
        var errorDescription: String? {
            (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain 错误 \(status)"
        }
    }
}

// MARK: - 聊天消息

struct DirectChatMessage: Codable, Equatable, Identifiable, Hashable {
    var role: String // "user" | "assistant" | "system"
    var content: String
    /// 只用来做 ForEach 的稳定 id
    var stamp = Date().timeIntervalSince1970

    var id: Double { stamp }
}

/// 直连会话日志（用户/助手消息），简单持久化到 UserDefaults，换会话不清。
enum DirectChatLog {
    private static let key = "xiaodi.directLog"

    static func load() -> [DirectChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([DirectChatMessage].self, from: data) else { return [] }
        return list
    }

    static func save(_ messages: [DirectChatMessage]) {
        // system 消息是发请求时拼的，不落盘
        let persistable = messages.filter { $0.role != "system" }
        guard let data = try? JSONEncoder().encode(persistable) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - 连接测试状态

enum DirectTestState: Equatable {
    case testing
    case ok(String)
    case fail(String)
}

// MARK: - SSE 流式客户端（OpenAI 兼容）

enum DirectChatError: LocalizedError {
    case badEndpoint
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badEndpoint: return "接口地址不合法（形如 https://api.deepseek.com/v1）"
        case .server(let detail): return detail
        }
    }
}

struct DirectChatClient {
    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta?
        }
        let choices: [Choice]
    }

    private struct PlainChunk: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message?
        }
        let choices: [Choice]
    }

    /// 干净的请求体：只带 role/content（时间戳是本地图字段，绝不出网）
    private static func make(
        config: DirectConnectionConfig,
        apiKey: String,
        messages: [DirectChatMessage],
        stream: Bool,
        maxTokens: Int?
    ) throws -> URLRequest {
        struct Body: Encodable {
            struct Item: Encodable {
                let role: String
                let content: String
            }
            let model: String
            let messages: [Item]
            let stream: Bool
            let max_tokens: Int?
        }
        let url = URL(string: {
            var base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            while base.hasSuffix("/") { base.removeLast() }
            return base + "/chat/completions"
        }())
        guard let url else { throw DirectChatError.badEndpoint }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Body(
            model: config.model,
            messages: messages.map { .init(role: $0.role, content: $0.content) },
            stream: stream,
            max_tokens: maxTokens
        ))
        return request
    }

    /// 流式对话：逐段 yield 助手增量文本。
    func stream(
        config: DirectConnectionConfig,
        apiKey: String,
        messages: [DirectChatMessage]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try Self.make(
                        config: config,
                        apiKey: apiKey,
                        messages: messages,
                        stream: true,
                        maxTokens: nil
                    )
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw DirectChatError.server("响应不是 HTTP")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        var body = ""
                        for try await line in bytes.lines { body += line; if body.count > 400 { break } }
                        throw DirectChatError.server("HTTP \(http.statusCode)：\(body.prefix(300))")
                    }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard trimmed.hasPrefix("data:") else { continue }
                        let payload = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                              let text = chunk.choices.first?.delta?.content,
                              !text.isEmpty else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 连接测试：小请求一发，返回模型的首段回话。
    func test(config: DirectConnectionConfig, apiKey: String) async throws -> String {
        let hi = DirectChatMessage(role: "user", content: "hi")
        let request = try Self.make(
            config: config,
            apiKey: apiKey,
            messages: [hi],
            stream: false,
            maxTokens: 16
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DirectChatError.server("响应不是 HTTP") }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data.prefix(400), encoding: .utf8) ?? ""
            throw DirectChatError.server("HTTP \(http.statusCode)：\(body.prefix(300))")
        }
        guard let parsed = try? JSONDecoder().decode(PlainChunk.self, from: data),
              let text = parsed.choices.first?.message?.content, !text.isEmpty else {
            return "已连通（响应格式未解析出文本）"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
