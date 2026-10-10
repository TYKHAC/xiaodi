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

    var body: some View {
        Button {
            // 播报中 → 打断；空闲 → 进入"准备按住"的提示态
            voice.togglePrimaryButton()
        } label: {
            ZStack {
                // 高级感波纹 = 柔光晕 + 渐变细环（不再是硬边圆环，用户 2026-10-10
                // 说「波纹不高级」）。球体外面先铺一层呼吸柔光，再让两条极细的
                // 渐变环缓慢向外扩散、边缘就淡掉 —— 看起来像光在散开，不是画圈。
                if !reduceMotion {
                    softGlow
                    if isRecording || isTranscribing {
                        halo(scale: 1.02, opacity: 0.55, delay: 0)
                        halo(scale: 1.30, opacity: 0.34, delay: 0.75)
                        halo(scale: 1.58, opacity: 0.18, delay: 1.5)
                    }
                }

                // Hestia：圆球本身就是全部视觉 —— 任何状态下都显示这颗球，
                // 状态差别交给球的动效（加速/变亮/呼吸）+ 波纹 + 文字标签。
                PearlOrbView(isActive: !isIdle, isSpeaking: isSpeaking)
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

    // Hestia：不放图标 —— 圆球本身就是全部视觉（Siri 风格的深色球 + 流动光带，
    // 见 PearlOrbView）；状态区别靠球的动效 + scaleEffect(1.16) + 波纹 + 文字标签。

    /// 球体外的一层呼吸柔光 —— 高级感主要来自它（模糊的光，而不是清晰的圈）
    private var softGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.42, green: 0.64, blue: 1.00).opacity(0.55),
                        Color(red: 0.72, green: 0.45, blue: 1.00).opacity(0.26),
                        Color(red: 1.00, green: 0.45, blue: 0.78).opacity(0.10),
                        .clear,
                    ],
                    center: .center,
                    startRadius: diameter * 0.30,
                    endRadius: diameter * 1.00
                )
            )
            .frame(width: diameter * 2.1, height: diameter * 2.1)
            .blur(radius: 7)
            .opacity(isRecording || isTranscribing ? 0.95 : 0.5)
            .scaleEffect(pulse ? 1.06 : 0.94)
            .animation(
                .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                value: pulse
            )
            .allowsHitTesting(false)
    }

    /// 向外扩散的一条柔光环：细、模糊、带渐变（末端淡出），所以不像"画的圈"
    private func halo(scale: CGFloat, opacity: Double, delay: Double) -> some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        Color(red: 0.45, green: 0.72, blue: 1.00).opacity(0.0),
                        Color(red: 0.55, green: 0.80, blue: 1.00).opacity(0.90),
                        Color(red: 0.78, green: 0.55, blue: 1.00).opacity(0.75),
                        Color(red: 0.45, green: 0.72, blue: 1.00).opacity(0.0),
                    ],
                    center: .center,
                    angle: .degrees(140)
                ),
                lineWidth: 1.1
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: 1.8)
            .scaleEffect(pulse ? scale : 0.98)
            .opacity(pulse ? 0 : opacity)
            .animation(
                .easeOut(duration: 2.6).repeatForever(autoreverses: false).delay(delay),
                value: pulse
            )
            .allowsHitTesting(false)
    }

    private var shadowColor: Color {
        isRecording || isTranscribing
            ? Color(red: 0.35, green: 0.55, blue: 0.98).opacity(0.55)
            : .clear
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

// MARK: - Hestia 语音球（Siri 风格：深色球体 + 流动彩色光带）

/// 照系统 Siri 的新球体做：深色底，内部几团高饱和光带缓慢缠绕流动，中心有亮核。
/// 全部用 SwiftUI `Canvas` + 渐变画出来，**不依赖任何图片资源**。
/// 动画由 `TimelineView(.animation)` 按时间驱动（不是 withAnimation 循环），
/// 所以能一直平滑流动，且开了「减少动态效果」时自动停。
/// 状态：空闲 = 慢速暗淡；按住说话 = 加速变亮；播报 = 呼吸脉冲。
struct PearlOrbView: View {
    /// 语音激活（聆听/识别）—— 加速变亮
    var isActive: Bool = false
    /// 播报中 —— 呼吸脉冲
    var isSpeaking: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            Canvas { ctx, size in
                draw(in: &ctx, size: size, t: context.date.timeIntervalSinceReferenceDate)
            }
        }
        .clipShape(Circle())
        .overlay(
            // 左上角玻璃高光
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.42), .clear],
                        center: UnitPoint(x: 0.30, y: 0.22),
                        startRadius: 0,
                        endRadius: 42
                    )
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        )
        .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
    }

    /// 状态相关的速度 / 亮度
    private var speed: Double { isActive ? 1.9 : 0.62 }
    private var glow: Double { isActive ? 1.0 : 0.72 }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = min(size.width, size.height) / 2

        // 1) 深色球体底
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.20, green: 0.22, blue: 0.38),
                    Color(red: 0.04, green: 0.05, blue: 0.12),
                ]),
                center: CGPoint(x: c.x - r * 0.25, y: c.y - r * 0.30),
                startRadius: r * 0.05,
                endRadius: r * 1.25
            )
        )

        // 2) 流动光带（模糊 + 叠加，四团不同色相各自转）
        ctx.addFilter(.blur(radius: r * 0.30))
        ctx.blendMode = .plusLighter
        let blobs: [(Color, CGFloat, Double, Double)] = [
            (Color(red: 0.25, green: 0.55, blue: 1.00), 0.50, 0.42, 0.95),   // 蓝
            (Color(red: 1.00, green: 0.35, blue: 0.75), 0.42, -0.31, 0.80),  // 粉
            (Color(red: 0.45, green: 0.95, blue: 0.90), 0.36, 0.63, 0.62),   // 青
            (Color(red: 0.65, green: 0.40, blue: 1.00), 0.32, -0.78, 0.58),  // 紫
        ]
        for (color, distance, spin, alpha) in blobs {
            let a = t * speed * spin
            let px = c.x + CGFloat(cos(a)) * r * distance
            let py = c.y + CGFloat(sin(a * 0.8)) * r * distance * 0.78
            let br = r * 0.55
            ctx.fill(
                Path(ellipseIn: CGRect(x: px - br, y: py - br, width: br * 2, height: br * 2)),
                with: .color(color.opacity(alpha * glow))
            )
        }

        // 3) 中心亮核（轻轻呼吸）
        let coreR = r * (isSpeaking ? 0.30 + 0.05 * sin(t * 4.2) : 0.28 + 0.02 * sin(t * 1.6))
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - coreR, y: c.y - coreR, width: coreR * 2, height: coreR * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.95 * glow),
                    Color(red: 0.70, green: 0.85, blue: 1.00).opacity(0.28 * glow),
                    .clear,
                ]),
                center: c,
                startRadius: 0,
                endRadius: coreR * 2.4
            )
        )
        ctx.blendMode = .normal
        ctx.addFilter(.blur(radius: 0))
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
