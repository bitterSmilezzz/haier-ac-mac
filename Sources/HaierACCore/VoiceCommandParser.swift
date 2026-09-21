import Foundation

/// 语音指令类型
public enum VoiceCommand: Equatable {
    /// 开关机
    case setPower(Bool)
    /// 设定具体温度（°C）
    case setTemperature(Double)
    /// 相对调节温度（例如 +1.0 或 -1.0）
    case adjustTemperature(delta: Double)
    /// 设定运行模式（如“制冷”、“制热”、“送风”、“除湿”、“自动”）
    case setMode(String)
    /// 设定风速（如“高风”、“微风”、“自动”）
    case setWindSpeed(String)
    /// 查询状态与室内温度
    case queryStatus
    /// 应用情景模式
    case applyScene(String)
}

/// 语音指令解析结果
public struct VoiceParseResult: Equatable {
    public let command: VoiceCommand
    public let displayText: String

    public init(command: VoiceCommand, displayText: String) {
        self.command = command
        self.displayText = displayText
    }
}

/// 自然语言语音指令解析器
public struct VoiceCommandParser {

    /// 解析用户输入的自然语言文本
    public static func parse(_ text: String) -> VoiceParseResult? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "。", with: "")
            .replacingOccurrences(of: "！", with: "")
            .replacingOccurrences(of: "？", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard !cleaned.isEmpty else { return nil }

        // 1. 查询类
        if cleaned.contains("多少度") || cleaned.contains("当前温度") || cleaned.contains("室内温度") ||
           cleaned.contains("现在温度") || cleaned.contains("查温度") || cleaned.contains("室温") {
            return VoiceParseResult(command: .queryStatus, displayText: "查询室内温度")
        }

        // 2. 关机 / 开机（注意：关机判定放在开机前，避免“关闭空调”因含有“开”而被误判）
        if isPowerOff(cleaned) {
            return VoiceParseResult(command: .setPower(false), displayText: "关闭空调电源")
        }
        if isPowerOn(cleaned) {
            return VoiceParseResult(command: .setPower(true), displayText: "打开空调电源")
        }

        // 3. 相对温度微调（太冷了/太热了/高一度/低一度）
        if let relative = parseRelativeTemperature(cleaned) {
            return relative
        }

        // 4. 绝对温度设定（调到26度 / 26度 / 二十六度）
        if let absolute = parseAbsoluteTemperature(cleaned) {
            return absolute
        }

        // 5. 风速调节（放在模式切换之前，避免“自动风”被“自动”误判拦截）
        if let wind = parseWindSpeed(cleaned) {
            return wind
        }

        // 6. 运行模式切换
        if let mode = parseMode(cleaned) {
            return mode
        }

        // 7. 情景模式
        if let scene = parseScene(cleaned) {
            return scene
        }

        return nil
    }

    // MARK: - 辅助解析子函数

    private static func isPowerOff(_ text: String) -> Bool {
        let offKeywords = ["关空调", "关闭空调", "关掉空调", "关机", "别吹了", "停机", "关闭", "关掉"]
        return offKeywords.contains(where: { text.contains($0) })
    }

    private static func isPowerOn(_ text: String) -> Bool {
        let onKeywords = ["开空调", "打开空调", "开一下空调", "开机", "启动空调", "开启空调", "开开空调"]
        if onKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        if text == "打开" || text == "开启" || text == "开" {
            return true
        }
        return false
    }

    private static func parseRelativeTemperature(_ text: String) -> VoiceParseResult? {
        // 太热了 / 好热 -> 降温 1 度
        if text.contains("太热") || text.contains("好热") || text.contains("有点热") || text.contains("热死") {
            return VoiceParseResult(command: .adjustTemperature(delta: -1.0), displayText: "降温 1°C")
        }
        // 太冷了 / 好冷 -> 升温 1 度
        if text.contains("太冷") || text.contains("好冷") || text.contains("有点冷") || text.contains("冷死") {
            return VoiceParseResult(command: .adjustTemperature(delta: 1.0), displayText: "升温 1°C")
        }

        // 升温 / 调高 / 加
        if text.contains("高") || text.contains("升") || text.contains("加") || text.contains("热一点") {
            let delta = extractNumber(from: text) ?? 1.0
            let validDelta = (delta > 0 && delta <= 5) ? delta : 1.0
            return VoiceParseResult(
                command: .adjustTemperature(delta: validDelta),
                displayText: "升温 \(formatTemp(validDelta))°C"
            )
        }

        // 降温 / 调低 / 减 / 凉一点
        if text.contains("低") || text.contains("降") || text.contains("减") || text.contains("冷一点") || text.contains("凉一点") {
            let delta = extractNumber(from: text) ?? 1.0
            let validDelta = (delta > 0 && delta <= 5) ? delta : 1.0
            return VoiceParseResult(
                command: .adjustTemperature(delta: -validDelta),
                displayText: "降温 \(formatTemp(validDelta))°C"
            )
        }

        return nil
    }

    private static func parseAbsoluteTemperature(_ text: String) -> VoiceParseResult? {
        guard let temp = extractTemperatureValue(from: text) else { return nil }

        // 空调常见合理温度区间：16°C ~ 30°C
        if temp >= 16.0 && temp <= 30.0 {
            return VoiceParseResult(
                command: .setTemperature(temp),
                displayText: "设置温度为 \(formatTemp(temp))°C"
            )
        }
        return nil
    }

    private static func parseMode(_ text: String) -> VoiceParseResult? {
        if text.contains("制冷") || text.contains("冷气") || text.contains("冷风") || text.contains("开冷") {
            return VoiceParseResult(command: .setMode("制冷"), displayText: "切换至制冷模式")
        }
        if text.contains("制热") || text.contains("暖气") || text.contains("暖风") || text.contains("开暖") || text.contains("加热") {
            return VoiceParseResult(command: .setMode("制热"), displayText: "切换至制热模式")
        }
        if text.contains("送风") || text.contains("吹风") || text.contains("通风") || text.contains("自然风") {
            return VoiceParseResult(command: .setMode("送风"), displayText: "切换至送风模式")
        }
        if text.contains("除湿") || text.contains("抽湿") || text.contains("干燥") {
            return VoiceParseResult(command: .setMode("除湿"), displayText: "切换至除湿模式")
        }
        if (text.contains("自动") || text.contains("智能")) && !text.contains("自动风") && !text.contains("风速") {
            return VoiceParseResult(command: .setMode("自动"), displayText: "切换至智能自动模式")
        }
        return nil
    }

    private static func parseWindSpeed(_ text: String) -> VoiceParseResult? {
        if text.contains("自动风") || text.contains("风速自动") || text.contains("自动风速") {
            return VoiceParseResult(command: .setWindSpeed("自动"), displayText: "切换至自动风速")
        }
        if text.contains("大风") || text.contains("风大") || text.contains("强劲") || text.contains("高风") || text.contains("最大风") || text.contains("调大风") || text.contains("风速大") {
            return VoiceParseResult(command: .setWindSpeed("强劲"), displayText: "切换至强劲风速")
        }
        if text.contains("小风") || text.contains("风小") || text.contains("微风") || text.contains("低风") || text.contains("静音") || text.contains("柔风") || text.contains("调小风") || text.contains("风速小") {
            return VoiceParseResult(command: .setWindSpeed("微风"), displayText: "切换至微风模式")
        }
        if text.contains("中风") || text.contains("适中") || text.contains("风速中") {
            return VoiceParseResult(command: .setWindSpeed("中风"), displayText: "切换至中档风速")
        }
        return nil
    }

    private static func parseScene(_ text: String) -> VoiceParseResult? {
        if text.contains("睡眠") || text.contains("睡觉") || text.contains("伴眠") {
            return VoiceParseResult(command: .applyScene("睡眠"), displayText: "应用「睡眠」情景")
        }
        if text.contains("离家") || text.contains("出门") {
            return VoiceParseResult(command: .applyScene("离家"), displayText: "应用「离家」情景")
        }
        if text.contains("回家") || text.contains("到家") {
            return VoiceParseResult(command: .applyScene("回家"), displayText: "应用「回家」情景")
        }
        return nil
    }

    // MARK: - 数字与汉字解析工具

    private static func extractTemperatureValue(from text: String) -> Double? {
        let normalized = convertChineseNumbers(in: text)

        let pattern = #"([1-3]\d(?:\.[05])?)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = normalized as NSString
            let matches = regex.matches(in: normalized, range: NSRange(location: 0, length: nsString.length))
            if let first = matches.first {
                let matchStr = nsString.substring(with: first.range)
                return Double(matchStr)
            }
        }
        return nil
    }

    private static func extractNumber(from text: String) -> Double? {
        let normalized = convertChineseNumbers(in: text)
        let pattern = #"(\d+(?:\.\d+)?)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = normalized as NSString
            let matches = regex.matches(in: normalized, range: NSRange(location: 0, length: nsString.length))
            if let first = matches.first {
                let matchStr = nsString.substring(with: first.range)
                return Double(matchStr)
            }
        }
        return nil
    }

    /// 将常见的中文数字表达替换为阿拉伯数字
    private static func convertChineseNumbers(in input: String) -> String {
        var str = input
        str = str.replacingOccurrences(of: "两", with: "2")
        str = str.replacingOccurrences(of: "半", with: "0.5")

        let mapping: [(String, String)] = [
            ("三十", "30"),
            ("二十九", "29"),
            ("二十八", "28"),
            ("二十七", "27"),
            ("二十六", "26"),
            ("二十五", "25"),
            ("二十四", "24"),
            ("二十三", "23"),
            ("二十二", "22"),
            ("二十一", "21"),
            ("二十", "20"),
            ("十九", "19"),
            ("十八", "18"),
            ("十七", "17"),
            ("十六", "16"),
            ("十五", "15"),
            ("一", "1"),
            ("二", "2"),
            ("三", "3"),
            ("四", "4"),
            ("五", "5"),
            ("六", "6"),
            ("七", "7"),
            ("八", "8"),
            ("九", "9"),
            ("零", "0"),
            ("点五", ".5"),
            ("点", ".")
        ]

        for (cn, ar) in mapping {
            str = str.replacingOccurrences(of: cn, with: ar)
        }
        return str
    }

    private static func formatTemp(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1.0) == 0 {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }
}
