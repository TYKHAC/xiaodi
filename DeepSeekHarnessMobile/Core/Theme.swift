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

/// 朱小姐首页背景 —— 珍珠光晕（用户要求去掉 DeepSeek 落地页的点阵样式）。
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
                pearlBlobs.opacity(0.6)
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
