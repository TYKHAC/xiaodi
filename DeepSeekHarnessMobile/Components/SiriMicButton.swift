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
    private var isIdle: Bool { !isRecording && !isTranscribing && !isSpeaking }

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

                // 底圆：闲着＝珍珠圆球，按住/播报时才切成渐变色。
                // 朱小姐：不放任何图标 —— 用户要的就是一颗纯圆球；
                // 语音状态靠「变大 + 波纹 + 底色」表达，文字提示由 VoiceStateBadge 负责。
                Group {
                    if isIdle {
                        PearlOrbView()
                    } else {
                        Circle().fill(background)
                    }
                }
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
                .shadow(color: shadowColor, radius: isRecording ? 14 : 6, y: 3)
                .scaleEffect(orbScale)
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
        .accessibilityHint(String(localized: "长按说话，松开后发送", defaultValue: "长按说话，松开后发送"))
        .onAppear {
            if !reduceMotion { pulse = true }
            orbScale = isIdle ? 1 : Self.activeScale
        }
        // 选中语音输入（进入聆听/识别/播报）→ 圆球弹大；回到空闲 → 弹回。
        .onChange(of: isIdle) { _, idle in
            setOrbScale(idle ? 1 : Self.activeScale)
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.22),
            value: voice.state
        )
    }

    // MARK: - 选中/录音中的圆球动效

    /// 语音激活态的目标放大倍数（珍珠球从 54 → 约 63pt，明显但不挤）
    private static let activeScale: CGFloat = 1.16

    @State private var orbScale: CGFloat = 1

    private func setOrbScale(_ target: CGFloat) {
        if reduceMotion {
            orbScale = target
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.58)) {
            orbScale = target
        }
    }

    // MARK: - 外观

    // 朱小姐：不放图标 —— 圆球本身（珍珠质感/激活渐变）就是全部视觉，
    // 状态区分交给 scaleEffect(1.16) + 波纹 + VoiceStateBadge 文字。

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

// MARK: - 珍珠圆球（朱小姐的语音键质感）

/// 虹彩珍珠质感：四团柔光（粉/蓝/薄荷/紫）+ 一条高光，
/// 全部用渐变叠出来，不依赖图片资源，所以不用往 Assets 里加东西。
struct PearlOrbView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.95, blue: 0.98),
                    Color(red: 0.92, green: 0.95, blue: 1.00),
                    Color(red: 0.91, green: 0.99, blue: 0.97),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white, Color(red: 1.0, green: 0.88, blue: 0.95).opacity(0.85), .clear],
                center: UnitPoint(x: 0.28, y: 0.20), startRadius: 0, endRadius: 95
            )
            RadialGradient(
                colors: [Color(red: 0.87, green: 0.93, blue: 1.00).opacity(0.95), .clear],
                center: UnitPoint(x: 0.78, y: 0.26), startRadius: 0, endRadius: 85
            )
            RadialGradient(
                colors: [Color(red: 0.86, green: 0.99, blue: 0.95).opacity(0.95), .clear],
                center: UnitPoint(x: 0.72, y: 0.82), startRadius: 0, endRadius: 85
            )
            RadialGradient(
                colors: [Color(red: 0.93, green: 0.87, blue: 1.00).opacity(0.95), .clear],
                center: UnitPoint(x: 0.20, y: 0.78), startRadius: 0, endRadius: 85
            )
            // 左上角那一点油光
            RadialGradient(
                colors: [Color.white.opacity(0.95), .clear],
                center: UnitPoint(x: 0.24, y: 0.16), startRadius: 0, endRadius: 26
            )
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
