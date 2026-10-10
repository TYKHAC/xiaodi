import SwiftUI

enum DSHColor {
    static let navy = Color(red: 0.025, green: 0.09, blue: 0.17)
    static let navyRaised = Color(red: 0.05, green: 0.14, blue: 0.25)
    static let ocean = Color(red: 0.18, green: 0.42, blue: 0.9)
    static let mist = Color(red: 0.75, green: 0.84, blue: 1)
    static let ink = Color(red: 0.055, green: 0.075, blue: 0.1)
    static let paper = Color(red: 0.975, green: 0.98, blue: 0.99)
    static let purple = Color(red: 0.48, green: 0.33, blue: 0.78)
    static let orange = Color(red: 0.94, green: 0.49, blue: 0.08)
    static let amber = Color(red: 1.0, green: 0.68, blue: 0.12)
    static let success = Color(red: 0.18, green: 0.72, blue: 0.36)
}

/// Hestia统一主题「珍珠」v1 —— 用户 2026-10-09：
/// 「东拼西凑很杂，我想要统一主题」。**所有界面从这里取值，别再各写各的。**
///
/// 规范三条：
/// 1. 一个强调色（accent，值＝旧 ocean 不变，避免全 App 迁移）；
///    UIKit 侧同值在 ConversationViewport.updateBubbleColors（0.18,0.42,0.9）。
/// 2. 一个卡片语言：cardFill/cardStroke 自适应明暗（白底黑字、深底白字都成立）。
/// 3. 一个圆角：气泡 15、卡片 16、控件 14。
/// 语义色不受统一约束：success绿 / orange警告 / purple推理徽章 —— 只做状态，不做装饰。
enum ZhuTheme {
    /// 唯一强调色
    static let accent = DSHColor.ocean

    /// 用户气泡填充（淡染，非实色 —— 远端/UIKit 侧同参数）
    static func accentFill(dark: Bool) -> Color { accent.opacity(dark ? 0.24 : 0.11) }

    /// 用户气泡描边
    static func accentStroke(dark: Bool) -> Color { accent.opacity(dark ? 0.34 : 0.08) }

    /// 卡片填充 / 描边（自适应）
    static let cardFill = Color.primary.opacity(0.05)
    static let cardStroke = Color.primary.opacity(0.08)

    /// 统一圆角
    static let radiusBubble: CGFloat = 15
    static let radiusCard: CGFloat = 16
    static let radiusControl: CGFloat = 14
}

/// Hestia首页背景 —— 珍珠光晕（用户要求去掉 DeepSeek 落地页的点阵样式）。
/// 浅色：系统底 + 三团珍珠色柔光；深色：藏蓝底 + 淡彩光晕。
/// 全部纯代码渐变，不依赖素材，也不用 Metal。
struct DeepOceanBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                DSHColor.navy
                pearlBlobs.opacity(0.24)
            } else {
                Color(uiColor: .systemBackground)
                // 浅色：珍珠光斑必须压得很淡 —— 0.6 那版会把黑色标题和灰色副标题
                // 一起糊成看不见（用户 2026-10-10「这个主题字都看不到了」）。
                pearlBlobs.opacity(0.3)
            }
        }
        .ignoresSafeArea()
    }

    private var pearlBlobs: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.99, green: 0.90, blue: 0.95), .clear],
                center: UnitPoint(x: 0.86, y: 0.06),
                startRadius: 0,
                endRadius: 330
            )
            RadialGradient(
                colors: [Color(red: 0.86, green: 0.92, blue: 1.00), .clear],
                center: UnitPoint(x: 0.08, y: 0.28),
                startRadius: 0,
                endRadius: 300
            )
            RadialGradient(
                colors: [Color(red: 0.87, green: 0.98, blue: 0.94), .clear],
                center: UnitPoint(x: 0.78, y: 0.94),
                startRadius: 0,
                endRadius: 340
            )
        }
    }
}
