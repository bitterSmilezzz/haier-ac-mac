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
    /// 查询全屋所有空调状态与汇总 (v1.9.38)
    case queryStatusAll
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
    /// 设定运行模式与目标温度 (mode: 模式名称如"制冷"/"制热", temperature: 可选温度) (v1.9.39)
    case setModeAndTemperature(mode: String, temperature: Double?)
    /// 全屋/所有设备统一设置风速 (speed: 如"微风"/"中风"/"强劲"/"自动") (v1.9.41)
    case setWindSpeedAll(String)
    /// 启动 56°C 蒸发器高温自清洁 (v1.9.30)
    case startSelfCleaning
    /// 停止蒸发器自清洁 (v1.9.30)
    case stopSelfCleaning
    /// 查询空调滤网洁净度与保养健康状态 (v1.9.44)
    case queryFilterHealth
    /// 查询全屋所有空调滤网健康状态与汇总 (v1.9.44)
    case queryFilterHealthAll
    /// 重置空调滤网运行时间与保养计时 (v1.9.45)
    case resetFilterMaintenance
    /// 重置全屋所有空调滤网运行时间与保养计时 (v1.9.45)
    case resetFilterMaintenanceAll
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

        // 1. 查询类（支持全屋空调状态汇总与室内温度查询） (v1.9.38)
        if cleaned.contains("多少度") || cleaned.contains("当前温度") || cleaned.contains("室内温度") ||
           cleaned.contains("现在温度") || cleaned.contains("查温度") || cleaned.contains("室温") ||
           cleaned.contains("查状态") || cleaned.contains("空调状态") || cleaned.contains("运行状态") {
            if isAllDeviceScope(cleaned) {
                return VoiceParseResult(command: .queryStatusAll, displayText: "查询全屋空调状态")
            } else {
                return VoiceParseResult(command: .queryStatus, displayText: "查询室内温度")
            }
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

        // 5.1 滤网保养重置与复位 (v1.9.45)
        // 优先于滤网健康度查询，避免“滤网洗好了/已清洗”因包含“洗”被误判为查询
        if isResetFilterMaintenance(cleaned) {
            if isAllDeviceScope(cleaned) {
                return VoiceParseResult(command: .resetFilterMaintenanceAll, displayText: "重置全屋滤网保养计时")
            } else {
                return VoiceParseResult(command: .resetFilterMaintenance, displayText: "重置滤网保养计时")
            }
        }

        // 5.2 滤网健康度与洁净度查询 (v1.9.44)
        if cleaned.contains("滤网") || cleaned.contains("过滤网") || cleaned.contains("过滤片") {
            if cleaned.contains("洁净") || cleaned.contains("健康") || cleaned.contains("寿命") ||
               cleaned.contains("状态") || cleaned.contains("洗") || cleaned.contains("查") ||
               cleaned.contains("脏") || cleaned.contains("怎么样") || cleaned.contains("换") ||
               cleaned.contains("看") || cleaned.contains("报告") {
                if isAllDeviceScope(cleaned) {
                    return VoiceParseResult(command: .queryFilterHealthAll, displayText: "查询全屋滤网健康度")
                } else {
                    return VoiceParseResult(command: .queryFilterHealth, displayText: "查询滤网健康度")
                }
            }
        }

        // 6. 定时与倒计时任务（优先于立即开关机与预设执行，避免“全屋30分钟后关机”被提前作为立即关机拦截） (v1.9.40)
        if let scheduleOrCountdown = parseScheduleOrCountdown(cleaned) {
            return scheduleOrCountdown
        }

        // 7. 全屋多设备协同立即开/关控制与模式/温度预设 (v1.9.33)
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
        if isAllDeviceScope(cleaned), let allWind = parseWindSpeed(cleaned) {
            return allWind
        }
        if isAllPowerOn(cleaned) {
            return VoiceParseResult(command: .turnOnAll, displayText: "开启全屋所有空调")
        }

        // 8. 立即关机 / 开机（注意：关机判定放在开机前，避免“关闭空调”因含有“开”而被误判）
        if isPowerOff(cleaned) {
            return VoiceParseResult(command: .setPower(false), displayText: "关闭空调电源")
        }
        if isPowerOn(cleaned) {
            return VoiceParseResult(command: .setPower(true), displayText: "打开空调电源")
        }

        // 9. 运行模式 + 温度复合设定（如“制冷26度”、“开暖气22度”、“开制冷26度”、“客厅制冷24度”）(v1.9.39 彻底解决复合口令模式丢失缺陷)
        if let modeAndTemp = parseModeAndTemperature(cleaned) {
            return modeAndTemp
        }

        // 10. 相对温度微调（太冷了/太热了/高一度/低一度）
        if let relative = parseRelativeTemperature(cleaned) {
            return relative
        }

        // 11. 绝对温度设定（调到26度 / 26度 / 二十六度）
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

    private static func isResetFilterMaintenance(_ text: String) -> Bool {
        guard !containsNegativeAction(text) else { return false }
        guard text.contains("滤网") || text.contains("过滤网") || text.contains("过滤片") else {
            return false
        }

        let resetKeywords = [
            "重置", "复位", "清零", "已清洗", "清洗完成", "洗好了", "洗完了", "洗过了", "洗好", "洗完",
            "已洗", "刚洗", "换好了", "换完了", "已更换", "更换完成", "换新", "换了新", "装了新", "已装好", "恢复100"
        ]

        if resetKeywords.contains(where: { text.contains($0) }) {
            return true
        }

        // 结构化时态匹配：包含“洗/换/擦”且包含“干净了/好了/完了/过了/搞定”
        if (text.contains("洗") || text.contains("换") || text.contains("擦")) &&
           (text.contains("干净了") || text.contains("好了") || text.contains("完了") || text.contains("过了") || text.contains("搞定")) {
            return true
        }

        return false
    }

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
        let isAll = isAllDeviceScope(text)

        // 判定是否包含明确的具体钟点时间指示词（点/时/:），此时即使包含“定时”与“分”（如“定时在十点五分关机”），也不应误判为倒计时 (v1.9.48)
        let withoutTiming = text.replacingOccurrences(of: "定时", with: "")
        let hasClockTime = (withoutTiming.contains("点") || withoutTiming.contains("时") || withoutTiming.contains(":")) &&
                           !withoutTiming.contains("小时") && !withoutTiming.contains("钟头") &&
                           !withoutTiming.contains("后") && !withoutTiming.contains("倒计时")

        // 先判断是否为倒计时（如包含“后”、“倒计时”、“定时关/开”或“定时X分钟/小时”）
        if !hasClockTime && (text.contains("后") || text.contains("倒计时") ||
           text.contains("定时关") || text.contains("定时开") ||
           (text.contains("定时") && (text.contains("分") || text.contains("小时") || text.contains("钟头")))) {
            if let minutes = parseCountdownMinutes(from: text) {
                let isPowerOn = text.contains("开") && !text.contains("关")
                let actionStr = isPowerOn ? "开机" : "关机"
                let timeStr: String
                if minutes >= 60 && minutes % 60 == 0 {
                    timeStr = "\(minutes / 60) 小时"
                } else {
                    timeStr = "\(minutes) 分钟"
                }
                let display = isAll ? "全屋设定 \(timeStr)后\(actionStr)" : "设定 \(timeStr)后\(actionStr)"
                return VoiceParseResult(
                    command: .countdownPower(minutes: minutes, power: isPowerOn),
                    displayText: display
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
            let display = isAll ? "定时全屋在 \(timeStr) \(actionStr)" : "定时在 \(timeStr) \(actionStr)"
            return VoiceParseResult(
                command: .schedulePower(hour: time.hour, minute: time.minute, power: isPowerOn),
                displayText: display
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

        // 匹配 X小时 或 X个小时 或 X个钟头 (v1.9.46 覆盖日常高频“一个小时/两个小时/2个小时”等)
        let hourPattern = #"(\d+(?:\.\d+)?)\s*(?:个?小时|个钟头)"#
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

        let isNightMidnight = normalized.contains("晚上") || normalized.contains("今晚") ||
                              normalized.contains("明晚") || normalized.contains("夜里") ||
                              normalized.contains("半夜") || normalized.contains("午夜") ||
                              normalized.contains("凌晨")
        let isAfternoonPM = normalized.contains("下午") || normalized.contains("傍晚") || normalized.contains("午后")
        let isNoon = normalized.contains("中午")

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

        // 2. 差分倒算结构 (v1.9.48: 支持“十点差五分”与“差五分十点”等逆序时间计算)
        // 2.1 Pattern: (\d{1,2})\s*(?:点|时)\s*差\s*(\d{1,2})\s*分? (如 10点差5分 -> 09:55)
        if hour == nil {
            let diffPattern1 = #"(\d{1,2})\s*(?:点|时)\s*差\s*(\d{1,2})\s*分?"#
            if let regex = try? NSRegularExpression(pattern: diffPattern1) {
                let ns = normalized as NSString
                if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                    let targetHStr = ns.substring(with: match.range(at: 1))
                    let diffMStr = ns.substring(with: match.range(at: 2))
                    if let targetH = Int(targetHStr), let diffM = Int(diffMStr), diffM > 0 && diffM < 60 {
                        hour = (targetH + 24 - 1) % 24
                        minute = 60 - diffM
                    }
                }
            }
        }

        // 2.2 Pattern: 差\s*(\d{1,2})\s*分?\s*(\d{1,2})\s*(?:点|时) (如 差5分10点 -> 09:55)
        if hour == nil {
            let diffPattern2 = #"差\s*(\d{1,2})\s*分?\s*(\d{1,2})\s*(?:点|时)"#
            if let regex = try? NSRegularExpression(pattern: diffPattern2) {
                let ns = normalized as NSString
                if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                    let diffMStr = ns.substring(with: match.range(at: 1))
                    let targetHStr = ns.substring(with: match.range(at: 2))
                    if let targetH = Int(targetHStr), let diffM = Int(diffMStr), diffM > 0 && diffM < 60 {
                        hour = (targetH + 24 - 1) % 24
                        minute = 60 - diffM
                    }
                }
            }
        }

        // 3. X点 / X时 (含零点 / 0点及后接分钟提取)
        if hour == nil {
            let pointPattern = #"(\d{1,2})\s*(?:点|时)(?:\s*(?:过|零|0)?\s*(\d{1,2})\s*分?)?"#
            if let regex = try? NSRegularExpression(pattern: pointPattern) {
                let ns = normalized as NSString
                if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                    let hStr = ns.substring(with: match.range(at: 1))
                    if let h = Int(hStr) {
                        hour = h
                    }
                    let minRange = match.range(at: 2)
                    if minRange.location != NSNotFound {
                        let mStr = ns.substring(with: minRange)
                        if let m = Int(mStr) {
                            minute = m
                        }
                    }
                }
            }
        }

        guard var finalHour = hour else { return nil }

        // 4. 兜底后置分钟（以防复杂修饰语未被第3条捕获）
        if minute == 0 {
            let minPattern = #"(?:点|时)\s*(?:过|零|0)?\s*(\d{1,2})\s*分"#
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

        // 5. 钟点时段与时态校准 (v1.9.48 彻底根除午夜/零点误为正午及中午11点误为深夜23点缺陷)
        if finalHour == 12 {
            if isNightMidnight {
                // “晚上12点”、“半夜12点”、“午夜12点”、“凌晨12点”均代表午夜 00:00
                finalHour = 0
            }
        } else if finalHour == 0 {
            // 明确的“零点/0点/0时”，无论前缀如何，恒定为 00:xx，严禁累加 12
            finalHour = 0
        } else if finalHour > 0 && finalHour < 12 {
            if isAfternoonPM || (normalized.contains("晚上") || normalized.contains("今晚") || normalized.contains("明晚") || normalized.contains("夜里") || normalized.contains("傍晚")) {
                finalHour += 12
            } else if isNoon && finalHour <= 5 {
                // 中午 1 点、2 点等午后时段
                finalHour += 12
            }
        }

        if finalHour >= 24 {
            finalHour = 0
        }

        return (finalHour, minute)
    }

    private static let negativeActionRegex: NSRegularExpression? = {
        // 否定词（别/不要/不用/不必/无需/先别/先不要/暂不/暂不要/千万别/千万不要/不能/不可以/切勿/切莫/不要再/别再/暂时不用/暂时不要）
        // 允许中间插入 0~6 个任意非标点非空白字符（如“给我”、“帮我”、“急着”、“现在”、“太快”、“乱”、“随便”等，彻底杜绝插字绕过漏洞） (v1.9.40)
        // 动作谓词（关/停/开/启动/运转/打开/关闭/调/设/升/降/重置/复位/清零） (v1.9.39 扩展调温与变频动作否定, v1.9.45 扩展滤网重置否定)
        let pattern = #"(?:别|不要|不用|不必|无需|先别|先不要|暂不|暂不要|千万别|千万不要|不能|不可以|切勿|切莫|不要再|别再|暂时不用|暂时不要)[^，。！？\s]{0,6}?(?:关|停|开|启动|运转|打开|关闭|调|设|升|降|重置|复位|清零)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 检测文本中是否包含针对开关机/调温/模式动作的否定意图（如“别关”、“不要开”、“先别急着关”、“别给我关了”、“千万别现在关”、“别开制冷”、“不要调”、“别重置”等，防止误触发） (v1.9.36, v1.9.40, v1.9.45)
    private static func containsNegativeAction(_ text: String) -> Bool {
        guard let regex = negativeActionRegex else {
            let fallbackPatterns = [
                "别关", "不要关", "不用关", "先别关", "先不要关", "暂不关", "不能关", "不可以关", "别停", "不要停", "不用停",
                "别开", "不要开", "不用开", "先别开", "先不要开", "暂不开", "不能开", "不可以开", "别启动", "不要启动",
                "别调", "不要调", "不用调", "别设", "不要设", "别升", "不要升", "别降", "不要降",
                "别重置", "不要重置", "不用重置", "别复位", "不要复位", "别清零",
                "别给我关", "千万别关", "千万别开"
            ]
            return fallbackPatterns.contains(where: { text.contains($0) })
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    private static let targetRoomKeywords = [
        "客厅", "主卧", "次卧", "书房", "儿童房", "老人房", "客房", "餐厅", "阳台", "卧室", "厨房"
    ]

    private static func hasTargetRoomKeyword(_ text: String) -> Bool {
        targetRoomKeywords.contains(where: { text.contains($0) })
    }

    private static func isAllPowerOff(_ text: String) -> Bool {
        guard !containsNegativeAction(text) else { return false }
        // 排除定时与倒计时命令（如“全屋30分钟后关机”、“全屋定时关机”、“所有空调晚上10点关机”） (v1.9.40)
        if text.contains("后") || text.contains("倒计时") || text.contains("定时") || text.contains("预约") {
            return false
        }
        // 若口令中包含明确的定向房间/设备词且未包含全屋全局作用域词（如“客厅和主卧都关了”），
        // 其中的“都”为指代前述房间的副词，严禁越权泛化为全屋关机 (v1.9.42)
        if hasTargetRoomKeyword(text) && !isAllDeviceScope(text) {
            return false
        }
        let allOffKeywords = [
            "关闭所有空调", "关掉所有空调", "关闭全部空调", "关掉全部空调",
            "关所有空调", "关全部空调", "全屋关机", "全部关机", "全关了", "都关了", "全都关了",
            "关闭全屋空调", "关掉全屋空调", "全屋关空调", "所有空调关机", "全屋关",
            "全关", "全部关", "全都关", "通通关了", "统统关了",
            "把所有的空调都关了", "把所有空调都关了", "把空调都关了", "把空调全都关了",
            "把所有的空调都关掉", "把所有空调都关掉", "把空调都关掉", "把空调全都关掉",
            "把全部空调关了", "把全部空调关掉", "所有空调都关了", "全部空调都关了",
            "所有空调关掉", "全部空调关掉", "空调全关了", "空调都关了", "全关掉"
        ]
        if allOffKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 自然语言容错：包含“所有/全部/全屋/全都”并包含“关/停”
        if (text.contains("所有") || text.contains("全部") || text.contains("全屋") || text.contains("全都") || text.contains("全家") || text.contains("整套")) &&
           (text.contains("关") || text.contains("停")) {
            return true
        }
        return false
    }

    public static func isAllDeviceScope(_ text: String) -> Bool {
        if hasTargetRoomKeyword(text) {
            // 当明确包含具体房间词（如“客厅”、“主卧”）时，仅当明确包含全局性主语（如“全屋”、“全家”、“整套”、“所有空调”、“全部空调”）时才属于全屋范围；
            // 彻底杜绝“把客厅和主卧全部关了/全都关了”中的副词“全部/全都”越权泛化为全屋关机 (v1.9.43)
            return text.contains("全屋") || text.contains("全家") || text.contains("整套") ||
                   text.contains("所有空调") || text.contains("全部空调")
        }
        return text.contains("所有") || text.contains("全部") || text.contains("全屋") || text.contains("全都") || text.contains("全家") || text.contains("整套")
    }

    private static func parseAllPreset(_ text: String) -> VoiceParseResult? {
        guard !containsNegativeAction(text) else { return nil }
        guard isAllDeviceScope(text) else { return nil }

        // 排除风速调节命令（如“全屋自动风”、“全屋开大风”、“所有空调微风”） (v1.9.41)
        if text.contains("自动风") || text.contains("风速") || text.contains("微风") || text.contains("大风") || text.contains("强劲") {
            return nil
        }

        // 识别模式
        let detectedMode: String? = {
            if text.contains("制冷") || text.contains("冷气") || text.contains("冷风") { return "制冷" }
            if text.contains("制热") || text.contains("暖气") || text.contains("暖风") || text.contains("加热") { return "制热" }
            if text.contains("送风") || text.contains("吹风") || text.contains("通风") { return "送风" }
            if text.contains("除湿") || text.contains("抽湿") || text.contains("干燥") { return "除湿" }
            if (text.contains("自动") || text.contains("智能")) && !text.contains("自动风") && !text.contains("风速") { return "自动" }
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
        // 排除定时与倒计时口令（如“全屋半小时后开机”经数字归一后包含“30分钟”），防止误触发全屋温度设为 30 度 (v1.9.40)
        if text.contains("后") || text.contains("倒计时") || text.contains("定时") || text.contains("预约") ||
           text.contains("分") || text.contains("小时") || text.contains("钟头") {
            return nil
        }
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
        // 排除定时与倒计时命令（如“全屋半小时后开机”、“全屋明早7点开机”） (v1.9.40)
        if text.contains("后") || text.contains("倒计时") || text.contains("定时") || text.contains("预约") {
            return false
        }
        // 若口令包含明确的定向房间/设备词且未包含全屋全局作用域词（如“客厅和次卧都开了”），
        // 其中的“都”为指代前述房间的副词，严禁越权泛化为全屋开机 (v1.9.42)
        if hasTargetRoomKeyword(text) && !isAllDeviceScope(text) {
            return false
        }
        // 排除带有具体有效温度（16~30°C）的口令（如“全屋开26度”、“全屋开26”、“所有空调开25”） (v1.9.41 完善全屋开机防线)
        if let temp = extractTemperatureValue(from: text), temp >= 16.0 && temp <= 30.0 {
            return false
        }
        // 排除模式与温控命令（如“全屋开暖气”、“全屋开冷气”、“全屋开制热”、“全屋开到26度”），防止冷暖倒置 (v1.9.33)
        if text.contains("冷气") || text.contains("暖气") || text.contains("制冷") || text.contains("制热") ||
           text.contains("冷风") || text.contains("暖风") || text.contains("度") {
            return false
        }
        // 排除风速调节命令（如“全屋开大风”、“所有空调开微风”、“全屋自动风”） (v1.9.41)
        let windKeywords = [
            "自动风", "风速", "大风", "风大", "强劲", "高风", "微风", "小风", "风小", "静音", "柔风", "低风", "中风"
        ]
        if windKeywords.contains(where: { text.contains($0) }) {
            return false
        }
        let allOnKeywords = [
            "打开所有空调", "开启所有空调", "打开全部空调", "开启全部空调",
            "开所有空调", "开全部空调", "全屋开机", "全部开机", "全开了", "都开了", "全都开了",
            "开启全屋空调", "打开全屋空调", "全屋开空调", "所有空调开机", "全屋开",
            "全开", "全部开", "全都开", "通通开了", "统统开了",
            "把所有的空调都开了", "把所有空调都开了", "把空调都打开", "把空调全都打开",
            "把所有的空调都打开", "把所有空调都打开", "把全部空调打开", "把全部空调开了",
            "所有空调都开了", "全部空调都开了", "所有空调打开", "全部空调打开",
            "空调全开了", "空调都开了", "全打开"
        ]
        if allOnKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 自然语言容错：包含“所有/全部/全屋/全都”并包含“开/启”且不含关
        if (text.contains("所有") || text.contains("全部") || text.contains("全屋") || text.contains("全都") || text.contains("全家") || text.contains("整套")) &&
           (text.contains("开") || text.contains("启")) && !text.contains("关") {
            return true
        }
        return false
    }

    private static func isPowerOff(_ text: String) -> Bool {
        guard !containsNegativeAction(text) else { return false }
        // 排除定时与倒计时命令（如“30分钟后关机”、“晚上10点关空调”） (v1.9.40)
        if text.contains("后") || text.contains("倒计时") || text.contains("定时") || text.contains("预约") {
            return false
        }
        // 排除风速调节（如“关小风”、“风速关小一点”）与相对调温（如“关小一点”） (v1.9.38)
        if (text.contains("小") || text.contains("微") || text.contains("低")) && (text.contains("风") || text.contains("速")) {
            return false
        }
        if text.contains("小一点") || text.contains("慢一点") || text.contains("轻一点") {
            return false
        }
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
        // 排除定时与倒计时命令（如“30分钟后开机”、“早上7点开空调”） (v1.9.40)
        if text.contains("后") || text.contains("倒计时") || text.contains("定时") || text.contains("预约") {
            return false
        }
        // 排除带有具体有效温度（16~30°C）的口令（如“开26度”、“开26”、“打开25”、“开到26度”）(v1.9.40 彻底消除省略“度”字时被误判为单纯开机的缺陷)
        if let temp = extractTemperatureValue(from: text), temp >= 16.0 && temp <= 30.0 {
            return false
        }
        // 排除模式切换命令（如“开制冷”、“开冷气”、“开制热”、“开暖气”、“开除湿”、“开抽湿”、“开送风”、“开吹风”、“开自动”、“打开除湿”、“开启送风”等）(v1.9.38)
        let modeKeywords = [
            "制冷", "冷气", "冷风", "开冷", "制热", "暖气", "暖风", "开暖", "加热",
            "送风", "吹风", "通风", "自然风", "除湿", "抽湿", "干燥", "自动", "智能"
        ]
        if modeKeywords.contains(where: { text.contains($0) }) {
            return false
        }
        // 排除风速调节命令（如“开大风”、“开微风”、“开小风”、“开强劲风”、“开静音”、“自动风”）(v1.9.38)
        let windKeywords = [
            "自动风", "风速", "大风", "风大", "强劲", "高风", "微风", "小风", "风小", "静音", "柔风", "低风", "中风"
        ]
        if windKeywords.contains(where: { text.contains($0) }) {
            return false
        }
        // 排除情景模式命令（如“开睡眠情景”、“开离家模式”）
        if text.contains("情景") || (text.contains("模式") && (text.contains("睡眠") || text.contains("离家") || text.contains("回家"))) {
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
        guard !containsNegativeAction(text) else { return nil }
        if text.contains("不要") || text.contains("别") || text.contains("不用") || text.contains("暂不") {
            return nil
        }
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

    /// 运行模式 + 设定温度复合口令解析（如“制冷26度”、“开暖气22度”、“客厅制冷24度”）(v1.9.39)
    private static func parseModeAndTemperature(_ text: String) -> VoiceParseResult? {
        guard !containsNegativeAction(text) else { return nil }
        if text.contains("不要") || text.contains("别") || text.contains("不用") || text.contains("暂不") {
            return nil
        }
        // 若为全屋作用域，由 parseAllPreset 优先分发处理
        guard !isAllDeviceScope(text) else { return nil }

        // 识别模式
        let detectedMode: String? = {
            if text.contains("制冷") || text.contains("冷气") || text.contains("冷风") || text.contains("开冷") { return "制冷" }
            if text.contains("制热") || text.contains("暖气") || text.contains("暖风") || text.contains("开暖") || text.contains("加热") { return "制热" }
            if text.contains("送风") || text.contains("吹风") || text.contains("通风") || text.contains("自然风") { return "送风" }
            if text.contains("除湿") || text.contains("抽湿") || text.contains("干燥") { return "除湿" }
            if (text.contains("自动") || text.contains("智能")) && !text.contains("自动风") && !text.contains("风速") { return "自动" }
            return nil
        }()

        guard let mode = detectedMode else { return nil }

        // 必须同时包含有效目标温度区间（16~30°C），否则放行至后续纯模式或纯风速解析流程
        guard let temp = extractTemperatureValue(from: text), temp >= 16.0 && temp <= 30.0 else {
            return nil
        }

        let tempStr = formatTemp(temp)
        let display: String
        if mode == "制热" {
            display = "舒适制热 \(tempStr)°C"
        } else if mode == "制冷" {
            display = "清爽制冷 \(tempStr)°C"
        } else {
            display = "\(mode)模式 \(tempStr)°C"
        }

        return VoiceParseResult(command: .setModeAndTemperature(mode: mode, temperature: temp), displayText: display)
    }

    private static func parseAbsoluteTemperature(_ text: String) -> VoiceParseResult? {
        guard !containsNegativeAction(text) else { return nil }
        if text.contains("不要") || text.contains("别") || text.contains("不用") || text.contains("暂不") {
            return nil
        }
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
        guard !containsNegativeAction(text) else { return nil }
        if text.contains("不要") || text.contains("别") || text.contains("不用") || text.contains("暂不") {
            return nil
        }
        let isAll = isAllDeviceScope(text)
        let matched: (speed: String, desc: String)? = {
            // 1. 自动风档位 (v1.9.47 支持 4档/四档/智能风等别名)
            if text.contains("自动风") || text.contains("风速自动") || text.contains("自动风速") ||
               text.contains("四档") || text.contains("4档") || text.contains("第4档") || text.contains("第四档") ||
               text.contains("风速4") || text.contains("风速四") || text.contains("智能风") {
                return ("自动", "自动风速")
            }
            // 2. 强劲 / 高风 / 3档 / 开大风 (v1.9.47 覆盖动词间隔与档位口语，如“把风开大/风调大点/三档风”)
            if text.contains("大风") || text.contains("风大") || text.contains("强劲") || text.contains("高风") ||
               text.contains("最大风") || text.contains("最大") || text.contains("调大风") || text.contains("风速大") ||
               text.contains("高速风") || text.contains("开到最大") || text.contains("强风") || text.contains("极速") ||
               text.contains("三档") || text.contains("3档") || text.contains("第3档") || text.contains("第三档") ||
               text.contains("风速3") || text.contains("风速三") || text.contains("高档") || text.contains("风速调大") ||
               text.contains("风开大") || text.contains("把风开大") || text.contains("风调大") || text.contains("风大点") ||
               text.contains("调大风速") || text.contains("开大风速") || text.contains("吹大风") {
                return ("强劲", "强劲风速")
            }
            // 3. 微风 / 柔风 / 1档 / 静音 / 开小风 (v1.9.47 覆盖动词间隔与档位口语，如“把风开小/风调小点/一档风”)
            if text.contains("小风") || text.contains("风小") || text.contains("微风") || text.contains("低风") ||
               text.contains("静音") || text.contains("柔风") || text.contains("最小风") || text.contains("调小风") ||
               text.contains("风速小") || text.contains("低速风") || text.contains("开到最小") || text.contains("弱风") ||
               text.contains("一档") || text.contains("1档") || text.contains("第1档") || text.contains("第一档") ||
               text.contains("风速1") || text.contains("风速一") || text.contains("低档") || text.contains("慢速") ||
               text.contains("风速调小") || text.contains("风开小") || text.contains("把风开小") || text.contains("风调小") ||
               text.contains("风小点") || text.contains("调小风速") || text.contains("开小风速") || text.contains("吹微风") ||
               text.contains("吹小风") {
                return ("微风", "微风模式")
            }
            // 4. 中风 / 适中 / 2档 (v1.9.47 支持 2档/二档/两档/中档等别名)
            if text.contains("中风") || text.contains("适中") || text.contains("风速中") || text.contains("中速风") ||
               text.contains("二档") || text.contains("2档") || text.contains("两档") || text.contains("第2档") ||
               text.contains("第二档") || text.contains("风速2") || text.contains("风速二") || text.contains("中档") ||
               text.contains("中速") || text.contains("标准风") || text.contains("吹中风") {
                return ("中风", "中档风速")
            }
            return nil
        }()

        guard let match = matched else { return nil }

        if isAll {
            return VoiceParseResult(
                command: .setWindSpeedAll(match.speed),
                displayText: "全屋切换至\(match.desc)"
            )
        } else {
            return VoiceParseResult(
                command: .setWindSpeed(match.speed),
                displayText: "切换至\(match.desc)"
            )
        }
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

    /// 将常见的中文数字表达替换为阿拉伯数字 (v1.9.42 升级为 1~99 结构化复合数字解析，v1.9.43 解决“两个半小时/三个半小时/两小时半”缩水缺陷)
    private static func convertChineseNumbers(in input: String) -> String {
        var str = input

        let digitMap: [Character: Int] = [
            "零": 0, "一": 1, "二": 2, "两": 2, "三": 3,
            "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]

        // 复合半小时与半钟头结构（如：两个半小时 -> 2.5小时，三个半小时 -> 3.5小时，两小时半 -> 2.5小时，一个半小时 -> 1.5小时，两个半钟头 -> 2.5小时）
        // 彻底根除“两个半小时后关机”被“半小时”粗暴替换为“30分钟”导致严重缩水120分钟的重大缺陷 (v1.9.43, v1.9.44 覆盖“两个半钟头/两钟头半”)
        let halfHourPattern = #"([一二两三四五六七八九]|\d+)(?:个半小时|个钟头半|小时半|个小时半|个半钟头|钟头半)"#
        if let regex = try? NSRegularExpression(pattern: halfHourPattern) {
            let ns = str as NSString
            let matches = regex.matches(in: str, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let digitStr = ns.substring(with: m.range(at: 1))
                let digitVal: Int = {
                    if let d = Int(digitStr) { return d }
                    return digitMap[digitStr.first ?? " "] ?? 1
                }()
                let range = Range(m.range, in: str)!
                str.replaceSubrange(range, with: "\(digitVal).5小时")
            }
        }

        // 单独的固定搭配与刻度归一 (v1.9.44 解决“一刻钟后关机”与“十点一刻关机”缺陷, v1.9.46 根除“半个小时”、“二刻钟”、“两刻/二刻后”、“十点两刻/十点二刻”等映射缺失与误判为 10:02 的严重缺陷)
        str = str.replacingOccurrences(of: "一个半小时", with: "1.5小时")
        str = str.replacingOccurrences(of: "1个半小时", with: "1.5小时")
        str = str.replacingOccurrences(of: "一个半钟头", with: "1.5小时")
        str = str.replacingOccurrences(of: "1个半钟头", with: "1.5小时")
        str = str.replacingOccurrences(of: "半个小时", with: "30分钟")
        str = str.replacingOccurrences(of: "半个钟头", with: "30分钟")
        str = str.replacingOccurrences(of: "半钟头", with: "30分钟")
        str = str.replacingOccurrences(of: "半小时", with: "30分钟")
        str = str.replacingOccurrences(of: "点半", with: "点30分")
        str = str.replacingOccurrences(of: "时半", with: "点30分")
        str = str.replacingOccurrences(of: "一刻钟", with: "15分钟")
        str = str.replacingOccurrences(of: "1刻钟", with: "15分钟")
        str = str.replacingOccurrences(of: "两刻钟", with: "30分钟")
        str = str.replacingOccurrences(of: "2刻钟", with: "30分钟")
        str = str.replacingOccurrences(of: "二刻钟", with: "30分钟")
        str = str.replacingOccurrences(of: "三刻钟", with: "45分钟")
        str = str.replacingOccurrences(of: "3刻钟", with: "45分钟")
        str = str.replacingOccurrences(of: "一刻后", with: "15分钟后")
        str = str.replacingOccurrences(of: "1刻后", with: "15分钟后")
        str = str.replacingOccurrences(of: "两刻后", with: "30分钟后")
        str = str.replacingOccurrences(of: "2刻后", with: "30分钟后")
        str = str.replacingOccurrences(of: "二刻后", with: "30分钟后")
        str = str.replacingOccurrences(of: "三刻后", with: "45分钟后")
        str = str.replacingOccurrences(of: "3刻后", with: "45分钟后")
        str = str.replacingOccurrences(of: "点一刻", with: "点15分")
        str = str.replacingOccurrences(of: "时一刻", with: "点15分")
        str = str.replacingOccurrences(of: "点1刻", with: "点15分")
        str = str.replacingOccurrences(of: "时1刻", with: "点15分")
        str = str.replacingOccurrences(of: "点两刻", with: "点30分")
        str = str.replacingOccurrences(of: "时两刻", with: "点30分")
        str = str.replacingOccurrences(of: "点二刻", with: "点30分")
        str = str.replacingOccurrences(of: "时二刻", with: "点30分")
        str = str.replacingOccurrences(of: "点2刻", with: "点30分")
        str = str.replacingOccurrences(of: "时2刻", with: "点30分")
        str = str.replacingOccurrences(of: "点三刻", with: "点45分")
        str = str.replacingOccurrences(of: "时三刻", with: "点45分")
        str = str.replacingOccurrences(of: "点3刻", with: "点45分")
        str = str.replacingOccurrences(of: "时3刻", with: "点45分")

        // “点过”与“差刻”固定搭配 (v1.9.48)
        str = str.replacingOccurrences(of: "点过一刻", with: "点15分")
        str = str.replacingOccurrences(of: "时过一刻", with: "点15分")
        str = str.replacingOccurrences(of: "点过1刻", with: "点15分")
        str = str.replacingOccurrences(of: "时过1刻", with: "点15分")
        str = str.replacingOccurrences(of: "点过两刻", with: "点30分")
        str = str.replacingOccurrences(of: "时过两刻", with: "点30分")
        str = str.replacingOccurrences(of: "点过二刻", with: "点30分")
        str = str.replacingOccurrences(of: "时过二刻", with: "点30分")
        str = str.replacingOccurrences(of: "点过2刻", with: "点30分")
        str = str.replacingOccurrences(of: "时过2刻", with: "点30分")
        str = str.replacingOccurrences(of: "点过半", with: "点30分")
        str = str.replacingOccurrences(of: "时过半", with: "点30分")
        str = str.replacingOccurrences(of: "点过三刻", with: "点45分")
        str = str.replacingOccurrences(of: "时过三刻", with: "点45分")
        str = str.replacingOccurrences(of: "点过3刻", with: "点45分")
        str = str.replacingOccurrences(of: "时过3刻", with: "点45分")

        str = str.replacingOccurrences(of: "差一刻", with: "差15分")
        str = str.replacingOccurrences(of: "差1刻", with: "差15分")
        str = str.replacingOccurrences(of: "差两刻", with: "差30分")
        str = str.replacingOccurrences(of: "差2刻", with: "差30分")
        str = str.replacingOccurrences(of: "差二刻", with: "差30分")
        str = str.replacingOccurrences(of: "差三刻", with: "差45分")
        str = str.replacingOccurrences(of: "差3刻", with: "差45分")
        str = str.replacingOccurrences(of: "一百", with: "100")

        // 温度与时间小数转换：仅匹配紧跟“度/°/小时/个钟头”的小数点五（如“二十六点五度” -> 26.5度，“1点5小时” -> 1.5小时）
        // 彻底杜绝无上下文粗暴替换“点五”导致“十点五分/八点五分/十点五十分”被破坏为“10.5分”进而被误判为5分钟倒计时的灾难性缺陷 (v1.9.47)
        let decimalPointPattern = #"([一二两三四五六七八九\d]+)点五(?=度|°|个?小时|个钟头)"#
        if let regex = try? NSRegularExpression(pattern: decimalPointPattern) {
            let ns = str as NSString
            let matches = regex.matches(in: str, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let prefix = ns.substring(with: m.range(at: 1))
                let range = Range(m.range, in: str)!
                str.replaceSubrange(range, with: "\(prefix).5")
            }
        }
        let compoundPattern = #"([一二两三四五六七八九])?十([一二三四五六七八九])?"#
        if let regex = try? NSRegularExpression(pattern: compoundPattern) {
            let ns = str as NSString
            let matches = regex.matches(in: str, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let tensStr = m.range(at: 1).location != NSNotFound ? ns.substring(with: m.range(at: 1)) : nil
                let onesStr = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)) : nil
                let tens = tensStr.flatMap { digitMap[$0.first!] } ?? 1
                let ones = onesStr.flatMap { digitMap[$0.first!] } ?? 0
                let value = tens * 10 + ones
                let range = Range(m.range, in: str)!
                str.replaceSubrange(range, with: "\(value)")
            }
        }

        for (cn, val) in digitMap {
            str = str.replacingOccurrences(of: String(cn), with: "\(val)")
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
