//
//  小弟 · 语音输入控制器
//  ─────────────────────────────────────────────────────────────
//  按住说话 → 松手 → 语音转文字 → 交给 Gateway 发消息
//
//  设计要点（每条都是踩过才知道的）：
//   1. 录音用 AVAudioSession 的 .record，播报用 .playAndRecord —— 同一套会话，
//      避免"说话时听不清自己"的经典问题
//   2. 转写用 SFSpeechRecognizer 的 on-device/网络结果；**必须有超时兜底**，
//      否则用户按住不放会一直挂着
//   3. TTS 用 AVSpeechSynthesizer，**必须在 AVAudioSession 激活后再 speak**，
//      否则第一句会被吞掉
//   4. 状态机是四态（idle/listening/transcribing/speaking），UI 只读这个状态，
//      不去猜"到底在干什么" —— 这跟 DSH 自己"illegal states unrepresentable"同一思路
//

import Foundation
import AVFoundation
import Speech

@MainActor
// 必须继承 NSObject：AVSpeechSynthesizerDelegate 是 @objc 协议，
// Swift 里想实现 @objc 协议，类就得有 NSObject 基类，否则报
// "cannot declare conformance to 'NSObjectProtocol' in Swift"。
final class VoiceInputController: NSObject, ObservableObject {

    override init() {
        super.init()
    }

    // MARK: - 对外状态（UI 只读这个）

    enum State: Equatable {
        case idle
        case listening
        case transcribing
        case speaking
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript: String = ""
    @Published private(set) var permissionDenied: String? = nil

    /// 用户按住时为 true —— UI 用它驱动圆球动画
    @Published private(set) var isHeld: Bool = false

    /// 语音播报开关（用户可以关掉只听不说）
    @Published var speakReplies: Bool = true

    /// 语音转文字后是否只填进输入框（不直接发送）—— UI 在"向右上滑 = 转文字"时置 true，
    /// AppStore 的 onTranscribed 消费后清掉它（用户 2026-10-10 定的手势）。
    var routeTranscriptToDraft: Bool = false

    // MARK: - 依赖（外部注入，便于测试与替换）

    /// 转写成功后把文字交出去 —— 由 View 层接到 store.send
    var onTranscribed: ((String) -> Void)?
    /// 有一条完整回答时触发播报
    var onReplyReady: ((String) -> Void)?

    // MARK: - 内部

    private var recorder: AVAudioRecorder?
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechSynthesizer: AVSpeechSynthesizer?
    private var audioFileURL: URL?

    /// 松手后给转写留的兜底超时；真人短句 5s 足够，拖太久说明识别器卡了
    private let transcriptionTimeout: TimeInterval = 5

    private var transcriptionDeadline: DispatchWorkItem?

    private lazy var speechLanguage: String = {
        // 中文优先（用户是中文场景）；失败时退回设备当前语言
        if SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) != nil {
            return "zh-CN"
        }
        return Locale.current.identifier
    }()

    // MARK: - 权限

    /// 首次进入对话时调用。只申请，不弹框由用户决定。
    func requestPermissionsIfNeeded() async {
        // 麦克风
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        // 语音识别
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            // requestAuthorization 只有回调版本，没有 async 重载 —— 自己包一层
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                SFSpeechRecognizer.requestAuthorization { _ in
                    cont.resume()
                }
            }
        }
        permissionDenied = checkPermissionProblem()
    }

    private func checkPermissionProblem() -> String? {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        guard mic == .authorized else {
            return mic == .denied ? "麦克风权限被拒绝，请在「设置」里打开" : nil
        }
        let speech = SFSpeechRecognizer.authorizationStatus()
        guard speech == .authorized else {
            return speech == .denied ? "语音识别权限被拒绝，请在「设置」里打开" : nil
        }
        return nil
    }

    // MARK: - 按下 / 松开

    /// 手指按下圆球
    func beginRecording() {
        guard state == .idle || state == .speaking else { return }
        stopSpeaking()          // 正在念就打断（Daisy 同款体验）
        permissionDenied = checkPermissionProblem()
        if permissionDenied != nil { return }

        isHeld = true
        transcript = ""
        state = .listening

        let session = AVAudioSession.sharedInstance()
        do {
            // playAndRecord + 默认到听筒 + 语音聊天模式 =
            // 既能录进来，又不会被当成电话而切走
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .idle
            isHeld = false
            permissionDenied = "无法启动录音：\(error.localizedDescription)"
            return
        }

        // 录音文件（虽然主要靠实时识别，但留一份便于兜底/排查）
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("xiaodi-\(UUID().uuidString).m4a")
        audioFileURL = tmp
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        do {
            recorder = try AVAudioRecorder(url: tmp, settings: settings)
            recorder?.record()
        } catch {
            state = .idle
            isHeld = false
            permissionDenied = "无法开始录音：\(error.localizedDescription)"
            return
        }

        startRecognition()
    }

    /// 手指松开
    func endRecording() {
        guard isHeld else { return }
        isHeld = false
        recorder?.stop()
        recorder = nil
        // 这里**不立刻置 idle**：要让 state 走到 .transcribing，
        // 圆球才显示"识别中"，用户才知道松手生效了
        state = .transcribing
        scheduleTranscriptionTimeout()
    }

    /// 取消（手指滑出按钮 / 用户点其他处）
    func cancelRecording() {
        guard isHeld || state == .transcribing else { return }
        isHeld = false
        recorder?.stop()
        recorder = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        cancelTimeout()
        cleanupAudioFile()
        state = .idle
        transcript = ""
    }

    // MARK: - 实时识别

    private func startRecognition() {
        recognitionTask?.cancel()
        let rz = SFSpeechRecognizer(locale: Locale(identifier: speechLanguage))
        recognizer = rz
        guard let rz, rz.isAvailable else {
            // 识别器不可用：仍然把录音存着，等松手后提示
            return
        }

        // recognizer 已就绪，现在才能问 supportsOnDeviceRecognition（实例属性）。
        // 系统支持时优先走 on-device：隐私更好、不耗流量。
        // 每次重新判定：request 是复用的，上一轮的状态不能带过来。
        request.requiresOnDeviceRecognition = false
        applyOnDeviceIfPossible()

        recognitionTask = rz.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    // 结果已定稿就可以收尾，不必等超时
                    if result.isFinal {
                        self.finishTranscription()
                    }
                }
                // 非 final 结果会继续回调；真正的 error 只在彻底失败时来
                if error != nil && self.state == .transcribing {
                    self.finishTranscription()
                }
            }
        }
    }

    private var request: SFSpeechAudioBufferRecognitionRequest = {
        let r = SFSpeechAudioBufferRecognitionRequest()
        r.shouldReportPartialResults = true      // 边说边出字，体验更像 Siri
        r.taskHint = .dictation
        // 注意：supportsOnDeviceRecognition 是【实例】属性，必须有 recognizer 实例才能问。
        // 属性初始化器里造 recognizer 太早，这里先留默认 false，
        // 由 beginRecording() 在拿到 recognizer 之后按需打开（见 applyOnDeviceIfPossible）。
        return r
    }()

    /// 只有官方明确支持时才要求 on-device，否则会直接失败。
    /// 必须在 recognizer 建好之后调用 —— supportsOnDeviceRecognition 是实例属性。
    private func applyOnDeviceIfPossible() {
        guard let recognizer,
              SFSpeechRecognizer.authorizationStatus() == .authorized,
              recognizer.supportsOnDeviceRecognition
        else { return }
        request.requiresOnDeviceRecognition = true
    }

    private func scheduleTranscriptionTimeout() {
        cancelTimeout()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.finishTranscription() }
        }
        transcriptionDeadline = work
        DispatchQueue.main.asyncAfter(deadline: .now() + transcriptionTimeout, execute: work)
    }

    private func cancelTimeout() {
        transcriptionDeadline?.cancel()
        transcriptionDeadline = nil
    }

    private func finishTranscription() {
        cancelTimeout()
        recognitionTask?.cancel()
        recognitionTask = nil

        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanupAudioFile()

        if text.isEmpty {
            state = .idle
            transcript = ""
            return
        }
        state = .idle
        onTranscribed?(text)
    }

    private func cleanupAudioFile() {
        guard let url = audioFileURL else { return }
        audioFileURL = nil
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 播报

    /// 有一条完整回答 → 念出来
    func speak(_ text: String) {
        guard speakReplies else { return }
        let clean = Self.stripForSpeech(text)
        guard !clean.isEmpty else { return }

        stopSpeaking()
        state = .speaking

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let synth = AVSpeechSynthesizer()
        speechSynthesizer = synth
        synth.delegate = self

        // 分句播报：长回答不会一口气念完，用户中途能打断
        let chunks = Self.chunkForSpeech(clean)
        for chunk in chunks {
            let u = AVSpeechUtterance(string: chunk)
            u.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
            u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.98   // 稍慢一点，听得清
            u.pitchMultiplier = 1.0
            synth.speak(u)
        }
    }

    /// 点球打断播报
    func stopSpeaking() {
        if let s = speechSynthesizer, s.isSpeaking {
            s.stopSpeaking(at: .immediate)
        }
        speechSynthesizer = nil
        if state == .speaking {
            state = .idle
        }
    }

    /// 用户点圆球时的统一入口：说话中 → 打断；空闲 → 开始
    func togglePrimaryButton() {
        if state == .speaking {
            stopSpeaking()
        } else {
            cancelRecording()
        }
    }

    // MARK: - 文本清洗

    /// 把 Markdown/代码/表格从要念的内容里去掉，只念人能听懂的部分
    static func stripForSpeech(_ raw: String) -> String {
        var t = raw
        // 代码块
        if let r = t.range(of: "```", options: .backwards) {
            let start = t.range(of: "```", range: t.startIndex..<r.lowerBound)
            if let s = start { t = String(t[t.index(after: s.upperBound)..<r.lowerBound]) }
        }
        // 行内代码
        t = t.replacingOccurrences(of: "`", with: "")
        // 图片 / 链接
        t = t.replacingOccurrences(of: #"!\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        // 标题符号 / 引用 / 列表符号
        for mark in ["#", ">", "-", "*", "_", "~"] {
            t = t.replacingOccurrences(of: "\(mark) ", with: "")
        }
        // Hestia：漏网的标记 —— **粗体**/~~删除线~~ 会把"星号"念出来
        t = t.replacingOccurrences(of: "**", with: "")
        t = t.replacingOccurrences(of: "__", with: "")
        t = t.replacingOccurrences(of: "~~", with: "")
        t = t.replacingOccurrences(of: "*", with: "")   // 斜体/残留星号，宁可丢星号不念"星"
        // 行首标题（#标题，井号后可没空格）与有序列表序号
        t = t.replacingOccurrences(of: #"(?m)^\s*#+\s*"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?m)^\s*\d+\.\s+"#, with: "", options: .regularExpression)
        // 表格竖线
        t = t.replacingOccurrences(of: "|", with: "，")
        // 连续空白
        t = t.replacingOccurrences(of: #"\n{2,}"#, with: "。", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 按句号/问号/感叹号切句，长回答也能被中途打断
    static func chunkForSpeech(_ text: String, limit: Int = 160) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in text {
            cur.append(ch)
            if "。！？!?\n".contains(ch) || cur.count >= limit {
                let piece = cur.trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty { out.append(piece) }
                cur = ""
            }
        }
        if !cur.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(cur) }
        return out
    }
}

// MARK: - 播报结束回到空闲

extension VoiceInputController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            if !synthesizer.isSpeaking { self.state = .idle }
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.state = .idle }
    }
}