import SwiftUI
import AppKit

/// 主题模式：跟随系统 / 浅色 / 深色
enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 设计令牌 —— 基于 OpenViking 记忆中的 Linear 设计系统
/// 画布 + 四阶表面阶梯 + 薰衣草紫唯一强调色 + hairline 边框 + 紧凑圆角
/// 所有颜色均为动态色（浅色/深色双套，跟随外观自动切换）
enum Theme {
    // MARK: - 色彩（Linear 深色体系 / inverse 浅色体系）

    /// 画布底色
    static let canvas = Color.dynamic(light: 0xFFFFFF, dark: 0x010102)
    /// 表面阶梯 1：卡片、面板
    static let surface1 = Color.dynamic(light: 0xF5F6F6, dark: 0x0F1011)
    /// 表面阶梯 2：强调卡片、悬停
    static let surface2 = Color.dynamic(light: 0xECEEEF, dark: 0x141516)
    /// 表面阶梯 3：次级面板
    static let surface3 = Color.dynamic(light: 0xE2E4E5, dark: 0x18191A)
    /// hairline 边框（1px）
    static let hairline = Color.dynamic(light: 0xE4E5E7, dark: 0x23252A)
    /// hairline 强（输入聚焦）
    static let hairlineStrong = Color.dynamic(light: 0xC9CCD1, dark: 0x34343A)

    /// 主文字
    static let ink = Color.dynamic(light: 0x1D1D1F, dark: 0xF7F8F8)
    /// 次级文字
    static let inkMuted = Color.dynamic(light: 0x44474D, dark: 0xD0D6E0)
    /// 三级文字
    static let inkSubtle = Color.dynamic(light: 0x6E7379, dark: 0x8A8F98)
    /// 四级文字（禁用）
    static let inkTertiary = Color.dynamic(light: 0x9CA0A6, dark: 0x62666D)

    /// 品牌强调色：薰衣草紫（唯一色相）
    static let accent = Color.dynamic(light: 0x5E6AD2, dark: 0x5E6AD2)
    /// 强调悬停（深色下偏亮，浅色下偏深）
    static let accentHover = Color.dynamic(light: 0x4C58C8, dark: 0x828FFF)
    /// 语义：成功（在线）
    static let success = Color.dynamic(light: 0x1E8E3E, dark: 0x27A644)
    /// 语义：警告
    static let warning = Color.dynamic(light: 0xA67C00, dark: 0xC9A227)
    /// 语义：错误
    static let danger = Color.dynamic(light: 0xC93A3A, dark: 0xD64545)

    // MARK: - 圆角（4px 基准）

    static let radiusXS: CGFloat = 4
    static let radiusSM: CGFloat = 6
    static let radiusMD: CGFloat = 8
    static let radiusLG: CGFloat = 12
    static let radiusXL: CGFloat = 16

    // MARK: - 间距（4px 基准）

    static let spaceXS: CGFloat = 8
    static let spaceSM: CGFloat = 12
    static let spaceMD: CGFloat = 16
    static let spaceLG: CGFloat = 24
    static let spaceXL: CGFloat = 32

    // MARK: - 组件样式

    /// 主按钮：薰衣草紫
    static func primaryButtonStyle() -> some ButtonStyle {
        FlatButtonStyle(background: accent, foreground: .white, radius: radiusMD)
    }

    /// 次按钮：表面 1 + hairline
    static func secondaryButtonStyle() -> some ButtonStyle {
        FlatButtonStyle(background: surface1, foreground: ink, radius: radiusMD, border: hairline)
    }

    /// 卡片背景
    static func cardBackground(_ level: Color = surface1) -> some View {
        RoundedRectangle(cornerRadius: radiusLG, style: .continuous)
            .fill(level)
            .overlay(
                RoundedRectangle(cornerRadius: radiusLG, style: .continuous)
                    .strokeBorder(hairline, lineWidth: 1)
            )
    }
}

/// 扁平无阴影按钮（Linear 风格：无投影，层级靠表面 + 边框）
struct FlatButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color
    let radius: CGFloat
    var border: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(border ?? .clear, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// 主题切换菜单（跟随系统 / 浅色 / 深色）
struct ThemePickerMenu: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Menu {
            ForEach(ThemeMode.allCases) { mode in
                Button {
                    model.themeMode = mode
                } label: {
                    Label(mode.label, systemImage: mode.icon)
                        .foregroundStyle(mode == model.themeMode ? Theme.accent : Theme.ink)
                }
            }
        } label: {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkMuted)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 22)
    }
}

// MARK: - Color 扩展

extension Color {
    /// 十六进制颜色
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// 动态颜色：根据当前外观（浅色/深色）自动切换
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(srgbRed: CGFloat((isDark ? dark : light) >> 16 & 0xFF) / 255,
                           green: CGFloat((isDark ? dark : light) >> 8 & 0xFF) / 255,
                           blue: CGFloat((isDark ? dark : light) & 0xFF) / 255,
                           alpha: 1)
        })
    }
}
