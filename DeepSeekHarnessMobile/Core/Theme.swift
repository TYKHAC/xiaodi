import SwiftUI

enum DSHColor {
    /// 深色模式底：中性近黑（用户 2026-10-10 敲定「黑白冷酷」，不用藏蓝）
    static let navy = Color(red: 0.04, green: 0.04, blue: 0.045)
    static let navyRaised = Color(red: 0.09, green: 0.09, blue: 0.10)
    /// 强调色 = 黑白（浅色近黑 / 深色纯白）。用户：「主题要求黑白冷酷圆润」+「主题跟图标差不多风格」。
    /// 全 App 不再出现蓝/粉/青/紫的强调色；语义色（成功/警告）仍保留做状态。
    static let ocean = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 1.0)
            : UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1.0)
    })
    /// 冷灰（次要文字/描边）
    static let mist = Color(red: 0.60, green: 0.62, blue: 0.66)
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let paper = Color(red: 0.975, green: 0.98, blue: 0.985)
    static let purple = Color(red: 0.48, green: 0.33, blue: 0.78)
    static let orange = Color(red: 0.94, green: 0.49, blue: 0.08)
    static let amber = Color(red: 1.0, green: 0.68, blue: 0.12)
    static let success = Color(red: 0.18, green: 0.72, blue: 0.36)
}

/// App 名字（Hestia）可选字体 —— 用户 2026-10-11：
/// 「你给出的选择字体设为自定义字体选择里」= 把设计稿里那 16 个候选做成设置项，用户自己挑。
/// iOS 上就用系统自带字体（不打包字体文件）；名字对不上会退回系统字体，绝不崩。
enum HestiaNameFont: String, CaseIterable, Identifiable {
    case didot, georgia, sfHeavy, futura, mincho, kaku, mono, impact          // ①～⑧
    case rounded, thinSpaced, baskerville, baskervilleItalic, snell, courier, kaiti, compressed  // ⑨～⑯

    var id: String { rawValue }

    var title: String {
        switch self {
        case .didot: return "① Didone 罗马体"
        case .georgia: return "② 古典衬线"
        case .sfHeavy: return "③ 无衬线特粗"
        case .futura: return "④ 几何无衬线·宽字距"
        case .mincho: return "⑤ 日式明朝体"
        case .kaku: return "⑥ 日式粗黑·宽字距"
        case .mono: return "⑦ 等宽"
        case .impact: return "⑧ 超粗压缩体"
        case .rounded: return "⑨ 圆体"
        case .thinSpaced: return "⑩ 超细无衬线·大字距"
        case .baskerville: return "⑪ 经典衬线粗体"
        case .baskervilleItalic: return "⑫ 衬线斜体（当前）"
        case .snell: return "⑬ 手写体"
        case .courier: return "⑭ 等宽衬线"
        case .kaiti: return "⑮ 楷体"
        case .compressed: return "⑯ 压缩粗体"
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .didot: return .custom("Didot-Bold", size: size)
        case .georgia: return .custom("Georgia-Bold", size: size)
        case .sfHeavy: return .system(size: size, weight: .heavy)
        case .futura: return .custom("Futura-Medium", size: size)
        case .mincho: return .custom("HiraMinProN-W6", size: size)
        case .kaku: return .custom("HiraKakuProN-W6", size: size)
        case .mono: return .system(size: size, design: .monospaced).weight(.semibold)
        case .impact, .compressed: return .custom("Impact", size: size)
        case .rounded: return .system(size: size, weight: .heavy, design: .rounded)
        case .thinSpaced: return .system(size: size, weight: .thin)
        case .baskerville: return .custom("Baskerville-Bold", size: size)
        case .baskervilleItalic: return .custom("Baskerville-Italic", size: size)
        case .snell: return .custom("SnellRoundhand-Bold", size: size)
        case .courier: return .custom("CourierNewPS-BoldMT", size: size)
        case .kaiti: return .custom("Kaiti SC", size: size)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .futura, .thinSpaced: return 4
        case .kaku: return 3
        default: return 0
        }
    }
}

/// Hestia统一主题「黑白冷酷圆润」v2 —— 用户 2026-10-10 敲定：
/// 「主题要求黑白冷酷圆润」+「主题跟图标差不多风格」（图标=黑白线稿）。
/// **所有界面从这里取值，别再各写各的。**
///
/// 规范四条：
/// 1. 只用 黑/白/灰：强调色 = 近黑(浅色) / 纯白(深色)，不再有彩色强调色。
/// 2. 一个卡片语言：cardFill/cardStroke 自适应明暗（白底黑字、深底白字都成立）。
/// 3. 圆润：气泡 15、卡片 16-18、控件 14、胶囊全圆。
/// 4. 语义色不受统一约束：success绿 / orange警告 —— 只做状态，不做装饰。
enum ZhuTheme {
    /// 唯一强调色 = 黑白（见 DSHColor.ocean）
    static let accent = DSHColor.ocean

    /// 用户气泡填充（黑白淡染 —— 远端/UIKit 侧同参数）
    static func accentFill(dark: Bool) -> Color { accent.opacity(dark ? 0.16 : 0.08) }

    /// 用户气泡描边
    static func accentStroke(dark: Bool) -> Color { accent.opacity(dark ? 0.20 : 0.10) }

    /// 卡片填充 / 描边（自适应）
    static let cardFill = Color.primary.opacity(0.05)
    static let cardStroke = Color.primary.opacity(0.08)

    /// 全 App 唯一的一记「烈焰赤红」（用户 2026-10-11 定的黑白日漫规范：
    /// 色彩只出现一次，用在最关键处 —— 目前是「准备就绪」那个点 + 手势高亮）。
    static let dangerRed = Color(red: 0.847, green: 0.137, blue: 0.165)

    /// 统一圆角（黑白冷酷圆润：更圆）
    static let radiusBubble: CGFloat = 15
    static let radiusCard: CGFloat = 18
    static let radiusControl: CGFloat = 14
    /// 设置页图标块（豆包式行样式）
    static let radiusTile: CGFloat = 10
}

/// Hestia 首页背景 —— 黑白冷酷（用户 2026-10-10 敲定主题「黑白冷酷圆润」）。
/// 浅色：白底 + 极淡冷灰柔光；深色：纯黑 + 极淡白光晕。
/// 全部纯代码渐变，不依赖素材，也不用 Metal。
struct DeepOceanBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                Color(white: 0.02)
                pearlBlobs.opacity(0.16)
            } else {
                Color(uiColor: .systemBackground)
                // 浅色：柔光压得很淡 —— 太浓会把黑标题和灰副标题一起糊掉
                // （用户 2026-10-10「这个主题字都看不到了」）。
                pearlBlobs.opacity(0.22)
            }
        }
        .ignoresSafeArea()
    }

    /// 冷灰柔光（无色相，匹配「主题跟图标差不多风格」= 黑白线稿）
    private var pearlBlobs: some View {
        ZStack {
            RadialGradient(
                colors: [Color(white: 0.55), .clear],
                center: UnitPoint(x: 0.86, y: 0.06),
                startRadius: 0,
                endRadius: 330
            )
            RadialGradient(
                colors: [Color(white: 0.72), .clear],
                center: UnitPoint(x: 0.08, y: 0.28),
                startRadius: 0,
                endRadius: 300
            )
            RadialGradient(
                colors: [Color(white: 0.62), .clear],
                center: UnitPoint(x: 0.78, y: 0.94),
                startRadius: 0,
                endRadius: 340
            )
        }
    }
}
