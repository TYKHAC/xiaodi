//
//  Hestia · 直连模式（P0-1）
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
    /// OpenAI 兼容 base URL（Hestia：默认留空，用户填自己的中转/服务商地址）
    var baseURL: String
    var model: String

    static let defaultsKey = "xiaodi.directConfig"
    static let `default` = DirectConnectionConfig(
        enabled: false,
        baseURL: "",
        model: ""
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
    /// 图片附件的文件名（存在磁盘上，见 DirectImageStore）—— 用户 2026-10-12：
    /// 「图片要能发给模型」。旧消息没有这个字段 → 解码时自动为 nil（向后兼容）。
    var imageName: String?
    /// 只用来做 ForEach 的稳定 id
    var stamp = Date().timeIntervalSince1970

    var id: Double { stamp }
}

/// 直连对话的图片附件仓储 —— 用户 2026-10-12：「图片送模型」。
/// 图片写**磁盘**（Documents/direct-images/），消息里只留文件名：
/// 会话是序列化进 UserDefaults 的，把 base64 塞进消息里会很快把默认存储撑爆。
enum DirectImageStore {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("direct-images", isDirectory: true)
        if !FileManager.default.fileExists(atPath: d.path) {
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
        return d
    }

    static func url(named name: String) -> URL { dir.appendingPathComponent(name) }

    /// 等比缩到最长边 maxDimension 以内（省流量也省 token）
    static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = image.size.width
        let h = image.size.height
        guard w > 0, h > 0 else { return image }
        let longest = max(w, h)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: (w * scale).rounded(), height: (h * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// 存一张图 → 返回文件名；失败返回 nil
    static func save(_ image: UIImage) -> String? {
        let small = downscale(image, maxDimension: 1600)
        guard let data = small.jpegData(compressionQuality: 0.85) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: url(named: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    /// 读回来给气泡显示
    static func load(named name: String) -> UIImage? {
        guard let data = try? Data(contentsOf: url(named: name)) else { return nil }
        return UIImage(data: data)
    }

    /// 出网用的 base64 JPEG（不带 "data:image/jpeg;base64," 前缀）
    static func base64JPEG(named name: String, maxDimension: CGFloat = 1280) -> String? {
        guard let image = load(named: name) else { return nil }
        let small = downscale(image, maxDimension: maxDimension)
        return small.jpegData(compressionQuality: 0.8)?.base64EncodedString()
    }
}

/// 独立 agent 的本地会话 —— 用户 2026-10-09 产品决策：
/// 手机独立 agent 的会话与电脑会话**完全隔离**（共用同一个大脑，但会话列表互不显示）；
/// 未连接时抽屉只显示本地会话，电脑会话只在远程连接时出现；
/// 本地会话离线也保留（本来就是这个独立 agent 自己开的）。
struct DirectChatSession: Codable, Identifiable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var messages: [DirectChatMessage] = []
    var updatedAt: Date = Date()
}

/// 本地会话持久化（UserDefaults）。旧版单一日志自动迁移成第一个会话。
enum DirectChatLog {
    private static let sessionsKey = "xiaodi.directSessions"
    private static let activeKey = "xiaodi.directActiveSession"
    private static let legacyKey = "xiaodi.directLog"

    static func loadSessions() -> [DirectChatSession] {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let list = try? JSONDecoder().decode([DirectChatSession].self, from: data),
           !list.isEmpty {
            return list
        }
        // v1 迁移：旧的单一日志 → 第一个会话
        if let legacy = UserDefaults.standard.data(forKey: legacyKey),
           let messages = try? JSONDecoder().decode([DirectChatMessage].self, from: legacy),
           !messages.isEmpty {
            let migrated = DirectChatSession(title: "新对话", messages: messages)
            saveSessions([migrated])
            return [migrated]
        }
        return [DirectChatSession(title: "新对话")]
    }

    static func saveSessions(_ sessions: [DirectChatSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: sessionsKey)
    }

    static var activeID: String {
        get { UserDefaults.standard.string(forKey: activeKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: activeKey) }
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
        case .badEndpoint: return "接口地址不合法（形如 https://your-relay.com/v1）"
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

    /// 出网的一条消息：文本 + 可选图片 base64（不带 "data:image/jpeg;base64," 前缀）。
    /// 用户 2026-10-12：「图片送模型」。
    struct Outgoing {
        let role: String
        let text: String
        let imageBase64: String?
    }

    /// 干净的请求体：只带 role/content（时间戳、文件名这些本地字段绝不出网）。
    /// 有图时按 OpenAI 多模态格式把 content 编成 parts 数组（image_url + text），
    /// 没图时仍是纯字符串 —— 老接口/老模型不受影响。
    private static func make(
        config: DirectConnectionConfig,
        apiKey: String,
        outgoing: [Outgoing],
        stream: Bool,
        maxTokens: Int?
    ) throws -> URLRequest {
        // 注意顺序：Item 必须声明在 Body 之前 —— 函数体内的局部类型不能用未声明类型。
        struct Item: Encodable {
            let role: String
            let text: String
            let imageBase64: String?

            private enum Keys: String, CodingKey { case role, content }
            private enum PartKeys: String, CodingKey { case type, text, image_url }
            private enum URLKeys: String, CodingKey { case url }

            func encode(to encoder: Encoder) throws {
                var box = encoder.container(keyedBy: Keys.self)
                try box.encode(role, forKey: .role)
                guard let imageBase64, !imageBase64.isEmpty else {
                    try box.encode(text, forKey: .content)
                    return
                }
                var parts = box.nestedUnkeyedContainer(forKey: .content)
                var imagePart = parts.nestedContainer(keyedBy: PartKeys.self)
                try imagePart.encode("image_url", forKey: .type)
                var urlBox = imagePart.nestedContainer(keyedBy: URLKeys.self)
                try urlBox.encode("data:image/jpeg;base64,\(imageBase64)", forKey: .url)
                var textPart = parts.nestedContainer(keyedBy: PartKeys.self)
                try textPart.encode("text", forKey: .type)
                try textPart.encode(text.isEmpty ? "请看这张图。" : text, forKey: .text)
            }
        }
        struct Body: Encodable {
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
            messages: outgoing.map { Item(role: $0.role, text: $0.text, imageBase64: $0.imageBase64) },
            stream: stream,
            max_tokens: maxTokens
        ))
        return request
    }

    /// 流式对话：逐段 yield 助手增量文本（带图版本）。
    func stream(
        config: DirectConnectionConfig,
        apiKey: String,
        outgoing: [Outgoing]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try Self.make(
                        config: config,
                        apiKey: apiKey,
                        outgoing: outgoing,
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

    /// 流式对话（纯文本，老入口 —— 保留给只发文字的调用方）
    func stream(
        config: DirectConnectionConfig,
        apiKey: String,
        messages: [DirectChatMessage]
    ) -> AsyncThrowingStream<String, Error> {
        stream(
            config: config,
            apiKey: apiKey,
            outgoing: messages.map { Outgoing(role: $0.role, text: $0.content, imageBase64: nil) }
        )
    }

    /// 连接测试：小请求一发，返回模型的首段回话。
    func test(config: DirectConnectionConfig, apiKey: String) async throws -> String {
        let request = try Self.make(
            config: config,
            apiKey: apiKey,
            outgoing: [Outgoing(role: "user", text: "hi", imageBase64: nil)],
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

// MARK: - 生图 / 视频模型配置（模型配置中心 · 另两类）

/// 三类模型配置里的生图/视频两类（语言类＝DirectConnectionConfig，第15轮已上）。
/// 老规矩：非敏感配置进 UserDefaults，Key 进 Keychain。
struct MediaModelConfig: Codable, Equatable {
    var enabled: Bool
    /// OpenAI 兼容 base URL，到 /v1 一级，例：https://api.example.com/v1
    var baseURL: String
    var model: String

    static let imageDefaultsKey = "xiaodi.mediaImageConfig"
    static let videoDefaultsKey = "xiaodi.mediaVideoConfig"
    static let imageDefault = MediaModelConfig(enabled: false, baseURL: "", model: "")
    static let videoDefault = MediaModelConfig(enabled: false, baseURL: "", model: "")

    static func savedImage() -> MediaModelConfig { load(imageDefaultsKey) ?? imageDefault }
    static func savedVideo() -> MediaModelConfig { load(videoDefaultsKey) ?? videoDefault }
    func saveImage() { save(Self.imageDefaultsKey) }
    func saveVideo() { save(Self.videoDefaultsKey) }

    private static func load(_ key: String) -> MediaModelConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MediaModelConfig.self, from: data)
    }

    private func save(_ key: String) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private var trimmedBase: String {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        return base
    }

    /// OpenAI 兼容生图接口：POST {base}/images/generations
    var imagesEndpoint: URL? {
        guard !trimmedBase.isEmpty else { return nil }
        return URL(string: trimmedBase + "/images/generations")
    }
}

/// 生图/视频各自的 Keychain 槽位（和直连 Key 同一套 generic-password 做法）
enum MediaAPIKeyStore {
    private static let imageService = "com.clark.dshmobile.media-image-key"
    private static let videoService = "com.clark.dshmobile.media-video-key"

    private static func service(_ kind: MediaKeyKind) -> String {
        switch kind {
        case .image: return imageService
        case .video: return videoService
        }
    }

    static func load(_ kind: MediaKeyKind) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(kind),
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

    static func save(_ kind: MediaKeyKind, value: String) throws {
        let data = Data(value.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(kind),
            kSecAttrAccount as String: "default",
        ]
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw DirectKeychainStoreError(addStatus) }
        } else {
            guard status == errSecSuccess else { throw DirectKeychainStoreError(status) }
        }
    }

    static func delete(_ kind: MediaKeyKind) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(kind),
            kSecAttrAccount as String: "default",
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum MediaKeyKind {
    case image
    case video
}

struct DirectKeychainStoreError: LocalizedError {
    let status: OSStatus
    init(_ status: OSStatus) { self.status = status }
    var errorDescription: String? {
        (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain 错误 \(status)"
    }
}

/// 生图客户端（OpenAI 兼容 images/generations）。
/// 返回值是「可直接渲染的内容」：http(s) 图片链接，或 data:base64（中转常给这个）。
struct DirectImageClient {
    private struct GenRequest: Encodable {
        let model: String
        let prompt: String
        let n: Int
        let size: String?
    }

    private struct GenResponse: Decodable {
        struct Datum: Decodable {
            let url: String?
            let b64_json: String?
        }
        let data: [Datum]
    }

    func generate(
        config: MediaModelConfig,
        apiKey: String,
        prompt: String,
        size: String? = nil
    ) async throws -> String {
        guard let endpoint = config.imagesEndpoint else {
            throw DirectChatError.badEndpoint
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(GenRequest(
            model: config.model,
            prompt: prompt,
            n: 1,
            size: size
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DirectChatError.server("响应不是 HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data.prefix(400), encoding: .utf8) ?? ""
            throw DirectChatError.server("HTTP \(http.statusCode)：\(body.prefix(300))")
        }
        guard let parsed = try? JSONDecoder().decode(GenResponse.self, from: data),
              let first = parsed.data.first else {
            throw DirectChatError.server("响应里没有图片数据")
        }
        if let url = first.url, !url.isEmpty { return url }
        if let b64 = first.b64_json, !b64.isEmpty { return "data:image/png;base64,\(b64)" }
        throw DirectChatError.server("响应里没有 url 也没有 b64_json")
    }
}
