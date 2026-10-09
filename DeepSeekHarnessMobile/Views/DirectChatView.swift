//
//  朱小姐 · 直连聊天页（P0-1「打开就是对话」在无电脑时的落点）
//  ─────────────────────────────────────────────────────────────
//  独立于 KMP 会话 store：消息存在本地数组，走 DirectChatClient 的 SSE 流。
//  网关连不上（电脑不在/换网）时，ConversationView 的空态渲染这里 ——
//  用户打开 App 依然是「一个能打字的对话」，不会落在列表页。
//

import SwiftUI

struct DirectChatView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var messages: [DirectChatMessage] = DirectChatLog.load()
    @State private var draft = ""
    @State private var streamingText = ""
    @State private var isStreaming = false
    @State private var errorMessage: String?
    @State private var streamTask: Task<Void, Never>?

    /// 直连上下文里给模型的身份。远程（电脑端）身份由 DSH 自己管，这里只管直连。
    private var systemPrompt: DirectChatMessage {
        DirectChatMessage(
            role: "system",
            content: "你是「朱小姐」，用户的专属手机 AI 助手。回答尽量简洁、直接，用中文。"
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty && streamingText.isEmpty {
                welcome
            } else {
                messageList
            }
            if let errorMessage {
                errorBar(errorMessage)
            }
            inputBar
        }
        .onDisappear { streamTask?.cancel() }
    }

    // MARK: - 欢迎态

    private var welcome: some View {
        VStack(spacing: 14) {
            Image(systemName: "water.waves")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("朱小姐 · 直连模式")
                .font(.title3.weight(.semibold))
            Text("没连上电脑时也能直接聊。回答来自你配置的模型端点。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        bubble(message.role, message.content)
                    }
                    if !streamingText.isEmpty {
                        bubble("assistant", streamingText)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .onChange(of: messages) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: streamingText) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func bubble(_ role: String, _ text: String) -> some View {
        HStack {
            if role == "user" { Spacer(minLength: 48) }
            Text(text)
                .textSelection(.enabled)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                // 朱小姐主题 v1：用户气泡与远端对话页完全一致
                // （淡染+描边+自适应，ZhuTheme 统一取值，不再各页各画）
                .background(
                    role == "user"
                        ? AnyShapeStyle(ZhuTheme.accentFill(dark: colorScheme == .dark))
                        : AnyShapeStyle(Color(uiColor: .secondarySystemBackground)),
                    in: RoundedRectangle(cornerRadius: ZhuTheme.radiusBubble, style: .continuous)
                )
                .overlay {
                    if role == "user" {
                        RoundedRectangle(cornerRadius: ZhuTheme.radiusBubble, style: .continuous)
                            .strokeBorder(
                                ZhuTheme.accentStroke(dark: colorScheme == .dark),
                                lineWidth: 0.7
                            )
                    }
                }
                .foregroundStyle(.primary)
            if role == "user" { EmptyView() } else { Spacer(minLength: 48) }
        }
    }

    private func errorBar(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .lineLimit(3)
            Spacer()
            Button("设置") {
                // 由宿主（ConversationView 所在导航）负责跳设置页
                NotificationCenter.default.post(name: .zxjOpenDirectSettings, object: nil)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - 输入

    private var inputBar: some View {
        HStack(spacing: 9) {
            TextField("和朱小姐说点什么…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .submitLabel(.send)
                .onSubmit { send() }
                .disabled(isStreaming)

            Button {
                if isStreaming { stop() } else { send() }
            } label: {
                Image(systemName: isStreaming ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(sendDisabled ? Color.secondary : Color.accentColor)
            }
            .disabled(sendDisabled)
            .accessibilityLabel(isStreaming ? "停止" : "发送")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.thinMaterial)
    }

    private var sendDisabled: Bool {
        isStreaming ? false : draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 发送 / 流式

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        errorMessage = nil

        let config = DirectConnectionConfig.saved
        guard let apiKey = DirectAPIKeyStore.load(), !apiKey.isEmpty else {
            errorMessage = "还没填 API Key —— 设置 → 直连模式 里填上（存进 Keychain）"
            return
        }

        let outgoing = DirectChatMessage(role: "user", content: text)
        messages.append(outgoing)
        DirectChatLog.save(messages)
        draft = ""
        streamingText = ""
        isStreaming = true

        let history = [systemPrompt] + messages
        streamTask = Task { @MainActor in
            do {
                let stream = DirectChatClient().stream(
                    config: config,
                    apiKey: apiKey,
                    messages: history
                )
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    streamingText += chunk
                }
                finishAssistant()
            } catch {
                isStreaming = false
                // 空手而归（连报错都没吐出一个字）才报错；否则照样收进记录
                if streamingText.isEmpty {
                    errorMessage = errorText(error)
                } else {
                    finishAssistant()
                    self.errorMessage = errorText(error)
                }
            }
        }
    }

    private func finishAssistant() {
        isStreaming = false
        let text = streamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        streamingText = ""
        guard !text.isEmpty else { return }
        messages.append(DirectChatMessage(role: "assistant", content: text))
        DirectChatLog.save(messages)
        // 播报开关开着 → 直连回答也念（和远程模式同一个总开关）
        if store.speakRepliesEnabled {
            store.voice.speak(text)
        }
    }

    private func stop() {
        streamTask?.cancel()
        streamTask = nil
        finishAssistant()
    }

    private func errorText(_ error: Error) -> String {
        switch error {
        case let e as DirectChatError:
            return e.errorDescription ?? "直连失败"
        case is CancellationError:
            return ""
        default:
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain {
                return "网络错误（\(ns.code)）—— 检查地址与网络"
            }
            return error.localizedDescription
        }
    }
}

/// 直连设置页跳转信号（由宿主接）
extension Notification.Name {
    static let zxjOpenDirectSettings = Notification.Name("zxj.openDirectSettings")
}
