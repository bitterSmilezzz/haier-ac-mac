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

/// 空调运行模式分类（语义化感知）
enum ACModeCategory: String, CaseIterable {
    case cooling       // 制冷（冰蓝）
    case heating       // 制热（暖橙）
    case dehumidifying // 除湿（水碧）
    case fan           // 送风（薄荷绿）
    case auto          // 自动（薰衣草紫）
    case off           // 关机 / 离线（中性冷灰）

    var label: String {
        switch self {
        case .cooling: return "制冷"
        case .heating: return "制热"
        case .dehumidifying: return "除湿"
        case .fan: return "送风"
        case .auto: return "自动"
        case .off: return "关机"
        }
    }

    var icon: String {
        switch self {
        case .cooling: return "snowflake"
        case .heating: return "flame.fill"
        case .dehumidifying: return "drop.fill"
        case .fan: return "fan.fill"
        case .auto: return "sparkles"
        case .off: return "power"
        }
    }
}

/// 设计令牌 —— 融合 macOS 原生毛玻璃材质与 Linear 设计体系
/// 材质 + 四阶表面阶梯 + 语义化动态感知色 + Hairline 细边框 + 微投影
enum Theme {
    // MARK: - 基础色彩（Linear 深色体系 / inverse 浅色体系）

    /// 画布底色
    static let canvas = Color.dynamic(light: 0xFBFBFC, dark: 0x010102)
    /// 表面阶梯 1：卡片、面板
    static let surface1 = Color.dynamic(light: 0xF5F6F6, dark: 0x0F1011)
    /// 表面阶梯 2：强调卡片、悬停
    static let surface2 = Color.dynamic(light: 0xECEEEF, dark: 0x141516)
    /// 表面阶梯 3：次级面板
    static let surface3 = Color.dynamic(light: 0xE2E4E5, dark: 0x18191A)

    /// hairline 边框（1px 经典）
    static let hairline = Color.dynamic(light: 0xE4E5E7, dark: 0x23252A)
    /// hairline 强（输入聚焦、激活边缘）
    static let hairlineStrong = Color.dynamic(light: 0xC9CCD1, dark: 0x34343A)
    /// hairline 微弱（用于半透明或次级分隔）
    static let hairlineSubtle = Color.dynamic(light: 0xF0F1F3, dark: 0x1A1B1F)

    /// 主文字
    static let ink = Color.dynamic(light: 0x1D1D1F, dark: 0xF7F8F8)
    /// 次级文字
    static let inkMuted = Color.dynamic(light: 0x44474D, dark: 0xD0D6E0)
    /// 三级文字
    static let inkSubtle = Color.dynamic(light: 0x6E7379, dark: 0x8A8F98)
    /// 四级文字（禁用）
    static let inkTertiary = Color.dynamic(light: 0x9CA0A6, dark: 0x62666D)

    /// 品牌基准强调色：薰衣草紫
    static let accent = Color.dynamic(light: 0x5E6AD2, dark: 0x5E6AD2)
    /// 强调悬停（深色下偏亮，浅色下偏深）
    static let accentHover = Color.dynamic(light: 0x4C58C8, dark: 0x828FFF)
    /// 语义：成功（在线）
    static let success = Color.dynamic(light: 0x1E8E3E, dark: 0x27A644)
    /// 语义：警告
    static let warning = Color.dynamic(light: 0xA67C00, dark: 0xC9A227)
    /// 语义：错误
    static let danger = Color.dynamic(light: 0xC93A3A, dark: 0xD64545)

    // MARK: - 语义感知模式色彩（Mode Tint）

    /// 解析空调运行模式分类
    static func modeCategory(modeDesc: String?, isOn: Bool = true) -> ACModeCategory {
        guard isOn else { return .off }
        guard let desc = modeDesc?.lowercased(), !desc.isEmpty else { return .auto }
        if desc.contains("冷") || desc.contains("cool") { return .cooling }
        if desc.contains("热") || desc.contains("heat") { return .heating }
        if desc.contains("湿") || desc.contains("dry") || desc.contains("dehum") { return .dehumidifying }
        if desc.contains("风") || desc.contains("fan") { return .fan }
        return .auto
    }

    /// 模式主色调
    static func modeTint(for category: ACModeCategory) -> Color {
        switch category {
        case .cooling:
            // 冰蓝
            return Color.dynamic(light: 0x0071E3, dark: 0x2997FF)
        case .heating:
            // 暖橙
            return Color.dynamic(light: 0xF05A28, dark: 0xFF6934)
        case .dehumidifying:
            // 水青
            return Color.dynamic(light: 0x009688, dark: 0x20C997)
        case .fan:
            // 薄荷绿
            return Color.dynamic(light: 0x28A745, dark: 0x30D158)
        case .auto:
            // 经典薰衣草紫
            return accent
        case .off:
            // 优雅薰衣草灰紫（离线/关机，符合规范）
            return Color.dynamic(light: 0x5E6AD2, dark: 0x7E8BEE)
        }
    }

    /// 模式微光背景色（带极低不透明度，用于卡片底衬光晕）
    static func modeTintGlow(for category: ACModeCategory) -> Color {
        modeTint(for: category).opacity(0.12)
    }

    /// 快捷方法：根据描述字符串直接获取主色调
    static func modeTint(modeDesc: String?, isOn: Bool = true) -> Color {
        modeTint(for: modeCategory(modeDesc: modeDesc, isOn: isOn))
    }

    /// 温度阶梯色彩（根据目标/室内摄氏度返回感知色）
    static func temperatureColor(celsius: Double) -> Color {
        if celsius <= 20 {
            return Color.dynamic(light: 0x0071E3, dark: 0x2997FF) // 冰蓝
        } else if celsius <= 24 {
            return Color.dynamic(light: 0x00A86B, dark: 0x30D158) // 舒适绿
        } else if celsius <= 27 {
            return Color.dynamic(light: 0xF59E0B, dark: 0xFBBF24) // 温润金
        } else {
            return Color.dynamic(light: 0xF05A28, dark: 0xFF6934) // 暖橙
        }
    }

    /// 步进数值规范化取整（消除重复逻辑）
    static func roundStep(value: Double, step: Double) -> Double {
        (value / step).rounded() * step
    }

    // MARK: - 动效与弹性曲线

    /// 规范标准弹簧响应（按键微触感、数值切换）
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.75)
    /// 快速弹簧响应（极小微动）
    static let springFast = Animation.spring(response: 0.28, dampingFraction: 0.76)
    /// 平滑柔和弹簧（卡片展开、抽屉折叠）
    static let springSmooth = Animation.spring(response: 0.38, dampingFraction: 0.82)

    // MARK: - 圆角（遵循规范：8pt 内部胶囊, 14pt Bento Pods, 18pt 外层卡片）

    static let radiusXS: CGFloat = 4
    static let radiusSM: CGFloat = 8   // 内部胶囊 (Spec)
    static let radiusMD: CGFloat = 14  // Bento Pods (Spec)
    static let radiusLG: CGFloat = 18  // 外层卡片容器 (Spec)
    static let radiusXL: CGFloat = 22
    static let radiusPill: CGFloat = 999

    // MARK: - 间距（4px 基准体系）

    static let spaceXXS: CGFloat = 4
    static let spaceXS: CGFloat = 8
    static let spaceSM: CGFloat = 12
    static let spaceMD: CGFloat = 16
    static let spaceLG: CGFloat = 24
    static let spaceXL: CGFloat = 32

    // MARK: - 材质与卡片组件样式

    /// 原生毛玻璃卡片背景（支持边框与毛玻璃材质）
    static func materialCardBackground(
        material: Material = .regularMaterial,
        radius: CGFloat = radiusLG,
        strokeColor: Color = hairline
    ) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(material)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
    }

    /// 经典纯色卡片背景
    static func cardBackground(_ level: Color = surface1, radius: CGFloat = radiusLG) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(level)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(hairline, lineWidth: 1)
            )
    }

    /// 触控 Bento Pod 胶囊卡片背景（带微高光和自适应阴影）
    static func bentoCardBackground(
        radius: CGFloat = radiusLG,
        tint: Color? = nil
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
            if let tint = tint {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.opacity(0.06))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(tint?.opacity(0.25) ?? hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    /// 主按钮样式
    static func primaryButtonStyle(tint: Color = accent) -> some ButtonStyle {
        FlatButtonStyle(background: tint, foreground: .white, radius: radiusMD)
    }

    /// 次按钮样式
    static func secondaryButtonStyle() -> some ButtonStyle {
        FlatButtonStyle(background: surface1, foreground: ink, radius: radiusMD, border: hairline)
    }
}

/// 扁平微触感按钮（支持弹簧反馈和按压微缩放）
struct FlatButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color
    let radius: CGFloat
    var border: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(border ?? .clear, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(Theme.springFast, value: configuration.isPressed)
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

// MARK: - SwiftUI Preview

#if DEBUG
struct Theme_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            Text("Theme Mode Tints & Bento Pods")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            HStack(spacing: 12) {
                ForEach(ACModeCategory.allCases, id: \.self) { cat in
                    VStack(spacing: 6) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.modeTint(for: cat))
                        Text(cat.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .padding(.vertical, 10)
                    .frame(width: 60)
                    .background(Theme.bentoCardBackground(radius: Theme.radiusMD, tint: Theme.modeTint(for: cat)))
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vibrant Material Card")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Ultra-thin material with subtle hairline border")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .padding()
                .background(Theme.materialCardBackground())
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Theme.canvas)
    }
}
#endif
