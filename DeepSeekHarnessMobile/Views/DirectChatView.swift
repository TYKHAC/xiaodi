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
    /// 输入框焦点 —— 用户 2026-10-12：点别处要能收键盘（不要再逼用户去点别的）
    @FocusState private var composerFocused: Bool

    /// CI 视觉自查：SIMCTL_CHILD_ZXJ_SHOT=<模式> 把某个界面状态直接摆出来（正常启动为空）
    private var shotMode: String? { ProcessInfo.processInfo.environment["ZXJ_SHOT"] }

    /// 按截图模式摆初始状态（键盘模式 / 按住说话的三个变体 / 图片气泡）
    private func applyShotMode() {
        guard let mode = shotMode else { return }
        if mode == "chat-keyboard" { keyboardMode = true }
        if mode == "chat-holding-cancel" { voiceSlide = .cancel }
        if mode == "chat-holding-totext" { voiceSlide = .toText }
        if mode == "chat-image" { seedImageShot() }
    }

    /// CI 专用：造一张测试图走一遍「落盘 → 读回 → 气泡渲染」，
    /// 这样模拟器能替我们验图片这条路（真机上还要接 API Key 才能看模型回答）。
    private func seedImageShot() {
        guard store.activeDirectSession.messages.isEmpty else { return }
        let size = CGSize(width: 320, height: 320)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setStroke()
            for step in stride(from: 0, through: 320, by: 16) {
                ctx.cgContext.move(to: CGPoint(x: step, y: 0))
                ctx.cgContext.addLine(to: CGPoint(x: 0, y: step))
            }
            UIColor(red: 0.847, green: 0.137, blue: 0.165, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 96, y: 96, width: 128, height: 128))
        }
        guard let name = DirectImageStore.save(image) else { return }
        store.appendDirectMessage(DirectChatMessage(role: "user", content: "这张图里有什么？", imageName: name))
        store.appendDirectMessage(DirectChatMessage(role: "assistant", content: "（示例回答）我看到一张网点测试图，中间有一个赤红的圆。"))
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
        // 用户 2026-10-12「主题没实现」：主题背景（纸白/墨黑 + 极淡网点）原来只挂在
        // WorkspaceView 上，而根页面早就是这一页了 —— 所以真正的页面上根本没有主题。
        .background(DeepOceanBackground())
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
            // 用户 2026-10-13：加一颗赤红点（全 App 唯一那记红，表示待命/就绪）
            HStack(spacing: 6) {
                Circle()
                    .fill(ZhuTheme.dangerRed)
                    .frame(width: 6, height: 6)
                Text("准备就绪")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.activeDirectSession.messages) { message in
                        bubble(message.role, message.content, imageName: message.imageName)
                    }
                    if !streamingText.isEmpty {
                        bubble("assistant", streamingText)
                    } else if isStreaming {
                        // 用户 2026-10-12：模型还没吐出字时，显示「Hestia 正在思考…」，
                        // 而且要有颜色（赤红 + 呼吸的三点）—— 原来这里是空白的，像卡住了。
                        thinkingRow
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
            // 用户 2026-10-12：点/划对话区就能收键盘。
            // 用 simultaneousGesture 而不是 onTapGesture —— 不然会抢掉气泡的文字选择。
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded { composerFocused = false }
            )
        }
    }

    /// 「Hestia 正在思考…」—— 模型还没吐出字时的占位（用户 2026-10-12 要加，且要有颜色）。
    /// 赤红文字 + 三个赤红点呼吸，用 TimelineView 驱动，不引额外状态。
    /// 对话两侧头像的统一尺寸 —— 用户 2026-10-14：
    /// 「对话头像两边一样大，头像搞大一点点」（原来 26pt，看着偏小且两侧不一致）。
    private static let chatAvatarSize: CGFloat = 32

    private var thinkingRow: some View {
        HStack(alignment: .top, spacing: 9) {
            Image("HestiaMark")
                .resizable()
                .scaledToFit()
                .frame(width: Self.chatAvatarSize, height: Self.chatAvatarSize)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.8)
                )
            VStack(alignment: .leading, spacing: 5) {
                Text("Hestia")
                    .font(store.nameFont.font(size: 13))
                    .tracking(store.nameFont.tracking)
                    .foregroundStyle(.secondary)
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    HStack(spacing: 5) {
                        Text("正在思考")
                            .font(.system(size: 15))
                            .foregroundStyle(ZhuTheme.dangerRed)
                        ForEach(0..<3, id: \.self) { i in
                            let phase = (t * 2 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                            Circle()
                                .fill(ZhuTheme.dangerRed)
                                .frame(width: 5, height: 5)
                                .opacity(0.25 + 0.75 * phase)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 用户自己的头像（照片优先，否则用选中的符号）—— 26pt，和 Hestia 的图标同尺寸同圆角
    private var userAvatar: some View {        Group {
            if let name = store.userAvatarImageName, let image = DirectImageStore.load(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: store.userAvatarSymbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.primary.opacity(0.06))
            }
        }
        // 和 Hestia 那边同一个尺寸（用户 2026-10-14：「两边一样大」）
        .frame(width: Self.chatAvatarSize, height: Self.chatAvatarSize)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.8)
        )
    }

    /// 对话正文字体 —— 用户 2026-10-13：「可选择的字体是针对对话的」。
    /// 用户没选（bodyFontID 为空）就用系统字体；选了就套上，字号仍按调用处给的大小。
    private func bodyFont(size: CGFloat) -> Font {
        if let chosen = store.bodyFont {
            return chosen.font(size: size)
        }
        return .system(size: size)
    }

    private func bubble(_ role: String, _ text: String, imageName: String? = nil) -> some View {
        // 用户 2026-10-11 定案：**对话不要框框** —— 纯文字，靠左右对齐区分；
        // Hestia 这边带「图标 + 名字」（头像 + Hestia 小标）。
        Group {
            if role == "user" {
                // 用户 2026-10-12：「对话头像我发信息这边的可以自己选头像」——
                // 自己这边也带头像（照片优先，否则用选的符号），和 Hestia 那边对称。
                HStack(alignment: .top, spacing: 9) {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(store.userNickname)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        if let imageName, let image = DirectImageStore.load(named: imageName) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 220, maxHeight: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                                )
                        }
                        if !text.isEmpty {
                            Text(text)
                                .textSelection(.enabled)
                                .font(bodyFont(size: 15))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    userAvatar
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                HStack(alignment: .top, spacing: 9) {
                    Image("HestiaMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: Self.chatAvatarSize, height: Self.chatAvatarSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                            .font(bodyFont(size: 15))
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

    /// 上下文用量圈 —— 用户 2026-10-14：「加上下文用量」（看到电脑端那个 31% 圈，手机没有）。
    /// 直连时拿不到真实用量（要模型服务商返回），所以**本地估算**：
    /// 估算 token（CJK 按 1 字≈1、拉丁按 4 字符≈1）/ 配置里的 contextWindow。
    /// 颜色跟随 nana：正常=墨黑/主色，超过 75% 才用那记赤红警示。
    private var contextUsageRing: some View {
        let config = DirectConnectionConfig.saved
        let used = DirectTokenEstimate.tokens(in: store.activeDirectSession.messages)
            + DirectTokenEstimate.tokens(in: systemPrompt.content)
        let window = max(1_000, config.contextWindow)
        let progress = min(1.0, max(0.0, Double(used) / Double(window)))
        let warn = progress >= 0.75

        return HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.14), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(warn ? ZhuTheme.dangerRed : Color.primary,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 13, height: 13)

            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(warn ? ZhuTheme.dangerRed : Color.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityLabel("上下文已用 \(Int(progress * 100))%")
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            // 用户 2026-10-14「加上下文用量」：有消息时才显示（空对话显示 0% 没意义）
            if !store.activeDirectSession.messages.isEmpty {
                contextUsageRing
            }

            // 手势胶囊：**只按住圆球时才出现**（不按不出现 —— 用户 2026-10-10 明确）。
            // CI 截图模式下可由 ZXJ_SHOT=chat-holding* 强制摆出（模拟器没麦克风按不出来）。
            if store.voice.state == .listening || shotMode?.hasPrefix("chat-holding") == true {
                voiceGestures
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // 麦克风/语音识别权限被拒时给出可见提示 —— 用户 2026-10-12「语音没实现」：
            // 之前 permissionDenied 被设置后没有任何界面读它，按住圆球只是静默没反应。
            if let perm = store.voice.permissionDenied, !perm.isEmpty {
                Text(perm)
                    .font(.system(size: 12))
                    .foregroundStyle(ZhuTheme.dangerRed)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
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
                    // 用户 2026-10-12「键盘的发送发不出去」：**绝不能加 axis: .vertical** ——
                    // 多行输入框的回车键是「换行」，不会触发 onSubmit，所以键盘上的发送没反应。
                    // 要长文本就靠输入框自己滚动，发送只走回车/右侧 ↑。
                    TextField("说点什么…", text: $draft)
                        .textFieldStyle(.plain)
                        .focused($composerFocused)
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

    /// 按住说话浮层（用户 2026-10-14 定稿）：
    /// · 两片**各占一半宽、整块高**（用户：「实际触发区域跟图二红框一样」）
    /// · **不要有明显边界**（去掉灰底 + 描边，只留文字；激活时字变赤红）
    /// · **不要箭头**（原来是「↖ 取消」「转文字 ↗」，现在纯文字）
    /// · 用户 2026-10-14 追加：「把这三个调高点，跟 nana 一致」
    ///   —— 「取消 / 波形 / 转文字」三样整体**上移**（原来贴在最底下），
    ///      并且统一成 nana 的黑白（文字用主题色，不用微信那种深灰块）。
    private var voiceGestures: some View {
        VStack(spacing: 0) {
            // ── 三样并排：取消 ·（波形）· 转文字，整体上移 ──
            HStack(alignment: .center, spacing: 0) {
                arcPill(
                    title: voiceSlide == .cancel ? "松开 取消" : "取消",
                    active: voiceSlide == .cancel,
                    dim: hintOpacity(for: .cancel)
                )

                // 音量波形（七根，居中，nana 的墨黑）
                HStack(alignment: .center, spacing: 3) {
                    ForEach(0..<7, id: \.self) { index in
                        Capsule()
                            .fill(Color.primary.opacity(0.85))
                            .frame(width: 4, height: waveHeight(index))
                    }
                }
                .frame(height: 30)

                arcPill(
                    title: voiceSlide == .toText ? "松开 转文字" : "转文字",
                    active: voiceSlide == .toText,
                    dim: hintOpacity(for: .toText)
                )
            }
            .frame(maxWidth: .infinity)
            // ⬆️ 这就是「调高点」：整排往上抬，不贴着屏幕底边
            .padding(.bottom, 96)

            Text(voiceSlide == .cancel
                 ? "松开 取消"
                 : (voiceSlide == .toText ? "松开 转文字" : "松开 发送"))
                .font(.system(size: 14))
                .foregroundStyle(voiceSlide == .none ? Color.secondary : ZhuTheme.dangerRed)
                .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.15), value: voiceSlide)
    }

    /// 半边提示文字（用户 2026-10-14：触发区域 = 整块，不要明显边界；跟 nana 一致）。
    /// 纯文字、无底色无描边；激活时只把文字变赤红。
    private func arcPill(title: String, active: Bool, dim: Double) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(active ? ZhuTheme.dangerRed : Color.primary)
            .frame(maxWidth: .infinity)      // 各占一半宽
            .frame(height: 96)               // 整块高 = 触发区域
            .contentShape(Rectangle())       // 整块可滑（不只是文字）
            .opacity(dim)
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
        // 有图没字也能发（用户 2026-10-12）
        isStreaming ? false : (draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImage == nil)
    }

    // MARK: - 发送 / 流式

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        // 用户 2026-10-12：光有图没字也能发
        let attached = pendingImage
        guard !text.isEmpty || attached != nil, !isStreaming else { return }
        errorMessage = nil

        let config = DirectConnectionConfig.saved
        guard let apiKey = DirectAPIKeyStore.load(), !apiKey.isEmpty else {
            errorMessage = "还没填 API Key —— 设置 → 模型 里填上（Key 只存本机 Keychain）"
            return
        }

        // 图片落盘，消息里只留文件名
        var imageName: String?
        if let attached {
            imageName = DirectImageStore.save(attached)
            pendingImage = nil
        }

        let outgoing = DirectChatMessage(role: "user", content: text, imageName: imageName)
        store.appendDirectMessage(outgoing)
        draft = ""
        streamingText = ""
        isStreaming = true

        streamTask = Task { @MainActor in
            // 用户 2026-10-14：「怎么让他回答前检索大脑」
            // —— 发出去之前先查一次长期大脑，命中就把摘要拼到这一轮消息前面。
            //    桥不在（没连电脑 / 桥没开）时 brainRecallForPrompt 返回 nil，照常发送，绝不卡住。
            let history = [systemPrompt] + store.activeDirectSession.messages
            var payload = Self.outgoingPayload(from: history)            if let recall = await store.brainRecallForPrompt(text),
               let lastIndex = payload.lastIndex(where: { $0.role == "user" }) {
                let original = payload[lastIndex]
                payload[lastIndex] = DirectChatClient.Outgoing(
                    role: original.role,
                    text: recall + "\n\n" + original.text,
                    imageBase64: original.imageBase64
                )
            }

            do {
                let stream = DirectChatClient().stream(
                    config: config,
                    apiKey: apiKey,
                    outgoing: payload
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

    /// 把本地会话编成出网负载。
    /// 图片按 base64 内联进请求 —— 每轮都重发太费流量/token，所以只带**最近 2 张**附图的
    /// 消息（够「接着问这张图」用）；更早的图降级成一句文字标记，历史和上下文不断。
    static func outgoingPayload(from messages: [DirectChatMessage]) -> [DirectChatClient.Outgoing] {
        let imageIndices = messages.indices.filter { messages[$0].imageName != nil }
        let keep = Set(imageIndices.suffix(2))
        return messages.enumerated().map { index, message in
            var base64: String?
            if keep.contains(index), let name = message.imageName {
                base64 = DirectImageStore.base64JPEG(named: name)
            }
            var text = message.content
            if message.imageName != nil && base64 == nil && text.isEmpty {
                text = "（这里是之前发的一张图）"
            }
            return DirectChatClient.Outgoing(role: message.role, text: text, imageBase64: base64)
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

/// 弧形片（用户 2026-10-12 设计稿）：上圆下平，左右各向内张开 spread 度。
/// 下边是直线、上边用二次曲线拱起 —— 像两片花瓣托着圆球。
private struct ArcPillShape: Shape {
    var spread: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        // 上端比下端窄：两侧各向内收 h*tan(6°)，形成「张开」
        let inset = h * tan(spread * .pi / 180)
        var p = Path()
        // 左下角 → 左上（上端内收）
        p.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        // 上边：拱起（控制点在上方，像圆球底部的弧）
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY - h * 0.5)
        )
        // 右上 → 右下
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // 下边：平直
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
