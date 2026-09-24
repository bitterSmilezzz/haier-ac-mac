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
    /// 倒计时开关机（minutes: 倒计时分钟数，power: true=开机, false=关机）
    case countdownPower(minutes: Int, power: Bool)
    /// 指定钟点开关机（hour: 0~23, minute: 0~59, power: true=开机, false=关机）
    case schedulePower(hour: Int, minute: Int, power: Bool)
    /// 取消定向/当前设备定时与倒计时
    case cancelSchedules
    /// 取消全屋所有设备的定时与倒计时任务 (v1.9.36)
    case cancelSchedulesAll
    /// 启动智能睡眠温阶（curveName: 可选曲线名称）
    case startSleepCurve(curveName: String?)
    /// 停止智能睡眠温阶
    case stopSleepCurve
    /// 查询智能睡眠状态或昨晚睡眠报告（v1.9.18）
    case querySleepReport
    /// 关闭全屋所有空调 (v1.9.30)
    case turnOffAll
    /// 开启全屋所有空调 (v1.9.30)
    case turnOnAll
    /// 全屋/所有设备批量模式与温度预设 (mode: 模式名称如"制冷"/"制热", temperature: 可选温度) (v1.9.33)
    case presetAll(mode: String, temperature: Double?)
    /// 全屋/所有设备统一设置目标温度 (v1.9.33)
    case setTemperatureAll(Double)
    /// 全屋/所有设备统一相对调温 (v1.9.35)
    case adjustTemperatureAll(delta: Double)
    /// 启动 56°C 蒸发器高温自清洁 (v1.9.30)
    case startSelfCleaning
    /// 停止蒸发器自清洁 (v1.9.30)
    case stopSelfCleaning
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

        // 2. 定时与倒计时取消 (v1.9.36 闭环 CR P1-2: 区分全屋取消与定向设备取消)
        if isCancelSchedule(cleaned) {
            if isAllDeviceScope(cleaned) {
                return VoiceParseResult(command: .cancelSchedulesAll, displayText: "取消全屋所有定时与倒计时")
            } else {
                return VoiceParseResult(command: .cancelSchedules, displayText: "取消定时与倒计时")
            }
        }

        // 3. 睡眠状态与报告查询（v1.9.18，优先于通用睡眠开关）
        if (cleaned.contains("昨晚") && cleaned.contains("睡")) ||
           cleaned.contains("睡眠报告") ||
           cleaned.contains("睡眠情况") ||
           cleaned.contains("睡眠状态") ||
           (cleaned.contains("睡眠") && (cleaned.contains("还剩") || cleaned.contains("多久") || cleaned.contains("查") || cleaned.contains("进度"))) {
            return VoiceParseResult(command: .querySleepReport, displayText: "查询睡眠调温状态与报告")
        }

        // 4. 智能睡眠温阶启停（放在立即开关机与情景模式前）
        if cleaned.contains("智能睡眠") || cleaned.contains("睡眠曲线") || cleaned.contains("睡眠温阶") ||
           (cleaned.contains("睡眠") && (cleaned.contains("开启") || cleaned.contains("启动") || cleaned.contains("打开") || cleaned.contains("关") || cleaned.contains("停") || cleaned.contains("退"))) {
            let isStop = cleaned.contains("关") || cleaned.contains("停") || cleaned.contains("退") ||
                         cleaned.contains("取消") || cleaned.contains("中止") ||
                         cleaned.contains("别") || cleaned.contains("不要") || cleaned.contains("不用") ||
                         containsNegativeAction(cleaned)
            if isStop {
                return VoiceParseResult(command: .stopSleepCurve, displayText: "停止智能睡眠温阶")
            } else {
                let curveName: String?
                if cleaned.contains("儿童") || cleaned.contains("老人") || cleaned.contains("轻柔") {
                    curveName = "轻柔呵护"
                } else if cleaned.contains("省电") || cleaned.contains("清爽") {
                    curveName = "清爽省电"
                } else {
                    curveName = "标准舒适"
                }
                return VoiceParseResult(command: .startSleepCurve(curveName: curveName), displayText: "启动「\(curveName ?? "标准舒适")」睡眠温阶")
            }
        }

        // 5. 56°C 蒸发器自清洁启停 (v1.9.30)
        if cleaned.contains("自清洁") || cleaned.contains("清洗蒸发器") || cleaned.contains("蒸发器清洁") || cleaned.contains("高温除菌") {
            let isStop = cleaned.contains("关") || cleaned.contains("停") || cleaned.contains("退") ||
                         cleaned.contains("取消") || cleaned.contains("中止") ||
                         cleaned.contains("别") || cleaned.contains("不要") || cleaned.contains("不用") ||
                         containsNegativeAction(cleaned)
            if isStop {
                return VoiceParseResult(command: .stopSelfCleaning, displayText: "停止蒸发器自清洁")
            } else {
                return VoiceParseResult(command: .startSelfCleaning, displayText: "启动 56°C 蒸发器高温自清洁")
            }
        }

        // 6. 全屋多设备协同开/关控制与模式/温度预设 (v1.9.33，放在单设备开/关机前拦截)
        if isAllPowerOff(cleaned) {
            return VoiceParseResult(command: .turnOffAll, displayText: "关闭全屋所有空调")
        }
        if let allPreset = parseAllPreset(cleaned) {
            return allPreset
        }
        if let allTemp = parseAllTemperature(cleaned) {
            return allTemp
        }
        if let allRelativeTemp = parseAllRelativeTemperature(cleaned) {
            return allRelativeTemp
        }
        if isAllPowerOn(cleaned) {
            return VoiceParseResult(command: .turnOnAll, displayText: "开启全屋所有空调")
        }

        // 7. 定时与倒计时任务（放在立即开关机前，避免“30分钟后关机”被提前作为立即关机拦截）
        if let scheduleOrCountdown = parseScheduleOrCountdown(cleaned) {
            return scheduleOrCountdown
        }

        // 8. 立即关机 / 开机（注意：关机判定放在开机前，避免“关闭空调”因含有“开”而被误判）
        if isPowerOff(cleaned) {
            return VoiceParseResult(command: .setPower(false), displayText: "关闭空调电源")
        }
        if isPowerOn(cleaned) {
            return VoiceParseResult(command: .setPower(true), displayText: "打开空调电源")
        }

        // 6. 相对温度微调（太冷了/太热了/高一度/低一度）
        if let relative = parseRelativeTemperature(cleaned) {
            return relative
        }

        // 7. 绝对温度设定（调到26度 / 26度 / 二十六度）
        if let absolute = parseAbsoluteTemperature(cleaned) {
            return absolute
        }

        // 8. 风速调节（放在模式切换之前，避免“自动风”被“自动”误判拦截）
        if let wind = parseWindSpeed(cleaned) {
            return wind
        }

        // 9. 运行模式切换
        if let mode = parseMode(cleaned) {
            return mode
        }

        // 10. 情景模式
        if let scene = parseScene(cleaned) {
            return scene
        }

        return nil
    }

    // MARK: - 辅助解析子函数

    private static func isCancelSchedule(_ text: String) -> Bool {
        let cancelKeywords = ["取消定时", "取消倒计时", "关闭定时", "清除定时", "删除定时", "取消预约", "别定了", "别定时", "不要定时", "不用定时"]
        if cancelKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 自然语言容错：包含“取消/关闭/清除/删除/撤销”且包含“定时/倒计时/预约”（如“取消所有定时任务”、“关闭全屋倒计时”）
        if (text.contains("取消") || text.contains("关闭") || text.contains("清除") || text.contains("删除") || text.contains("撤销")) &&
           (text.contains("定时") || text.contains("倒计时") || text.contains("预约")) {
            return true
        }
        return false
    }

    private static func parseScheduleOrCountdown(_ text: String) -> VoiceParseResult? {
        // 先判断是否为倒计时（如包含“后”、“倒计时”、“定时关/开”或“定时X分钟/小时”）
        if text.contains("后") || text.contains("倒计时") ||
           text.contains("定时关") || text.contains("定时开") ||
           (text.contains("定时") && (text.contains("分") || text.contains("小时") || text.contains("钟头"))) {
            if let minutes = parseCountdownMinutes(from: text) {
                let isPowerOn = text.contains("开") && !text.contains("关")
                let actionStr = isPowerOn ? "开机" : "关机"
                let timeStr: String
                if minutes >= 60 && minutes % 60 == 0 {
                    timeStr = "\(minutes / 60) 小时"
                } else {
                    timeStr = "\(minutes) 分钟"
                }
                return VoiceParseResult(
                    command: .countdownPower(minutes: minutes, power: isPowerOn),
                    displayText: "设定 \(timeStr)后\(actionStr)"
                )
            }
        }

        // 再判断是否为指定具体钟点定时（如“晚上10点关机”、“明早7点开空调”）
        // 必须包含关机/开机意图或“定时”，避免“大风一点”、“调高一点”等“一点”被误判为 1 点钟
        if (text.contains("关") || text.contains("开") || text.contains("定时") || text.contains("预约")),
           let time = parseScheduleTime(from: text) {
            let isPowerOn = text.contains("开") && !text.contains("关")
            let actionStr = isPowerOn ? "开机" : "关机"
            let timeStr = String(format: "%02d:%02d", time.hour, time.minute)
            return VoiceParseResult(
                command: .schedulePower(hour: time.hour, minute: time.minute, power: isPowerOn),
                displayText: "定时在 \(timeStr) \(actionStr)"
            )
        }

        return nil
    }

    private static func parseCountdownMinutes(from text: String) -> Int? {
        let normalized = convertChineseNumbers(in: text)

        // 1. 特殊固定表达
        if normalized.contains("1.5小时") || normalized.contains("1.5个钟头") {
            return 90
        }
        if normalized.contains("0.5小时") || normalized.contains("0.5个钟头") || normalized.contains("半小时") {
            return 30
        }

        var totalMinutes = 0
        var found = false

        // 匹配 X小时 或 X个钟头
        let hourPattern = #"(\d+(?:\.\d+)?)\s*(?:小时|个钟头)"#
        if let regex = try? NSRegularExpression(pattern: hourPattern) {
            let ns = normalized as NSString
            if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                let valStr = ns.substring(with: match.range(at: 1))
                if let h = Double(valStr) {
                    totalMinutes += Int(h * 60)
                    found = true
                }
            }
        }

        // 匹配 Y分钟 或 Y分
        let minPattern = #"(\d+)\s*(?:分钟|分)"#
        if let regex = try? NSRegularExpression(pattern: minPattern) {
            let ns = normalized as NSString
            if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                let valStr = ns.substring(with: match.range(at: 1))
                if let m = Int(valStr) {
                    totalMinutes += m
                    found = true
                }
            }
        }

        if found && totalMinutes > 0 {
            return totalMinutes
        }

        // 纯数字 + 后 判定（如：30后关机 -> 30分钟后）
        let numPattern = #"(\d+)\s*后"#
        if let regex = try? NSRegularExpression(pattern: numPattern) {
            let ns = normalized as NSString
            if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                let valStr = ns.substring(with: match.range(at: 1))
                if let num = Int(valStr) {
                    return num <= 12 ? num * 60 : num
                }
            }
        }

        // 默认“定时关机”/“定时关空调” -> 默认 60 分钟
        if text.contains("定时关") || text.contains("倒计时关") {
            return 60
        }

        return nil
    }

    private static func parseScheduleTime(from text: String) -> (hour: Int, minute: Int)? {
        let normalized = convertChineseNumbers(in: text)

        // 必须包含“点”或“时”或者标准时间冒号，且不是“小时”
        guard (normalized.contains("点") || normalized.contains("时") || normalized.contains(":")) && !normalized.contains("小时") else {
            return nil
        }

        var isPM = false
        if normalized.contains("下午") || normalized.contains("晚上") || normalized.contains("今晚") ||
           normalized.contains("明晚") || normalized.contains("夜里") || normalized.contains("傍晚") {
            isPM = true
        }

        var hour: Int?
        var minute: Int = 0

        // 1. 标准时间格式 22:30 或 8:00
        let colonPattern = #"(\d{1,2}):(\d{2})"#
        if let regex = try? NSRegularExpression(pattern: colonPattern) {
            let ns = normalized as NSString
            if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                let hStr = ns.substring(with: match.range(at: 1))
                let mStr = ns.substring(with: match.range(at: 2))
                if let h = Int(hStr), let m = Int(mStr) {
                    hour = h
                    minute = m
                }
            }
        }

        // 2. X点 / X时
        if hour == nil {
            let pointPattern = #"(\d{1,2})\s*(?:点|时)"#
            if let regex = try? NSRegularExpression(pattern: pointPattern) {
                let ns = normalized as NSString
                if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                    let hStr = ns.substring(with: match.range(at: 1))
                    if let h = Int(hStr) {
                        hour = h
                    }
                }
            }
        }

        guard var finalHour = hour else { return nil }

        // 判断分钟
        if minute == 0 {
            let minPattern = #"(?:点|时)\s*(\d{1,2})\s*分?"#
            if let regex = try? NSRegularExpression(pattern: minPattern) {
                let ns = normalized as NSString
                if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                    let mStr = ns.substring(with: match.range(at: 1))
                    if let m = Int(mStr) {
                        minute = m
                    }
                }
            }
        }

        if isPM && finalHour < 12 {
            finalHour += 12
        }
        if finalHour >= 24 {
            finalHour = 0
        }

        return (finalHour, minute)
    }

    private static let negativeActionRegex: NSRegularExpression? = {
        // 否定词（别/不要/不用/不必/无需/先别/先不要/暂不/暂不要/千万别/千万不要/不能/不可以/切勿/切莫/不要再/别再/暂时不用/暂时不要）
        // 允许插入 0~6 个修饰词、量词、介词或设备名词（都/全/全部/全屋/全都/一起/统统/通通/马上/立刻/赶快/赶紧/急着/再/又/先/直接/也/把/给/将/空调/设备/机器/电源）
        // 动作谓词（关/停/开/启动/运转/打开/关闭）
        let pattern = #"(?:别|不要|不用|不必|无需|先别|先不要|暂不|暂不要|千万别|千万不要|不能|不可以|切勿|切莫|不要再|别再|暂时不用|暂时不要)[都全部屋所有一起统通马上立刻赶紧急着再又先直接也把给将空调设备机器电源它这个那房间主卧客厅]{0,6}(?:关|停|开|启动|运转|打开|关闭)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 检测文本中是否包含针对开关机动作的否定意图（如“别关”、“不要全部关”、“别急着关”、“先别开”等，防止误触发） (v1.9.36 闭环 CR P1-1)
    private static func containsNegativeAction(_ text: String) -> Bool {
        guard let regex = negativeActionRegex else {
            let fallbackPatterns = [
                "别关", "不要关", "不用关", "先别关", "先不要关", "暂不关", "不能关", "不可以关", "别停", "不要停", "不用停",
                "别开", "不要开", "不用开", "先别开", "先不要开", "暂不开", "不能开", "不可以开", "别启动", "不要启动"
            ]
            return fallbackPatterns.contains(where: { text.contains($0) })
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    private static func isAllPowerOff(_ text: String) -> Bool {
        guard !containsNegativeAction(text) else { return false }
        let allOffKeywords = [
            "关闭所有空调", "关掉所有空调", "关闭全部空调", "关掉全部空调",
            "关所有空调", "关全部空调", "全屋关机", "全部关机", "全关了", "都关了", "全都关了",
            "关闭全屋空调", "关掉全屋空调", "全屋关空调", "所有空调关机", "全屋关",
            "把所有的空调都关了", "把所有空调都关了", "把空调都关了", "把空调全都关了",
            "把所有的空调都关掉", "把所有空调都关掉", "把空调都关掉", "把空调全都关掉",
            "把全部空调关了", "把全部空调关掉", "所有空调都关了", "全部空调都关了",
            "所有空调关掉", "全部空调关掉", "空调全关了", "空调都关了", "全关掉"
        ]
        if allOffKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 自然语言容错：包含“所有/全部/全屋/全都”并包含“关/停”
        if (text.contains("所有") || text.contains("全部") || text.contains("全屋") || text.contains("全都")) &&
           (text.contains("关") || text.contains("停")) {
            return true
        }
        return false
    }

    private static func isAllDeviceScope(_ text: String) -> Bool {
        text.contains("所有") || text.contains("全部") || text.contains("全屋") || text.contains("全都")
    }

    private static func parseAllPreset(_ text: String) -> VoiceParseResult? {
        guard !containsNegativeAction(text) else { return nil }
        guard isAllDeviceScope(text) else { return nil }

        // 识别模式
        let detectedMode: String? = {
            if text.contains("制冷") || text.contains("冷气") || text.contains("冷风") { return "制冷" }
            if text.contains("制热") || text.contains("暖气") || text.contains("暖风") || text.contains("加热") { return "制热" }
            if text.contains("送风") || text.contains("吹风") || text.contains("通风") { return "送风" }
            if text.contains("除湿") || text.contains("抽湿") || text.contains("干燥") { return "除湿" }
            if text.contains("自动") || text.contains("智能") { return "自动" }
            return nil
        }()

        guard let mode = detectedMode else { return nil }

        // 识别温度（若有）
        var targetTemp: Double? = nil
        if let val = extractTemperatureValue(from: text), val >= 16.0 && val <= 30.0 {
            targetTemp = val
        } else {
            if mode == "制热" {
                targetTemp = 20.0
            } else if mode == "制冷" {
                targetTemp = 26.0
            } else if mode == "自动" {
                targetTemp = 24.0
            }
        }

        let display: String
        if let t = targetTemp {
            let tempStr = formatTemp(t)
            if mode == "制热" {
                display = "全屋舒适制热 \(tempStr)°C"
            } else if mode == "制冷" {
                display = "全屋清爽制冷 \(tempStr)°C"
            } else {
                display = "全屋\(mode)模式 \(tempStr)°C"
            }
        } else {
            display = "全屋\(mode)模式"
        }

        return VoiceParseResult(command: .presetAll(mode: mode, temperature: targetTemp), displayText: display)
    }

    private static func parseAllTemperature(_ text: String) -> VoiceParseResult? {
        guard !containsNegativeAction(text) else { return nil }
        guard isAllDeviceScope(text) else { return nil }
        // 排除已指定运行模式的情况
        if text.contains("制冷") || text.contains("冷气") || text.contains("制热") || text.contains("暖气") ||
           text.contains("送风") || text.contains("除湿") || text.contains("吹风") || text.contains("抽湿") {
            return nil
        }
        guard let temp = extractTemperatureValue(from: text), temp >= 16.0 && temp <= 30.0 else {
            return nil
        }
        let tempStr = formatTemp(temp)
        return VoiceParseResult(command: .setTemperatureAll(temp), displayText: "全屋温度调至 \(tempStr)°C")
    }

    private static func parseAllRelativeTemperature(_ text: String) -> VoiceParseResult? {
        guard !containsNegativeAction(text) else { return nil }
        guard isAllDeviceScope(text) else { return nil }
        // 排除已指定运行模式的情况
        if text.contains("制冷") || text.contains("冷气") || text.contains("制热") || text.contains("暖气") ||
           text.contains("送风") || text.contains("除湿") || text.contains("吹风") || text.contains("抽湿") {
            return nil
        }
        if let rel = parseRelativeTemperature(text) {
            if case .adjustTemperature(let delta) = rel.command {
                let dir = delta > 0 ? "升温" : "降温"
                let deltaAbs = abs(delta)
                let deltaStr = formatTemp(deltaAbs)
                return VoiceParseResult(
                    command: .adjustTemperatureAll(delta: delta),
                    displayText: "全屋\(dir) \(deltaStr)°C"
                )
            }
        }
        return nil
    }

    private static func isAllPowerOn(_ text: String) -> Bool {
        guard !containsNegativeAction(text) else { return false }
        // 排除模式与温控命令（如“全屋开暖气”、“全屋开冷气”、“全屋开制热”、“全屋开到26度”），防止冷暖倒置 (v1.9.33)
        if text.contains("冷气") || text.contains("暖气") || text.contains("制冷") || text.contains("制热") ||
           text.contains("冷风") || text.contains("暖风") || text.contains("度") {
            return false
        }
        let allOnKeywords = [
            "打开所有空调", "开启所有空调", "打开全部空调", "开启全部空调",
            "开所有空调", "开全部空调", "全屋开机", "全部开机", "全开了", "都开了", "全都开了",
            "开启全屋空调", "打开全屋空调", "全屋开空调", "所有空调开机", "全屋开",
            "把所有的空调都开了", "把所有空调都开了", "把空调都打开", "把空调全都打开",
            "把所有的空调都打开", "把所有空调都打开", "把全部空调打开", "把全部空调开了",
            "所有空调都开了", "全部空调都开了", "所有空调打开", "全部空调打开",
            "空调全开了", "空调都开了", "全打开"
        ]
        if allOnKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 自然语言容错：包含“所有/全部/全屋/全都”并包含“开/启”且不含关
        if (text.contains("所有") || text.contains("全部") || text.contains("全屋") || text.contains("全都")) &&
           (text.contains("开") || text.contains("启")) && !text.contains("关") {
            return true
        }
        return false
    }

    private static func isPowerOff(_ text: String) -> Bool {
        guard !containsNegativeAction(text) else { return false }
        let offKeywords = [
            "关空调", "关闭空调", "关掉空调", "关机", "别吹了", "停机", "关闭", "关掉",
            "关了", "关上", "关一下", "关停", "关掉它", "断电"
        ]
        if offKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 典型把字句与口语结构：包含“关了”、“关掉”、“关上”或以“关”开头/结尾
        if (text.contains("把") && (text.contains("关了") || text.contains("关掉") || text.contains("关上"))) ||
           text.hasPrefix("关") || text.hasSuffix("关") || text.hasSuffix("关了") || text.hasSuffix("关机") || text.hasSuffix("关一下") {
            return true
        }
        return false
    }

    private static func isPowerOn(_ text: String) -> Bool {
        guard !containsNegativeAction(text) else { return false }
        // 排除模式切换命令（如“开冷气”、“开暖气”、“吹冷风”）
        if text.contains("冷气") || text.contains("暖气") || text.contains("冷风") || text.contains("暖风") {
            return false
        }
        let onKeywords = [
            "开空调", "打开空调", "开一下空调", "开机", "启动空调", "开启空调", "开开空调",
            "开一下", "打开", "开启", "开开", "开了", "开上", "启动", "运转"
        ]
        if onKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 典型把字句与口语结构：包含“开了”、“打开”、“开启”或以“开”开头/结尾
        if (text.contains("把") && (text.contains("开了") || text.contains("打开") || text.contains("开启"))) ||
           text.hasPrefix("开") || text.hasSuffix("开") || text.hasSuffix("开了") || text.hasSuffix("开机") || text.hasSuffix("开一下") {
            return true
        }
        return false
    }

    private static func parseRelativeTemperature(_ text: String) -> VoiceParseResult? {
        // 优先匹配带明确方向与幅度的口令（如“太冷了调高两度”、“升温2度”、“降温两度”、“降温1度”）
        if text.contains("高") || text.contains("升") || text.contains("加") || text.contains("热一点") || text.contains("暖和一点") {
            let delta = extractNumber(from: text) ?? 1.0
            let validDelta = (delta > 0 && delta <= 5) ? delta : 1.0
            return VoiceParseResult(
                command: .adjustTemperature(delta: validDelta),
                displayText: "升温 \(formatTemp(validDelta))°C"
            )
        }

        if text.contains("低") || text.contains("降") || text.contains("减") || text.contains("冷一点") || text.contains("凉一点") {
            let delta = extractNumber(from: text) ?? 1.0
            let validDelta = (delta > 0 && delta <= 5) ? delta : 1.0
            return VoiceParseResult(
                command: .adjustTemperature(delta: -validDelta),
                displayText: "降温 \(formatTemp(validDelta))°C"
            )
        }

        // 纯感叹词（默认调节 1 度）
        if text.contains("太热") || text.contains("好热") || text.contains("有点热") || text.contains("热死") {
            return VoiceParseResult(command: .adjustTemperature(delta: -1.0), displayText: "降温 1°C")
        }
        if text.contains("太冷") || text.contains("好冷") || text.contains("有点冷") || text.contains("冷死") {
            return VoiceParseResult(command: .adjustTemperature(delta: 1.0), displayText: "升温 1°C")
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
        guard !containsNegativeAction(text) else { return nil }
        if text.contains("不要") || text.contains("别") || text.contains("不用") || text.contains("暂不") {
            return nil
        }
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
        if text.contains("大风") || text.contains("风大") || text.contains("强劲") || text.contains("高风") ||
           text.contains("最大风") || text.contains("最大") || text.contains("调大风") || text.contains("风速大") ||
           text.contains("高速风") || text.contains("开到最大") {
            return VoiceParseResult(command: .setWindSpeed("强劲"), displayText: "切换至强劲风速")
        }
        if text.contains("小风") || text.contains("风小") || text.contains("微风") || text.contains("低风") ||
           text.contains("静音") || text.contains("柔风") || text.contains("最小风") || text.contains("调小风") ||
           text.contains("风速小") || text.contains("低速风") || text.contains("开到最小") {
            return VoiceParseResult(command: .setWindSpeed("微风"), displayText: "切换至微风模式")
        }
        if text.contains("中风") || text.contains("适中") || text.contains("风速中") || text.contains("中速风") {
            return VoiceParseResult(command: .setWindSpeed("中风"), displayText: "切换至中档风速")
        }
        return nil
    }

    private static func parseScene(_ text: String) -> VoiceParseResult? {
        guard !containsNegativeAction(text) else { return nil }
        if text.contains("不要") || text.contains("别") || text.contains("不用") || text.contains("暂不") {
            return nil
        }
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
        var normalized = convertChineseNumbers(in: text)
        normalized = normalized.replacingOccurrences(of: "点", with: ".")

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
        // 先处理时间特定的固定搭配
        str = str.replacingOccurrences(of: "一个半小时", with: "90分钟")
        str = str.replacingOccurrences(of: "1个半小时", with: "90分钟")
        str = str.replacingOccurrences(of: "半小时", with: "30分钟")
        str = str.replacingOccurrences(of: "点半", with: "点30分")
        str = str.replacingOccurrences(of: "时半", with: "点30分")
        str = str.replacingOccurrences(of: "两", with: "2")

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
            ("十四", "14"),
            ("十三", "13"),
            ("十二", "12"),
            ("十一", "11"),
            ("十", "10"),
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
            ("点五", ".5")
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
