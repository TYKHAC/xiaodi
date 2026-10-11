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
    /// 底部栏模式：false = 语音模式（圆球居中），true = 键盘模式（输入框）
    @State private var keyboardMode = false
    /// 相机（用户 2026-10-11 第 2 项）：点按 = 拍照，长按 = 下方弹图库
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    /// 待发送的图片（先挂缩略图；送模型的链路后续接）
    @State private var pendingImage: UIImage?

    /// CI 视觉自查：SIMCTL_CHILD_ZXJ_SHOT=<模式> 把某个界面状态直接摆出来（正常启动为空）
    private var shotMode: String? { ProcessInfo.processInfo.environment["ZXJ_SHOT"] }

    /// 按截图模式摆初始状态（键盘模式 / 按住说话的三个变体）
    private func applyShotMode() {
        guard let mode = shotMode else { return }
        if mode == "chat-keyboard" { keyboardMode = true }
        if mode == "chat-holding-cancel" { voiceSlide = .cancel }
        if mode == "chat-holding-totext" { voiceSlide = .toText }
    }

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
            if let pendingImage {
                pendingImageBar(pendingImage)
            }
            inputBar
        }
        // 相机 / 相册（第 2 项）
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapturePicker { image in pendingImage = image }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryPicker { image in pendingImage = image }
                .ignoresSafeArea()
        }
        .onDisappear { streamTask?.cancel() }
        .onAppear { applyShotMode() }
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
            // 用户 2026-10-10：这里改成「图标 + 名字 + 准备就绪」—— 图标就是 App 图标，
            // 让它当视觉主角（主题 = 图标那套黑白线稿风格）。
            Image("HestiaMark")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
            // 名字字体：用户 2026-10-11 做成「自定义字体选择」——设置里挑，这里跟着变
            Text("Hestia")
                .font(store.nameFont.font(size: 27))
                .tracking(store.nameFont.tracking)
                .foregroundStyle(.primary)
            Text("准备就绪")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        // 用户 2026-10-11 定案：**对话不要框框** —— 纯文字，靠左右对齐区分；
        // Hestia 这边带「图标 + 名字」（头像 + Hestia 小标）。
        Group {
            if role == "user" {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("你")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(text)
                        .textSelection(.enabled)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                HStack(alignment: .top, spacing: 9) {
                    Image("HestiaMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.8)
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        // 名字字体统一（用户 2026-10-11 图一）：气泡上的名字也一样
                        Text("Hestia")
                            .font(store.nameFont.font(size: 13))
                            .tracking(store.nameFont.tracking)
                            .foregroundStyle(.secondary)
                        Text(text)
                            .textSelection(.enabled)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// 待发送图片的缩略图条（第 2 项）：拍完/选完图先挂在这儿，可点 × 去掉
    private func pendingImageBar(_ image: UIImage) -> some View {
        HStack(spacing: 10) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                )
            Text("待发送图片")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                pendingImage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("移除图片")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
            // 手势胶囊：**只按住圆球时才出现**（不按不出现 —— 用户 2026-10-10 明确）。
            // CI 截图模式下可由 ZXJ_SHOT=chat-holding* 强制摆出（模拟器没麦克风按不出来）。
            if store.voice.state == .listening || shotMode?.hasPrefix("chat-holding") == true {
                voiceGestures
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 9) {
                // 相机（最左）：点按 = 拍照；长按 = 下方弹图库（用户 2026-10-11 第 2 项）
                Image(systemName: "camera")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
                    .onTapGesture { showCamera = true }
                    .onLongPressGesture(minimumDuration: 0.35) { showPhotoLibrary = true }
                    .accessibilityLabel("拍照或选图")

                // 语音球：按住说话（左上滑取消 / 右上滑转文字）
                // 底部栏双模式（用户 2026-10-11 定案）：
                //   语音模式 = 圆球居中贴底（按住说话）；键盘模式 = 输入框 + 发送
                if keyboardMode {
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
                } else {
                    Spacer(minLength: 0)
                    SiriMicButton(
                        voice: store.voice,
                        diameter: 56,
                        reduceMotion: reduceMotion,
                        onSlideModeChange: { voiceSlide = $0 }
                    )
                    Spacer(minLength: 0)
                }

                // 右：键盘 / 语音 切换（点一下换模式）
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { keyboardMode.toggle() }
                } label: {
                    Image(systemName: keyboardMode ? "waveform" : "keyboard")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel(keyboardMode ? "切到语音模式" : "切到键盘模式")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            // 用户 2026-10-11 图二：「圆球再往上一点点」——底部留白加大，整条栏抬起来
            .padding(.bottom, 14)
        }
        .animation(.easeOut(duration: 0.18), value: store.voice.state)
        // 用户 2026-10-11 图二：「不要灰色背景…然后虚化」——把原来那块灰板换成毛玻璃，
        // 纸白 + 网点能透上来，不再是另贴的一块板
        .background(.ultraThinMaterial)
    }

    /// 按住说话 = 照微信那套（用户 2026-10-11）：
    /// 左上「取消」、右上「转文字」，中间音量波形，球下方「松开 发送」。
    /// 左上滑 → 取消变红；右上滑 → 转文字变红；没滑动的那一侧**虚化**（用户 2026-10-11 图二）。
    private var voiceGestures: some View {
        VStack(spacing: 12) {
            HStack {
                // 用户图二：不要箭头、字体再大一点；非激活侧虚化
                Text(voiceSlide == .cancel ? "松开 取消" : "取消")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(voiceSlide == .cancel ? ZhuTheme.dangerRed : Color.primary)
                    .opacity(hintOpacity(for: .cancel))
                Spacer(minLength: 0)
                Text(voiceSlide == .toText ? "转文字 ✓" : "转文字")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(voiceSlide == .toText ? ZhuTheme.dangerRed : Color.primary)
                    .opacity(hintOpacity(for: .toText))
            }
            .padding(.horizontal, 18)

            // 音量波形（七根）
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(Color.primary.opacity(0.75))
                        .frame(width: 4, height: waveHeight(index))
                }
            }
            .frame(height: 26)

            Text(voiceSlide == .cancel
                 ? "松开手指，取消发送"
                 : (voiceSlide == .toText ? "松开转成文字，填进输入框" : "松开 发送"))
                .font(.system(size: 14))
                .foregroundStyle(voiceSlide == .none ? Color.secondary : ZhuTheme.dangerRed)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.15), value: voiceSlide)
    }

    /// 两侧提示的透明度：正在滑的那一侧清晰，另一侧虚化；
    /// 完全没滑时两侧都稍微压一点（用户 2026-10-11 图二「然后虚化」）。
    private func hintOpacity(for side: VoiceSlideMode) -> Double {
        if voiceSlide == .none { return 0.55 }
        return voiceSlide == side ? 1.0 : 0.30
    }

    /// 波形高度（固定一组，配合 TimelineView 的呼吸感；简单稳妥，不引音频电平）
    private func waveHeight(_ index: Int) -> CGFloat {
        let pattern: [CGFloat] = [9, 18, 25, 13, 21, 11, 16]
        return pattern[index % pattern.count]
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
