//
//  Hestia · 直连聊天页（P0-1「打开就是对话」在无电脑时的落点）
//  ─────────────────────────────────────────────────────────────
//  独立于 KMP 会话 store：消息存在本地数组，走 DirectChatClient 的 SSE 流。
//  网关连不上（电脑不在/换网）时，ConversationView 的空态渲染这里 ——
//  用户打开 App 依然是「一个能打字的对话」，不会落在列表页。
//

import SwiftUI

struct DirectChatView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ""
    @State private var streamingText = ""
    @State private var isStreaming = false
    @State private var errorMessage: String?
    @State private var streamTask: Task<Void, Never>?
    /// 按住圆球时的手势方向（决定上方显示「取消」还是「滑到这里 转文字」）
    @State private var voiceSlide: VoiceSlideMode = .none

    /// 直连上下文里给模型的身份。远程（电脑端）身份由 DSH 自己管，这里只管直连。
    private var systemPrompt: DirectChatMessage {
        DirectChatMessage(
            role: "system",
            content: "你是「Hestia」，用户的专属手机 AI 助手。回答尽量简洁、直接，用中文。"
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.activeDirectSession.messages.isEmpty && streamingText.isEmpty {
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
        // 「向右上滑 = 转文字」：识别结果填进输入框，不直接发送
        .onChange(of: store.voiceDraftToComposer) { _, text in
            guard let text, !text.isEmpty else { return }
            draft = text
            store.voiceDraftToComposer = nil
        }
    }

    // MARK: - 欢迎态

    private var welcome: some View {
        VStack(spacing: 14) {
            Image(systemName: "water.waves")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("你的独立 agent")
                .font(.title3.weight(.semibold))
            Text("模型配好就能直接聊；和电脑端共用一颗大脑。")
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
                    ForEach(store.activeDirectSession.messages) { message in
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
            .onChange(of: store.activeDirectSession.messages) { _, _ in
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
                // Hestia主题 v1：用户气泡与远端对话页完全一致
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
        VStack(spacing: 0) {
            // 手势胶囊：**只按住圆球时才出现**（不按不出现 —— 用户 2026-10-10 明确）
            if store.voice.state == .listening {
                voiceGestures
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 9) {
                // 语音球：按住说话（左上滑取消 / 右上滑转文字）
                SiriMicButton(
                    voice: store.voice,
                    diameter: 38,
                    reduceMotion: reduceMotion,
                    onSlideModeChange: { voiceSlide = $0 }
                )

                TextField("说点什么…", text: $draft, axis: .vertical)
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
                        .foregroundStyle(sendDisabled ? Color.secondary : ZhuTheme.accent)
                }
                .disabled(sendDisabled)
                .accessibilityLabel(isStreaming ? "停止" : "发送")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .animation(.easeOut(duration: 0.18), value: store.voice.state)
        .background(.thinMaterial)
    }

    /// 按住说话时上方的两块深色胶囊（照用户给的参考图：左「取消」/ 右更宽的「滑到这里 转文字」）
    private var voiceGestures: some View {
        HStack(spacing: 14) {
            Text("取消")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .padding(.horizontal, 22)
                .frame(minWidth: 88)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(voiceSlide == .cancel
                              ? Color(red: 0.84, green: 0.30, blue: 0.29)
                              : Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.80))
                )

            Text("滑到这里 转文字")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .padding(.horizontal, 30)
                .frame(minWidth: 88)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(voiceSlide == .toText
                              ? DSHColor.ocean
                              : Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.80))
                )
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.15), value: voiceSlide)
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
            errorMessage = "还没填 API Key —— 设置 → 模型 里填上（Key 只存本机 Keychain）"
            return
        }

        let outgoing = DirectChatMessage(role: "user", content: text)
        store.appendDirectMessage(outgoing)
        draft = ""
        streamingText = ""
        isStreaming = true

        let history = [systemPrompt] + store.activeDirectSession.messages
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
        store.appendDirectMessage(DirectChatMessage(role: "assistant", content: text))
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
            return e.errorDescription ?? "请求失败"
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
