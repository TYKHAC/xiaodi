//
//  小弟 · Siri 风格的圆形麦克风按钮
//  ─────────────────────────────────────────────────────────────
//  规格（照 Siri 来）：
//    · 直径 44pt —— Apple 触控最小目标尺寸，不多不少
//    · 静止：灰底 + 麦克风描边符号
//    · 按住：渐变色（Siri 那个彩虹感）+ 呼吸波纹
//    · 识别中：圆环旋转 + 麦克风变实心
//    · 播报中：喇叭符号 + 声波动画，点一下打断
//
//  用 SF Symbols（mic.circle / mic.fill / speaker.wave.2.fill）——
//  系统图标自带 iOS 版本适配，不用自己画，也不会丑。
//

import SwiftUI

struct SiriMicButton: View {
    @ObservedObject var voice: VoiceInputController
    /// 图标尺寸（默认 44 = 系统最小触控区）
    var diameter: CGFloat = 44
    /// 是否降低动效（无障碍）
    var reduceMotion: Bool = false

    @State private var pulse = false

    private var isRecording: Bool { voice.state == .listening }
    private var isTranscribing: Bool { voice.state == .transcribing }
    private var isSpeaking: Bool { voice.state == .speaking }

    /// Siri 的多色渐变（青→蓝→紫），静止态只露一点点，按下才全开
    private var siriGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.85, blue: 0.75),
                Color(red: 0.25, green: 0.60, blue: 0.98),
                Color(red: 0.60, green: 0.40, blue: 0.96),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button {
            // 播报中 → 打断；空闲 → 进入"准备按住"的提示态
            voice.togglePrimaryButton()
        } label: {
            ZStack {
                // 录音时的呼吸波纹（两圈，错开相位）
                if isRecording && !reduceMotion {
                    ring(scale: 1.0, opacity: 0.45, delay: 0)
                    ring(scale: 1.35, opacity: 0.22, delay: 0.35)
                }

                // 底圆
                Circle()
                    .fill(background)
                    .frame(width: diameter, height: diameter)
                    .shadow(color: shadowColor, radius: isRecording ? 12 : 4, y: 2)

                // 图标
                Image(systemName: symbolName)
                    .font(.system(size: diameter * 0.42, weight: .semibold))
                    .foregroundStyle(foreground)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: diameter * 1.5, height: diameter * 1.5)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // 按住说话 —— 这是整个交互的核心
        .onLongPressGesture(
            minimumDuration: 0.12,      // 轻点不误触发
            maximumDistance: 40,        // 手指滑出 40pt 内仍算按住
            pressing: { pressing in
                if pressing {
                    voice.beginRecording()
                } else {
                    voice.endRecording()
                }
            },
            perform: { }
        )
        // 真的松手（滑出后抬起）也要结束，不能卡在 listening
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if voice.isHeld { voice.endRecording() }
                }
        )
        .accessibilityLabel(String(localized: "按住说话", defaultValue: "按住说话"))
        .accessibilityHint(String(localized: "长按麦克风说话，松开后发送", defaultValue: "长按麦克风说话，松开后发送"))
        .onAppear {
            if !reduceMotion { pulse = true }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.22),
            value: voice.state
        )
    }

    // MARK: - 外观

    private var symbolName: String {
        if isSpeaking { return "speaker.wave.2.fill" }
        if isTranscribing { return "mic.fill" }
        return "mic"
    }

    private var foreground: Color {
        if isRecording || isTranscribing || isSpeaking { return .white }
        return .primary
    }

    private var background: AnyShapeStyle {
        if isRecording || isTranscribing { return AnyShapeStyle(siriGradient) }
        if isSpeaking {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.85, blue: 0.75),
                        Color(red: 0.25, green: 0.60, blue: 0.98),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.secondary.opacity(0.14))
    }

    private var shadowColor: Color {
        isRecording || isTranscribing
            ? Color(red: 0.35, green: 0.55, blue: 0.98).opacity(0.55)
            : .clear
    }

    private func ring(scale: CGFloat, opacity: Double, delay: Double) -> some View {
        Circle()
            .stroke(
                Color(red: 0.35, green: 0.60, blue: 0.98),
                lineWidth: 2
            )
            .frame(width: diameter, height: diameter)
            .scaleEffect(pulse ? scale + 0.28 : scale)
            .opacity(pulse ? 0 : opacity)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(delay),
                value: pulse
            )
    }
}

// MARK: - 状态小标签（可选，显示在按钮上方）

struct VoiceStateBadge: View {
    @ObservedObject var voice: VoiceInputController

    private var text: String {
        switch voice.state {
        case .idle: return ""
        case .listening: return String(localized: "聆听中", defaultValue: "聆听中")
        case .transcribing: return String(localized: "识别中", defaultValue: "识别中")
        case .speaking: return String(localized: "播报中", defaultValue: "播报中")
        }
    }

    private var tint: Color {
        switch voice.state {
        case .listening: return .red
        case .transcribing: return .orange
        case .speaking: return .green
        case .idle: return .secondary
        }
    }

    var body: some View {
        if !text.isEmpty {
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(text).font(.caption2).foregroundStyle(.secondary)
                if voice.state == .listening && !voice.transcript.isEmpty {
                    Text(voice.transcript)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

#Preview {
    @Previewable @StateObject var voice = VoiceInputController()
    HStack(spacing: 24) {
        SiriMicButton(voice: voice)
        SiriMicButton(voice: voice, diameter: 52)
        VoiceStateBadge(voice: voice)
    }
    .padding()
}
