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
    /// 循环周期定时开关机（hour: 0~23, minute: 0~59, power: true=开机, false=关机, repeatWeekdays: [Int], repeatLabel: String）(v1.9.56)
    case scheduleRepeatPower(hour: Int, minute: Int, power: Bool, repeatWeekdays: [Int], repeatLabel: String)
    /// 取消定向/当前设备定时与倒计时
    case cancelSchedules
    /// 取消全屋所有设备的定时与倒计时任务 (v1.9.36)
    case cancelSchedulesAll
    /// 临时暂停定向/当前设备定时与倒计时 (v1.9.60)
    case pauseSchedules
    /// 临时暂停全屋所有设备的定时与倒计时任务 (v1.9.60)
    case pauseSchedulesAll
    /// 恢复生效定向/当前设备定时与倒计时 (v1.9.60)
    case resumeSchedules
    /// 恢复生效全屋所有设备的定时与倒计时任务 (v1.9.60)
    case resumeSchedulesAll
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

        // 1. 查询类（支持全屋空调状态汇总、温湿度感知与启闭状态查询） (v1.9.38, v1.9.51)
        if cleaned.contains("多少度") || cleaned.contains("当前温度") || cleaned.contains("室内温度") ||
           cleaned.contains("现在温度") || cleaned.contains("查温度") || cleaned.contains("室温") ||
           cleaned.contains("查状态") || cleaned.contains("查询状态") || cleaned.contains("空调状态") || cleaned.contains("运行状态") ||
           cleaned.contains("空调开着吗") || cleaned.contains("空调开了吗") || cleaned.contains("空调关了吗") ||
           cleaned.contains("空调开着没") || cleaned.contains("空调开了没") || cleaned.contains("空调关了没") ||
           cleaned.contains("开着没") || cleaned.contains("开着吗") || cleaned.contains("关着吗") || cleaned.contains("关了没") ||
           cleaned.contains("查湿度") || cleaned.contains("查询湿度") || cleaned.contains("室内湿度") ||
           cleaned.contains("当前湿度") || cleaned.contains("现在湿度") || cleaned.contains("湿度多少") {
            if isAllDeviceScope(cleaned) {
                return VoiceParseResult(command: .queryStatusAll, displayText: "查询全屋空调状态")
            } else {
                return VoiceParseResult(command: .queryStatus, displayText: "查询室内温度与工况")
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

        // 2.1 定时与倒计时临时暂停 (v1.9.60)
        if isPauseSchedule(cleaned) {
            if isAllDeviceScope(cleaned) {
                return VoiceParseResult(command: .pauseSchedulesAll, displayText: "临时暂停全屋所有定时任务")
            } else {
                return VoiceParseResult(command: .pauseSchedules, displayText: "临时暂停定时任务")
            }
        }

        // 2.2 定时与倒计时恢复生效 (v1.9.60)
        if isResumeSchedule(cleaned) {
            if isAllDeviceScope(cleaned) {
                return VoiceParseResult(command: .resumeSchedulesAll, displayText: "恢复全屋所有定时任务")
            } else {
                return VoiceParseResult(command: .resumeSchedules, displayText: "恢复定时任务生效")
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
            "已洗", "刚洗", "洗过", "洗了", "换过", "换了", "已换", "换好了", "换完了", "已更换", "更换完成", "换新", "换了新", "装了新", "已装好", "恢复100"
        ]

        if resetKeywords.contains(where: { text.contains($0) }) {
            return true
        }

        // 结构化时态匹配：包含“洗/换/擦”且包含“干净了/好了/完了/过了/搞定/完成”
        if (text.contains("洗") || text.contains("换") || text.contains("擦")) &&
           (text.contains("干净了") || text.contains("好了") || text.contains("完了") || text.contains("过了") || text.contains("搞定") || text.contains("完成")) {
            return true
        }

        return false
    }

    private static func isCancelSchedule(_ text: String) -> Bool {
        // 若包含明确否定“取消/清除/删除/撤销/清空”的动作（如“千万别取消定时”、“不要取消定时”、“别给我取消定时任务”、“千万不要删除全屋定时”、“千万别清空定时”），必须严格拦截，杜绝误取消 (v1.9.61, v1.9.63 补齐清空动作否定防线)
        if containsNegativeForAction(text: text, actionPattern: #"(?:取消|清除|删除|撤销|清空)"#) {
            return false
        }
        // 若包含明确动作谓词且为否定动作（如“别定时开机”、“不要定时关机”、“千万别定时开”），属于动作否定拦截，严禁误判为取消定时 (v1.9.55)
        if (text.contains("开") || text.contains("关") || text.contains("停") || text.contains("启动")) &&
           (text.contains("别") || text.contains("不要") || text.contains("不用") || text.contains("千万") || containsNegativeAction(text)) &&
           !text.contains("取消") && !text.contains("清除") && !text.contains("删除") && !text.contains("撤销") && !text.contains("清空") {
            return false
        }
        let cancelKeywords = [
            "取消定时", "取消倒计时", "关闭定时", "清除定时", "删除定时", "取消预约", "别定了", "别定时", "不要定时", "不用定时",
            "清空定时", "清空所有定时", "清空全部定时", "清空倒计时", "清空所有倒计时",
            "取消所有任务", "取消全部任务", "清空所有任务", "清空全部任务", "取消任务", "清空任务",
            "撤销定时", "撤销所有定时", "撤销全部定时", "撤销倒计时", "撤销所有倒计时",
            "撤销所有任务", "撤销全部任务", "撤销任务", "清除所有任务", "删除所有任务"
        ]
        if cancelKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 自然语言容错：包含“取消/关闭/清除/删除/撤销/清空”且包含“定时/倒计时/预约/计划/调度/任务”（如“取消所有定时任务”、“关闭全屋倒计时”、“清空所有计划”、“清空所有任务”）
        if (text.contains("取消") || text.contains("关闭") || text.contains("清除") || text.contains("删除") || text.contains("撤销") || text.contains("清空")) &&
           (text.contains("定时") || text.contains("倒计时") || text.contains("预约") || text.contains("计划") || text.contains("调度") || text.contains("任务")) {
            return true
        }
        return false
    }

    private static func isPauseSchedule(_ text: String) -> Bool {
        // 若包含结构化否定“暂停/挂起/暂缓”动作（如“别暂停定时”、“千万别暂停”、“别给我暂停定时”、“先别急着暂停定时”），严格拦截防误触 (v1.9.60, v1.9.61 消除字面量紧邻缺陷)
        if containsNegativeForAction(text: text, actionPattern: #"(?:暂停|挂起|暂缓)"#) {
            return false
        }
        let pauseKeywords = [
            "暂停定时", "暂停倒计时", "暂停调度", "暂停计划", "挂起定时", "暂挂定时",
            "暂停所有任务", "暂停全部任务", "暂停任务", "挂起所有任务", "暂缓所有任务"
        ]
        if pauseKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 自然语言容错：包含“暂停/暂缓/挂起”且包含“定时/倒计时/计划/调度/任务”（如“暂停所有定时任务”、“暂停全屋定时”、“暂停所有任务”）
        if (text.contains("暂停") || text.contains("暂缓") || text.contains("挂起")) &&
           (text.contains("定时") || text.contains("倒计时") || text.contains("计划") || text.contains("调度") || text.contains("任务")) {
            return true
        }
        return false
    }

    private static func isResumeSchedule(_ text: String) -> Bool {
        // 若包含结构化否定“恢复/继续/启用”动作（如“别恢复定时”、“不要恢复”、“千万别恢复全屋定时”、“不要给我恢复定时”），严格拦截 (v1.9.60, v1.9.61 消除字面量紧邻缺陷)
        if containsNegativeForAction(text: text, actionPattern: #"(?:恢复|继续|重新启用|启用)"#) {
            return false
        }
        let resumeKeywords = [
            "恢复定时", "恢复倒计时", "恢复调度", "恢复计划", "继续定时", "重新启用定时", "启用定时任务",
            "恢复所有任务", "恢复全部任务", "恢复任务", "继续所有任务", "重新启用所有任务"
        ]
        if resumeKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 自然语言容错：包含“恢复/继续/重新启用/重新激活”且包含“定时/倒计时/计划/调度/任务”（如“恢复全屋定时任务”、“继续定时”、“恢复所有任务”）
        if (text.contains("恢复") || text.contains("继续") || text.contains("重新启用") || text.contains("重新激活")) &&
           (text.contains("定时") || text.contains("倒计时") || text.contains("计划") || text.contains("调度") || text.contains("任务")) {
            return true
        }
        return false
    }

    private static func parseScheduleOrCountdown(_ text: String) -> VoiceParseResult? {
        guard !containsNegativeAction(text) else { return nil }
        let isAll = isAllDeviceScope(text)

        // 1. 优先判断指定具体钟点定时（如“晚上10点关机”、“明早7点开空调”、“差半小时八点关机”、“十点差五分关机”、“每天晚上10点关机”、“工作日早上7点开空调”）
        // 必须包含关机/开机/停意图或“启动/运转”或“定时/预约”，避免“大风一点”、“调高一点”等“一点”被误判为 1 点钟 (v1.9.48, v1.9.50, v1.9.78)
        if (text.contains("关") || text.contains("开") || text.contains("停") || text.contains("启动") || text.contains("运转") || text.contains("定时") || text.contains("预约")),
           let time = parseScheduleTime(from: text) {
            let isPowerOn = (text.contains("开") || text.contains("启动") || text.contains("运转")) && !text.contains("关") && !text.contains("停")
            let actionStr = isPowerOn ? "开机" : "关机"
            let timeStr = String(format: "%02d:%02d", time.hour, time.minute)

            // 循环周期判定 (v1.9.56 支持每天/工作日/周末/按星期重复定时, v1.9.57 补齐单星期与扩展周期重复定时, v1.9.58 补齐礼拜周期与多日复合星期一三五/二四六, v1.9.59 补齐周一至周三/周二至周五/周五至周日复合星期, v1.9.61 扩展复合跨天周期, v1.9.62 统一收敛公共解析引擎并补齐周一至周日全周期与短周期复合范围)
            let repeatInfo = parseRepeatWeekdays(text)

            if let rep = repeatInfo {
                let display = isAll ? "定时全屋在 \(rep.label) \(timeStr) \(actionStr)" : "定时在 \(rep.label) \(timeStr) \(actionStr)"
                return VoiceParseResult(
                    command: .scheduleRepeatPower(hour: time.hour, minute: time.minute, power: isPowerOn, repeatWeekdays: rep.weekdays, repeatLabel: rep.label),
                    displayText: display
                )
            }

            let dayDesc: String = {
                if text.contains("大后天") || text.contains("大后日") || text.contains("大后儿") || text.contains("大后儿个") {
                    return "大后天 "
                } else if text.contains("后天") || text.contains("后日") || text.contains("后儿") || text.contains("后儿个") {
                    return "后天 "
                } else if text.contains("明天") || text.contains("明早") || text.contains("明晚") || text.contains("明午") || text.contains("明夜") || text.contains("明晨") || text.contains("次日") || text.contains("次晨") || text.contains("明儿") || text.contains("隔日") || text.contains("翌日") || text.contains("翌晨") || text.contains("明日") || text.contains("隔天") || text.contains("明儿个") {
                    return "明天 "
                } else if text.contains("今天") || text.contains("今日") || text.contains("今晚") || text.contains("今早") || text.contains("今夜") || text.contains("今晨") || text.contains("今儿") || text.contains("今儿个") {
                    return "今天 "
                }
                return ""
            }()
            let display = isAll ? "定时全屋在 \(dayDesc)\(timeStr) \(actionStr)" : "定时在 \(dayDesc)\(timeStr) \(actionStr)"
            return VoiceParseResult(
                command: .schedulePower(hour: time.hour, minute: time.minute, power: isPowerOn),
                displayText: display
            )
        }

        // 2. 判断倒计时（如包含“后”、“倒计时”、“定时关/开”、“定时X分钟/小时”或前置“过/等/延迟/稍后”及直接持续时间“30分钟关机/半小时关机”） (v1.9.50, v1.9.78)
        let isCountdownTrigger = (text.contains("后") || text.contains("倒计时") ||
                                  text.contains("定时关") || text.contains("定时开") || text.contains("定时启动") ||
                                  text.contains("倒计时启动") || text.contains("预约启动") ||
                                  (text.contains("定时") && (text.contains("分") || text.contains("小时") || text.contains("钟头"))) ||
                                  text.contains("过") || text.contains("等") || text.contains("延迟") || text.contains("延后") || text.contains("稍后"))
        let hasDuration = (text.contains("分") || text.contains("小时") || text.contains("钟头") || text.contains("半") || text.contains("刻"))

        if isCountdownTrigger || hasDuration {
            if let minutes = parseCountdownMinutes(from: text), minutes > 0 {
                if text.contains("关") || text.contains("开") || text.contains("停") || text.contains("启动") || text.contains("运转") || text.contains("定时") || text.contains("倒计时") {
                    let isPowerOn = (text.contains("开") || text.contains("启动") || text.contains("运转")) && !text.contains("关") && !text.contains("停")
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
        }

        return nil
    }

    private static let repeatWeekdayRangeRegex: NSRegularExpression? = {
        // 支持全语素“周一到周五/周五至周日”、省略语素“周一至五/周一到五/周五至日/周六到天/周六至二/周日至五”以及破折号与波浪号“-”、“~”和阿拉伯数字 (v1.9.65, v1.9.66)
        let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配双连续区间复合口语（如“周一至周三以及周五至周日”、“周一到周三和周五到天”、“周二至周四和周六至周日”） (v1.9.72)
    private static let rangeWithRangeRegex: NSRegularExpression? = {
        let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配连续区间在前、核心关键词在后口语（如“周一至周五和周末”、“周一到周四以及单休”、“周一至五加双休”、“周一到周三加周末三天”） (v1.9.72)
    private static let rangeWithKeywordRegex: NSRegularExpression? = {
        let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(工作日|平时|周末|双休|单休|周末三天)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配核心关键词在前、连续区间在后口语（如“周末和周一至周三”、“工作日加周六至周日”、“单休加周一至周三”） (v1.9.72)
    private static let keywordWithRangeRegex: NSRegularExpression? = {
        let pattern = #"(工作日|平时|周末|双休|单休|周末三天)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7]))"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配连续区间附加离散星期复合口语（如“周一至周三以及周五”、“周一到周四还有周六”、“周一至五和周日”、“周一至周三和周五周六”） (v1.9.67, v1.9.70 增加每天负向断言防误判为星期天, v1.9.72 升级支持多离散星期)
    private static let rangeWithMultiDaysRegex: NSRegularExpression? = {
        let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配离散星期在前、连续区间在后复合口语（如“周五和周一至周三”、“周日以及周一至周四”、“周五周日和周一至周三”、“周五、周六和周一至周三”、“周一和周五至周日”） (v1.9.73)
    private static let multiDaysWithRangeRegex: NSRegularExpression? = {
        let pattern = #"((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配双连续区间附加多个离散星期复合口语（如“周一至周三、周五至周六和周日”、“周一到周二和周四到周五以及周日”） (v1.9.73)
    private static let dualRangeWithMultiDaysRegex: NSRegularExpression? = {
        let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配连续区间在先、多个离散星期居中、连续区间在后的夹心复合口语（如“周一至周三、周五以及周六至周日”、“周一到周二、周四和周六到周日”、“周一至周三和周五加周六至周日”） (v1.9.74)
    private static let rangeWithMultiDaysAndRangeRegex: NSRegularExpression? = {
        let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配离散星期在先、连续区间居中、离散星期在后的反向夹心复合口语（如“周一、周三至周五以及周日”、“周日和周二至周四以及周六”、“周二和周四到周五加周日”） (v1.9.75)
    private static let multiDaysWithRangeAndMultiDaysRegex: NSRegularExpression? = {
        let pattern = #"((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配三连续区间大一统复合口语（如“周一至周二、周四至周五和周六至周日”、“周一到周二、周三到周四以及周五到周六”） (v1.9.74)
    private static let triRangeRepeatRegex: NSRegularExpression? = {
        let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配三连续区间附加多个离散星期复合口语（如“周一至周二、周四至周五、周六至周日和周三”） (v1.9.75)
    private static let triRangeWithMultiDaysRegex: NSRegularExpression? = {
        let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配多个离散星期在先、三连续区间在后复合口语（如“周日和周一至周二、周四至周五以及周六至周日”） (v1.9.75)
    private static let multiDaysWithTriRangeRegex: NSRegularExpression? = {
        let pattern = #"((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配多个离散星期在前、双连续区间在后复合口语（如“周日和周一至周三以及周五至周六”、“周日加周一至周二加周四至周五”） (v1.9.73)
    private static let multiDaysWithDualRangeRegex: NSRegularExpression? = {
        let pattern = #"((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配多个离散星期在前、核心关键词在后口语（如“周六周日和工作日”、“周二周四和周末”、“周五和周日加工作日”） (v1.9.73)
    private static let multiDaysWithKeywordRegex: NSRegularExpression? = {
        let pattern = #"((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(工作日|平时|周末|双休|单休|周末三天)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配核心关键词在前、多个离散星期在后口语（如“工作日和周六周日”、“周末和周二周四”、“周末加周三、周五”） (v1.9.73)
    private static let keywordWithMultiDaysRegex: NSRegularExpression? = {
        let pattern = #"(工作日|平时|周末|双休|单休|周末三天)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 兼容单个离散附加星期正则 (v1.9.67, v1.9.70)
    private static let rangeWithExtraDaysRegex: NSRegularExpression? = {
        let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7]))"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配核心关键词复合星期口语（如“工作日和周六”、“工作日及周日”、“工作日还有周六”、“工作日加周日”、“工作日加周末”、“周末和周一”、“周末以及周五”、“单休和周日”） (v1.9.67, v1.9.70 增加每天负向断言防误判为星期天, v1.9.71 纳管单休与周末三天)
    private static let keywordWithExtraDayRegex: NSRegularExpression? = {
        let pattern = #"(工作日|平时|周末|双休|单休|周末三天)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7]|工作日|平时|周末|双休|单休|周末三天))"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配离散星期在前、核心关键词在后口语（如“周六和工作日”、“周一和周末”、“周日和单休”） (v1.9.67, v1.9.71 纳管单休与周末三天)
    private static let extraDayWithKeywordRegex: NSRegularExpression? = {
        let pattern = #"(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7]))\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(工作日|平时|周末|双休|单休|周末三天)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配离散多星期组合口语模式（如“周一和周三”、“周二、周四与周六”、“周一及周五”、“周一周三和周五周日”、“周一周三周五”、“周二周四周六”、“周一周二和周四周五”、“周一或者周四”、“周一还有周五”、“周一加周三”） (v1.9.66, v1.9.67, v1.9.70 增加每天负向断言防误判为星期天, v1.9.74 升级支持紧凑无分隔离散星期)
    private static let discreteWeekdaysRegex: NSRegularExpression? = {
        let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])(?:(?:\s*(?:[、,，和与及跟以及还有或者或加/／]\s*)+(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])))|(?:\s*(?:[、,，和与及跟以及还有或者或加/／\s]*)(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7]))))+"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 匹配排除型否定星期口语模式（如“除了周末每天晚上10点关机”、“除周末外每天早8点开机”、“除了工作日每天晚上11点关空调”、“除了周日每天早8点开机”、“除周一外每天晚10点关机”、“工作日除了周三早8点开机”、“周一至周五除周二外晚10点关空调”） (v1.9.68, v1.9.69 补全限定基准集约束)
    private static let exclusionRepeatRegex: NSRegularExpression? = {
        let pattern = #"(?:除了|除)\s*([^，,。！？\s]+?)\s*(?:(?:之|以)?外)?(?=[，,。！？\s]|工作日|平时|周末|双休|单休|一三五|二四六|每天|天天|每日|每晚|每早|每晨|每夜|日日|\d|早|晚|夜|中|上|下|凌晨|午|点|时|:|$|开|关|停)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 从排除文本中提取被排除的星期集合 (v1.9.68, v1.9.71 纳管周末三天与单休排除)
    private static func extractExcludedDays(from target: String) -> Set<Int>? {
        var excluded = Set<Int>()
        var remainingTarget = target
        if remainingTarget.contains("工作日") || remainingTarget.contains("平时") {
            excluded.formUnion([2, 3, 4, 5, 6])
            remainingTarget = remainingTarget.replacingOccurrences(of: "工作日", with: "").replacingOccurrences(of: "平时", with: "")
        }
        if remainingTarget.contains("周末三天") {
            excluded.formUnion([1, 6, 7])
            remainingTarget = remainingTarget.replacingOccurrences(of: "周末三天", with: "")
        }
        if remainingTarget.contains("周末") || remainingTarget.contains("双休") {
            excluded.formUnion([1, 7])
            remainingTarget = remainingTarget.replacingOccurrences(of: "周末", with: "").replacingOccurrences(of: "双休", with: "")
        }
        if remainingTarget.contains("单休") {
            excluded.formUnion([2, 3, 4, 5, 6, 7])
            remainingTarget = remainingTarget.replacingOccurrences(of: "单休", with: "")
        }
        // 尝试解析连续区间，如“周一至周五”、“周一到周四”（支持多个连续区间遍历提取）(v1.9.72)
        if let regex = repeatWeekdayRangeRegex {
            let ns = remainingTarget as NSString
            let matches = regex.matches(in: remainingTarget, options: [], range: NSRange(location: 0, length: ns.length))
            for match in matches {
                if match.numberOfRanges >= 3 {
                    let sStr = ns.substring(with: match.range(at: 1))
                    let eStr = ns.substring(with: match.range(at: 2))
                    if let sCh = sStr.first, let sWd = chineseDayCharToWeekday(sCh),
                       let eCh = eStr.first, let eWd = chineseDayCharToWeekday(eCh) {
                        excluded.formUnion(generateWeeklyRange(start: sWd, end: eWd))
                    }
                }
            }
            if !matches.isEmpty {
                remainingTarget = regex.stringByReplacingMatches(in: remainingTarget, options: [], range: NSRange(location: 0, length: ns.length), withTemplate: " ")
            }
        }
        // 尝试提取离散星期
        let singleRegex = try? NSRegularExpression(pattern: #"(?:周|星期|礼拜)?([一二三四五六日天1-7])"#)
        let ns = remainingTarget as NSString
        if let matches = singleRegex?.matches(in: remainingTarget, options: [], range: NSRange(location: 0, length: ns.length)) {
            for m in matches {
                if m.numberOfRanges >= 2 {
                    let chStr = ns.substring(with: m.range(at: 1))
                    if let ch = chStr.first, let wd = chineseDayCharToWeekday(ch) {
                        excluded.insert(wd)
                    }
                }
            }
        }
        return excluded.isEmpty ? nil : excluded
    }

    /// 从除外子句之外的文本中提取基准星期集合（Base Scope），若未指定则默认全周 7 天 (v1.9.69, v1.9.70 大一统基准提取引擎)
    private static func extractBaseScopeWeekdays(from text: String) -> Set<Int>? {
        if let base = parseBaseRepeatWeekdays(text) {
            if base.weekdays.isEmpty {
                return Set([1, 2, 3, 4, 5, 6, 7]) // "每天" 表示全周 7 天
            } else {
                return Set(base.weekdays)
            }
        }
        return nil
    }

    /// 解析排除型周期语义并计算指定基准集合或全周的补集 (v1.9.68, v1.9.69 闭环限定基准范围约束)
    private static func parseExclusionRepeatWeekdays(_ text: String) -> (weekdays: [Int], label: String)? {
        let ns = text as NSString
        guard let regex = exclusionRepeatRegex,
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        let target = ns.substring(with: match.range(at: 1))
        guard let excluded = extractExcludedDays(from: target) else {
            return nil
        }
        // 剥离排除子句，解析上下文中的限定基准集（如“工作日除了周三”的基准集为“工作日”，“周末除周日外”的基准集为“周末”）
        let remainingText = ns.replacingCharacters(in: match.range, with: " ")
        let baseScope = extractBaseScopeWeekdays(from: remainingText) ?? Set([1, 2, 3, 4, 5, 6, 7])
        let remaining = baseScope.subtracting(excluded)
        guard !remaining.isEmpty && remaining.count < baseScope.count else {
            return nil
        }
        let sorted = Array(remaining).sorted()
        let label = formatWeekdayLabel(from: sorted)
        return (sorted, label)
    }

    private static func chineseDayCharToWeekday(_ ch: Character) -> Int? {
        switch ch {
        case "一", "1": return 2
        case "二", "2": return 3
        case "三", "3": return 4
        case "四", "4": return 5
        case "五", "5": return 6
        case "六", "6": return 7
        case "日", "天", "7", "0": return 1
        default: return nil
        }
    }

    private static func weekdayToWeeklyIndex(_ weekday: Int) -> Int {
        weekday == 1 ? 6 : weekday - 2
    }

    private static func weeklyIndexToWeekday(_ index: Int) -> Int {
        index == 6 ? 1 : index + 2
    }

    private static func generateWeeklyRange(start: Int, end: Int) -> [Int] {
        let startIndex = weekdayToWeeklyIndex(start)
        let endIndex = weekdayToWeeklyIndex(end)
        let dayCount = ((endIndex - startIndex + 7) % 7) + 1
        var result: [Int] = []
        for k in 0..<dayCount {
            let idx = (startIndex + k) % 7
            result.append(weeklyIndexToWeekday(idx))
        }
        return result.sorted()
    }

    /// 统一智能归一化格式化星期列表为自然语言地道标签 (v1.9.61, v1.9.66, v1.9.67)
    public static func formatRepeatWeekdaysLabel(_ repeatWeekdays: [Int], startWd: Int? = nil, endWd: Int? = nil) -> String? {
        guard !repeatWeekdays.isEmpty else { return nil }
        let sorted = repeatWeekdays.sorted()
        if sorted.count == 7 { return "周一至周日" }
        if sorted == [2, 3, 4, 5, 6] { return "工作日" }
        if sorted == [1, 7] { return "周末" }
        if sorted == [1, 6, 7] { return "周五至周日" }
        if sorted == [2, 4, 6] { return "每周一、三、五" }
        if sorted == [3, 5, 7] { return "每周二、四、六" }
        if sorted == [3, 5] { return "每周二、四" }
        if sorted == [3, 7] { return "每周二、六" }
        if sorted == [2, 4] { return "每周一、三" }
        if sorted == [2, 5] { return "每周一、四" }
        if sorted == [2, 6] { return "每周一、五" }
        if sorted == [2, 3, 5, 6, 7] { return "每周一、二、四、五、六" }
        if sorted == [2, 3, 4, 5, 6, 7] { return "周一至周六" }
        if sorted == [1, 2, 3, 4, 5, 6] { return "周日至周五" }

        let dayChars = ["日", "一", "二", "三", "四", "五", "六"] // 1=日, 2=一, ..., 7=六

        // 如果是指定的连续区间
        if let s = startWd, let e = endWd {
            let sName = dayChars[max(0, min(s - 1, 6))]
            let eName = dayChars[max(0, min(e - 1, 6))]
            return "周\(sName)至周\(eName)"
        }

        // 环形连续区间智能探测：测试 7 种可能的起点，检查 sorted 是否恰好构成环形连续区间
        if sorted.count >= 2 {
            for startCandidate in 1...7 {
                let startIndex = weekdayToWeeklyIndex(startCandidate)
                let endIndex = (startIndex + sorted.count - 1) % 7
                let endCandidate = weeklyIndexToWeekday(endIndex)
                if generateWeeklyRange(start: startCandidate, end: endCandidate) == sorted {
                    let sName = dayChars[max(0, min(startCandidate - 1, 6))]
                    let eName = dayChars[max(0, min(endCandidate - 1, 6))]
                    return "周\(sName)至周\(eName)"
                }
            }
        }

        // 单个星期
        if sorted.count == 1, let d = sorted.first {
            let sName = dayChars[max(0, min(d - 1, 6))]
            return "每周\(sName)"
        }

        // 离散多星期：生成“每周一、三”等
        let names = sorted.map { dayChars[max(0, min($0 - 1, 6))] }
        return "每周" + names.joined(separator: "、")
    }

    /// 智能归一化格式化星期列表为自然语言地道标签（非可选重载）
    private static func formatWeekdayLabel(from weekdays: [Int], startWd: Int? = nil, endWd: Int? = nil) -> String {
        formatRepeatWeekdaysLabel(weekdays, startWd: startWd, endWd: endWd) ?? "每天"
    }

    /// 解析文本中的重复周期规则（涵盖周一至周日全周、工作日、周末、单休、每天、单星期及自然语言口语全排列复合离散与连续星期）(v1.9.62 统一公共解析引擎, v1.9.65 升级口语省略语素通用环形范围解析引擎, v1.9.66 升级通用离散与连续全排列混合周期调度引擎, v1.9.67 升级复合连续区间与离散混合大一统引擎, v1.9.70 大一统全基准排除型周期调度引擎与单休制纳管)
    public static func parseRepeatWeekdays(_ text: String) -> (weekdays: [Int], label: String)? {
        // 0. 排除型否定星期周期优先解析（如“除了周末每天晚上10点关机”、“除周末外每天早8点开机”、“除了工作日每天晚上11点关空调”、“除了周日每天早8点开机”、“除周一外每天晚10点关机”） (v1.9.68 杜绝硬编码包含导致反向语义逻辑颠倒缺陷, v1.9.69, v1.9.70 闭环全基准大一统排除引擎)
        if let exclusionResult = parseExclusionRepeatWeekdays(text) {
            return exclusionResult
        }
        return parseBaseRepeatWeekdays(text)
    }

    /// 基础周期规则提取（不含排除子句递归，供周期解析与基准范围提取公共复用） (v1.9.70)
    private static func parseBaseRepeatWeekdays(_ text: String) -> (weekdays: [Int], label: String)? {
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // 0.001 三连续区间附加多个离散星期复合口语（如“周一至周二、周四至周五、周六至周日和周三”） (v1.9.75)
        if let regex = triRangeWithMultiDaysRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 8 {
            let s1 = nsString.substring(with: match.range(at: 1))
            let e1 = nsString.substring(with: match.range(at: 2))
            let s2 = nsString.substring(with: match.range(at: 3))
            let e2 = nsString.substring(with: match.range(at: 4))
            let s3 = nsString.substring(with: match.range(at: 5))
            let e3 = nsString.substring(with: match.range(at: 6))
            let multi = nsString.substring(with: match.range(at: 7))
            if let s1Ch = s1.first, let s1Wd = chineseDayCharToWeekday(s1Ch),
               let e1Ch = e1.first, let e1Wd = chineseDayCharToWeekday(e1Ch),
               let s2Ch = s2.first, let s2Wd = chineseDayCharToWeekday(s2Ch),
               let e2Ch = e2.first, let e2Wd = chineseDayCharToWeekday(e2Ch),
               let s3Ch = s3.first, let s3Wd = chineseDayCharToWeekday(s3Ch),
               let e3Ch = e3.first, let e3Wd = chineseDayCharToWeekday(e3Ch) {
                var days = Set(generateWeeklyRange(start: s1Wd, end: e1Wd))
                days.formUnion(generateWeeklyRange(start: s2Wd, end: e2Wd))
                days.formUnion(generateWeeklyRange(start: s3Wd, end: e3Wd))
                for ch in multi {
                    if let wd = chineseDayCharToWeekday(ch) {
                        days.insert(wd)
                    }
                }
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 0.002 多个离散星期在先、三连续区间在后复合口语（如“周日和周一至周二、周四至周五以及周六至周日”） (v1.9.75)
        if let regex = multiDaysWithTriRangeRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 9 {
            let multi = nsString.substring(with: match.range(at: 1))
            let s1 = nsString.substring(with: match.range(at: 3))
            let e1 = nsString.substring(with: match.range(at: 4))
            let s2 = nsString.substring(with: match.range(at: 5))
            let e2 = nsString.substring(with: match.range(at: 6))
            let s3 = nsString.substring(with: match.range(at: 7))
            let e3 = nsString.substring(with: match.range(at: 8))
            if let s1Ch = s1.first, let s1Wd = chineseDayCharToWeekday(s1Ch),
               let e1Ch = e1.first, let e1Wd = chineseDayCharToWeekday(e1Ch),
               let s2Ch = s2.first, let s2Wd = chineseDayCharToWeekday(s2Ch),
               let e2Ch = e2.first, let e2Wd = chineseDayCharToWeekday(e2Ch),
               let s3Ch = s3.first, let s3Wd = chineseDayCharToWeekday(s3Ch),
               let e3Ch = e3.first, let e3Wd = chineseDayCharToWeekday(e3Ch) {
                var days = Set(generateWeeklyRange(start: s1Wd, end: e1Wd))
                days.formUnion(generateWeeklyRange(start: s2Wd, end: e2Wd))
                days.formUnion(generateWeeklyRange(start: s3Wd, end: e3Wd))
                for ch in multi {
                    if let wd = chineseDayCharToWeekday(ch) {
                        days.insert(wd)
                    }
                }
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 0.0 三连续区间大一统复合口语（如“周一至周二、周四至周五和周六至周日”、“周一到周二、周三到周四以及周五到周六”） (v1.9.74)
        if let regex = triRangeRepeatRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 7 {
            let s1 = nsString.substring(with: match.range(at: 1))
            let e1 = nsString.substring(with: match.range(at: 2))
            let s2 = nsString.substring(with: match.range(at: 3))
            let e2 = nsString.substring(with: match.range(at: 4))
            let s3 = nsString.substring(with: match.range(at: 5))
            let e3 = nsString.substring(with: match.range(at: 6))
            if let s1Ch = s1.first, let s1Wd = chineseDayCharToWeekday(s1Ch),
               let e1Ch = e1.first, let e1Wd = chineseDayCharToWeekday(e1Ch),
               let s2Ch = s2.first, let s2Wd = chineseDayCharToWeekday(s2Ch),
               let e2Ch = e2.first, let e2Wd = chineseDayCharToWeekday(e2Ch),
               let s3Ch = s3.first, let s3Wd = chineseDayCharToWeekday(s3Ch),
               let e3Ch = e3.first, let e3Wd = chineseDayCharToWeekday(e3Ch) {
                var days = Set(generateWeeklyRange(start: s1Wd, end: e1Wd))
                days.formUnion(generateWeeklyRange(start: s2Wd, end: e2Wd))
                days.formUnion(generateWeeklyRange(start: s3Wd, end: e3Wd))
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 0.05 连续区间在先、多个离散星期居中、连续区间在后夹心复合口语（如“周一至周三、周五以及周六至周日”、“周一到周二、周四和周六到周日”） (v1.9.74)
        if let regex = rangeWithMultiDaysAndRangeRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 7 {
            let s1 = nsString.substring(with: match.range(at: 1))
            let e1 = nsString.substring(with: match.range(at: 2))
            let multi = nsString.substring(with: match.range(at: 3))
            let s2 = nsString.substring(with: match.range(at: 5))
            let e2 = nsString.substring(with: match.range(at: 6))
            if let s1Ch = s1.first, let s1Wd = chineseDayCharToWeekday(s1Ch),
               let e1Ch = e1.first, let e1Wd = chineseDayCharToWeekday(e1Ch),
               let s2Ch = s2.first, let s2Wd = chineseDayCharToWeekday(s2Ch),
               let e2Ch = e2.first, let e2Wd = chineseDayCharToWeekday(e2Ch) {
                var days = Set(generateWeeklyRange(start: s1Wd, end: e1Wd))
                days.formUnion(generateWeeklyRange(start: s2Wd, end: e2Wd))
                for ch in multi {
                    if let wd = chineseDayCharToWeekday(ch) {
                        days.insert(wd)
                    }
                }
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 0.06 离散星期在先、连续区间居中、离散星期在后反向夹心复合口语（如“周一、周三至周五以及周日”、“周日和周二至周四以及周六”、“周二和周四到周五加周日”） (v1.9.75)
        if let regex = multiDaysWithRangeAndMultiDaysRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 6 {
            let multi1 = nsString.substring(with: match.range(at: 1))
            let s = nsString.substring(with: match.range(at: 3))
            let e = nsString.substring(with: match.range(at: 4))
            let multi2 = nsString.substring(with: match.range(at: 5))
            if let sCh = s.first, let sWd = chineseDayCharToWeekday(sCh),
               let eCh = e.first, let eWd = chineseDayCharToWeekday(eCh) {
                var days = Set(generateWeeklyRange(start: sWd, end: eWd))
                for ch in multi1 {
                    if let wd = chineseDayCharToWeekday(ch) {
                        days.insert(wd)
                    }
                }
                for ch in multi2 {
                    if let wd = chineseDayCharToWeekday(ch) {
                        days.insert(wd)
                    }
                }
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 0.1 双连续区间附加多个离散星期（如“周一至周三、周五至周六和周日”、“周一到周二和周四到周五以及周日”） (v1.9.73)
        if let regex = dualRangeWithMultiDaysRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 6 {
            let s1 = nsString.substring(with: match.range(at: 1))
            let e1 = nsString.substring(with: match.range(at: 2))
            let s2 = nsString.substring(with: match.range(at: 3))
            let e2 = nsString.substring(with: match.range(at: 4))
            let multi = nsString.substring(with: match.range(at: 5))
            if let s1Ch = s1.first, let s1Wd = chineseDayCharToWeekday(s1Ch),
               let e1Ch = e1.first, let e1Wd = chineseDayCharToWeekday(e1Ch),
               let s2Ch = s2.first, let s2Wd = chineseDayCharToWeekday(s2Ch),
               let e2Ch = e2.first, let e2Wd = chineseDayCharToWeekday(e2Ch) {
                var days = Set(generateWeeklyRange(start: s1Wd, end: e1Wd))
                days.formUnion(generateWeeklyRange(start: s2Wd, end: e2Wd))
                for ch in multi {
                    if let wd = chineseDayCharToWeekday(ch) {
                        days.insert(wd)
                    }
                }
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 0.2 多个离散星期在前、双连续区间在后（如“周日和周一至周三以及周五至周六”、“周日加周一至周二加周四至周五”） (v1.9.73)
        if let regex = multiDaysWithDualRangeRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 7 {
            let multi = nsString.substring(with: match.range(at: 1))
            let s1 = nsString.substring(with: match.range(at: 3))
            let e1 = nsString.substring(with: match.range(at: 4))
            let s2 = nsString.substring(with: match.range(at: 5))
            let e2 = nsString.substring(with: match.range(at: 6))
            if let s1Ch = s1.first, let s1Wd = chineseDayCharToWeekday(s1Ch),
               let e1Ch = e1.first, let e1Wd = chineseDayCharToWeekday(e1Ch),
               let s2Ch = s2.first, let s2Wd = chineseDayCharToWeekday(s2Ch),
               let e2Ch = e2.first, let e2Wd = chineseDayCharToWeekday(e2Ch) {
                var days = Set(generateWeeklyRange(start: s1Wd, end: e1Wd))
                days.formUnion(generateWeeklyRange(start: s2Wd, end: e2Wd))
                for ch in multi {
                    if let wd = chineseDayCharToWeekday(ch) {
                        days.insert(wd)
                    }
                }
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 1. 双连续区间复合语义匹配（如“周一至周三和周五至周日”、“周一到周三以及周五到天”、“周二至周四和周六至周日”）(v1.9.72)
        if let regex = rangeWithRangeRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 5 {
            let s1 = nsString.substring(with: match.range(at: 1))
            let e1 = nsString.substring(with: match.range(at: 2))
            let s2 = nsString.substring(with: match.range(at: 3))
            let e2 = nsString.substring(with: match.range(at: 4))
            if let s1Ch = s1.first, let s1Wd = chineseDayCharToWeekday(s1Ch),
               let e1Ch = e1.first, let e1Wd = chineseDayCharToWeekday(e1Ch),
               let s2Ch = s2.first, let s2Wd = chineseDayCharToWeekday(s2Ch),
               let e2Ch = e2.first, let e2Wd = chineseDayCharToWeekday(e2Ch) {
                var days = Set(generateWeeklyRange(start: s1Wd, end: e1Wd))
                days.formUnion(generateWeeklyRange(start: s2Wd, end: e2Wd))
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 2. 连续区间在前 + 核心关键词在后（如“周一至周五和周末”、“周一到周四加单休”、“周一到周三加周末三天”）(v1.9.72)
        if let regex = rangeWithKeywordRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 4 {
            let sStr = nsString.substring(with: match.range(at: 1))
            let eStr = nsString.substring(with: match.range(at: 2))
            let kw = nsString.substring(with: match.range(at: 3))
            if let sCh = sStr.first, let sWd = chineseDayCharToWeekday(sCh),
               let eCh = eStr.first, let eWd = chineseDayCharToWeekday(eCh) {
                var days = Set(generateWeeklyRange(start: sWd, end: eWd))
                if kw == "工作日" || kw == "平时" {
                    days.formUnion([2, 3, 4, 5, 6])
                } else if kw == "周末" || kw == "双休" {
                    days.formUnion([1, 7])
                } else if kw == "单休" {
                    days.formUnion([2, 3, 4, 5, 6, 7])
                } else if kw == "周末三天" {
                    days.formUnion([1, 6, 7])
                }
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 3. 核心关键词在前 + 连续区间在后（如“周末和周一至周三”、“工作日加周六至周日”、“单休加周一至周三”）(v1.9.72)
        if let regex = keywordWithRangeRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 4 {
            let kw = nsString.substring(with: match.range(at: 1))
            let sStr = nsString.substring(with: match.range(at: 2))
            let eStr = nsString.substring(with: match.range(at: 3))
            if let sCh = sStr.first, let sWd = chineseDayCharToWeekday(sCh),
               let eCh = eStr.first, let eWd = chineseDayCharToWeekday(eCh) {
                var days = Set<Int>()
                if kw == "工作日" || kw == "平时" {
                    days.formUnion([2, 3, 4, 5, 6])
                } else if kw == "周末" || kw == "双休" {
                    days.formUnion([1, 7])
                } else if kw == "单休" {
                    days.formUnion([2, 3, 4, 5, 6, 7])
                } else if kw == "周末三天" {
                    days.formUnion([1, 6, 7])
                }
                days.formUnion(generateWeeklyRange(start: sWd, end: eWd))
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 4. 连续区间 + 多个附加离散星期（如“周一至周三和周五周六”、“周一到周三以及周五、周日”、“周一至五和周六周日”）(v1.9.72)
        if let regex = rangeWithMultiDaysRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 4 {
            let startStr = nsString.substring(with: match.range(at: 1))
            let endStr = nsString.substring(with: match.range(at: 2))
            let multiStr = nsString.substring(with: match.range(at: 3))
            if let sChar = startStr.first, let sWd = chineseDayCharToWeekday(sChar),
               let eChar = endStr.first, let eWd = chineseDayCharToWeekday(eChar) {
                var days = Set(generateWeeklyRange(start: sWd, end: eWd))
                for ch in multiStr {
                    if let wd = chineseDayCharToWeekday(ch) {
                        days.insert(wd)
                    }
                }
                if !days.isEmpty {
                    let sorted = days.sorted()
                    return (sorted, formatWeekdayLabel(from: sorted))
                }
            }
        }

        // 4.1 多个离散星期在前 + 连续区间在后（如“周五和周一至周三”、“周日以及周一至周四”、“周五周日和周一至周三”、“周五、周六和周一至周三”、“周一和周五至周日”）(v1.9.73)
        if let regex = multiDaysWithRangeRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 5 {
            let multiStr = nsString.substring(with: match.range(at: 1))
            let startStr = nsString.substring(with: match.range(at: 3))
            let endStr = nsString.substring(with: match.range(at: 4))
            if let sChar = startStr.first, let sWd = chineseDayCharToWeekday(sChar),
               let eChar = endStr.first, let eWd = chineseDayCharToWeekday(eChar) {
                var days = Set<Int>()
                for ch in multiStr {
                    if let wd = chineseDayCharToWeekday(ch) {
                        days.insert(wd)
                    }
                }
                days.formUnion(generateWeeklyRange(start: sWd, end: eWd))
                if !days.isEmpty {
                    let sorted = days.sorted()
                    return (sorted, formatWeekdayLabel(from: sorted))
                }
            }
        }

        // 4.2 多个离散星期在前 + 核心关键词在后（如“周六周日和工作日”、“周二周四和周末”、“周五和周日加工作日”）(v1.9.73)
        if let regex = multiDaysWithKeywordRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 4 {
            let multiStr = nsString.substring(with: match.range(at: 1))
            let kw = nsString.substring(with: match.range(at: 3))
            var days = Set<Int>()
            if kw == "工作日" || kw == "平时" {
                days.formUnion([2, 3, 4, 5, 6])
            } else if kw == "周末" || kw == "双休" {
                days.formUnion([1, 7])
            } else if kw == "单休" {
                days.formUnion([2, 3, 4, 5, 6, 7])
            } else if kw == "周末三天" {
                days.formUnion([1, 6, 7])
            }
            for ch in multiStr {
                if let wd = chineseDayCharToWeekday(ch) {
                    days.insert(wd)
                }
            }
            if !days.isEmpty {
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 4.3 核心关键词在前 + 多个离散星期在后（如“工作日和周六周日”、“周末和周二周四”、“周末加周三、周五”）(v1.9.73)
        if let regex = keywordWithMultiDaysRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 3 {
            let kw = nsString.substring(with: match.range(at: 1))
            let multiStr = nsString.substring(with: match.range(at: 2))
            var days = Set<Int>()
            if kw == "工作日" || kw == "平时" {
                days.formUnion([2, 3, 4, 5, 6])
            } else if kw == "周末" || kw == "双休" {
                days.formUnion([1, 7])
            } else if kw == "单休" {
                days.formUnion([2, 3, 4, 5, 6, 7])
            } else if kw == "周末三天" {
                days.formUnion([1, 6, 7])
            }
            for ch in multiStr {
                if let wd = chineseDayCharToWeekday(ch) {
                    days.insert(wd)
                }
            }
            if !days.isEmpty {
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 5. 复合语义优先匹配：区间 + 附加星期（如“周一至周三以及周五”、“周一到周四还有周六”、“周一至五和周日”）(v1.9.67)
        if let regex = rangeWithExtraDaysRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 4 {
            let startStr = nsString.substring(with: match.range(at: 1))
            let endStr = nsString.substring(with: match.range(at: 2))
            let extraStr = nsString.substring(with: match.range(at: 3))
            if let sChar = startStr.first, let sWd = chineseDayCharToWeekday(sChar),
               let eChar = endStr.first, let eWd = chineseDayCharToWeekday(eChar),
               let exChar = extraStr.first, let exWd = chineseDayCharToWeekday(exChar) {
                var days = Set(generateWeeklyRange(start: sWd, end: eWd))
                days.insert(exWd)
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 2. 复合语义优先匹配：核心关键词 + 附加星期（如“工作日和周六”、“工作日及周日”、“工作日加周末”、“周末和周一”、“周末以及周五”、“单休和周日”）(v1.9.67, v1.9.71)
        if let regex = keywordWithExtraDayRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 3 {
            let kw = nsString.substring(with: match.range(at: 1))
            let extra = nsString.substring(with: match.range(at: 2))
            var days = Set<Int>()
            if kw == "工作日" || kw == "平时" {
                days.formUnion([2, 3, 4, 5, 6])
            } else if kw == "周末" || kw == "双休" {
                days.formUnion([1, 7])
            } else if kw == "单休" {
                days.formUnion([2, 3, 4, 5, 6, 7])
            } else if kw == "周末三天" {
                days.formUnion([1, 6, 7])
            }
            if extra == "工作日" || extra == "平时" {
                days.formUnion([2, 3, 4, 5, 6])
            } else if extra == "周末" || extra == "双休" {
                days.formUnion([1, 7])
            } else if extra == "单休" {
                days.formUnion([2, 3, 4, 5, 6, 7])
            } else if extra == "周末三天" {
                days.formUnion([1, 6, 7])
            } else if let ch = extra.first, let wd = chineseDayCharToWeekday(ch) {
                days.insert(wd)
            }
            if !days.isEmpty {
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 3. 复合语义优先匹配：附加星期在前 + 核心关键词在后（如“周六和工作日”、“周一和周末”、“周日和单休”）(v1.9.67, v1.9.71)
        if let regex = extraDayWithKeywordRegex,
           let match = regex.firstMatch(in: text, options: [], range: fullRange),
           match.numberOfRanges >= 3 {
            let dayChar = nsString.substring(with: match.range(at: 1))
            let kw = nsString.substring(with: match.range(at: 2))
            var days = Set<Int>()
            if let ch = dayChar.first, let wd = chineseDayCharToWeekday(ch) {
                days.insert(wd)
            }
            if kw == "工作日" || kw == "平时" {
                days.formUnion([2, 3, 4, 5, 6])
            } else if kw == "周末" || kw == "双休" {
                days.formUnion([1, 7])
            } else if kw == "单休" {
                days.formUnion([2, 3, 4, 5, 6, 7])
            } else if kw == "周末三天" {
                days.formUnion([1, 6, 7])
            }
            if !days.isEmpty {
                let sorted = days.sorted()
                return (sorted, formatWeekdayLabel(from: sorted))
            }
        }

        // 4. 语义化独立核心短语识别
        if text.contains("工作日") || text.contains("平时") {
            return ([2, 3, 4, 5, 6], "工作日")
        }
        if text.contains("周末三天") {
            return ([1, 6, 7], "周五至周日")
        }
        if text.contains("周末") || text.contains("双休") || text.contains("周六周日") || text.contains("周六和周日") ||
           text.contains("周六周天") || text.contains("周六日") || text.contains("周六天") || text.contains("星期六日") ||
           text.contains("星期六天") || text.contains("礼拜六日") || text.contains("礼拜六天") || text.contains("星期六星期天") ||
           text.contains("星期六和星期天") || text.contains("礼拜六礼拜天") || text.contains("礼拜六和礼拜天") ||
           text.contains("礼拜六礼拜日") || text.contains("礼拜六和礼拜日") {
            return ([1, 7], "周末")
        }
        if text.contains("单休") {
            return ([2, 3, 4, 5, 6, 7], "周一至周六")
        }
        if text.contains("一三五") || text.contains("一、三、五") {
            return ([2, 4, 6], "每周一、三、五")
        }
        if text.contains("二四六") || text.contains("二、四、六") {
            return ([3, 5, 7], "每周二、四、六")
        }
        if text.contains("二四") || text.contains("二、四") {
            return ([3, 5], "每周二、四")
        }

        // 5. 通用自然语言连续星期环形范围解析（涵盖“周一至周五”、“周一至五”、“周五至日”、“周六至二”、“周日至五”、“周1到5”、“周一~周五”等所有组合）(v1.9.65, v1.9.66)
        if let regex = repeatWeekdayRangeRegex {
            if let match = regex.firstMatch(in: text, options: [], range: fullRange),
               match.numberOfRanges >= 3 {
                let startStr = nsString.substring(with: match.range(at: 1))
                let endStr = nsString.substring(with: match.range(at: 2))
                if let startChar = startStr.first, let startWd = chineseDayCharToWeekday(startChar),
                   let endChar = endStr.first, let endWd = chineseDayCharToWeekday(endChar) {
                    let weekdays = generateWeeklyRange(start: startWd, end: endWd)
                    let label = formatWeekdayLabel(from: weekdays, startWd: startWd, endWd: endWd)
                    return (weekdays, label)
                }
            }
        }

        // 6. 通用自然语言离散多星期复合解析（涵盖“周一和周三”、“周二、周四与周六”、“周一及周五”、“星期二和星期四”、“礼拜一跟礼拜五”、“每周一和每周三”、“每个周二与每个周四”、“周一或者周四”、“周一还有周五”、“周一加周三”等） (v1.9.66, v1.9.67)
        if let regex = discreteWeekdaysRegex {
            if let match = regex.firstMatch(in: text, options: [], range: fullRange) {
                let matchText = nsString.substring(with: match.range)
                var parsedDays = Set<Int>()
                for ch in matchText {
                    if let wd = chineseDayCharToWeekday(ch) {
                        parsedDays.insert(wd)
                    }
                }
                if parsedDays.count >= 2 {
                    let sortedDays = parsedDays.sorted()
                    let label = formatWeekdayLabel(from: sortedDays)
                    return (sortedDays, label)
                }
            }
        }

        // 7. 单星期与每天自然语言识别
        if text.contains("每周一") || text.contains("每个周一") || text.contains("每个星期一") || text.contains("每周星期一") || text.contains("逢周一") || text.contains("每逢周一") || text.contains("每逢星期一") || text.contains("逢星期一") || text.contains("每个礼拜一") || text.contains("每周礼拜一") || text.contains("逢礼拜一") || text.contains("每逢礼拜一") {
            return ([2], "每周一")
        } else if text.contains("每周二") || text.contains("每个周二") || text.contains("每个星期二") || text.contains("每周星期二") || text.contains("逢周二") || text.contains("每逢周二") || text.contains("每逢星期二") || text.contains("逢星期二") || text.contains("每个礼拜二") || text.contains("每周礼拜二") || text.contains("逢礼拜二") || text.contains("每逢礼拜二") {
            return ([3], "每周二")
        } else if text.contains("每周三") || text.contains("每个周三") || text.contains("每个星期三") || text.contains("每周星期三") || text.contains("逢周三") || text.contains("每逢周三") || text.contains("每逢星期三") || text.contains("逢星期三") || text.contains("每个礼拜三") || text.contains("每周礼拜三") || text.contains("逢礼拜三") || text.contains("每逢礼拜三") {
            return ([4], "每周三")
        } else if text.contains("每周四") || text.contains("每个周四") || text.contains("每个星期四") || text.contains("每周星期四") || text.contains("逢周四") || text.contains("每逢周四") || text.contains("每逢星期四") || text.contains("逢星期四") || text.contains("每个礼拜四") || text.contains("每周礼拜四") || text.contains("逢礼拜四") || text.contains("每逢礼拜四") {
            return ([5], "每周四")
        } else if text.contains("每周五") || text.contains("每个周五") || text.contains("每个星期五") || text.contains("每周星期五") || text.contains("逢周五") || text.contains("每逢周五") || text.contains("每逢星期五") || text.contains("逢星期五") || text.contains("每个礼拜五") || text.contains("每周礼拜五") || text.contains("逢礼拜五") || text.contains("每逢礼拜五") {
            return ([6], "每周五")
        } else if text.contains("每周六") || text.contains("每个周六") || text.contains("每个星期六") || text.contains("每周星期六") || text.contains("逢周六") || text.contains("每逢周六") || text.contains("每逢星期六") || text.contains("逢星期六") || text.contains("每个礼拜六") || text.contains("每周礼拜六") || text.contains("逢礼拜六") || text.contains("每逢礼拜六") {
            return ([7], "每周六")
        } else if text.contains("每周日") || text.contains("每周天") || text.contains("每个周日") || text.contains("每个周天") || text.contains("每个星期天") || text.contains("每个星期日") || text.contains("每周星期天") || text.contains("每周星期日") || text.contains("逢周日") || text.contains("每逢周日") || text.contains("每逢星期天") || text.contains("每逢星期日") || text.contains("逢星期日") || text.contains("逢星期天") || text.contains("每个礼拜天") || text.contains("每个礼拜日") || text.contains("每周礼拜天") || text.contains("每周礼拜日") || text.contains("逢礼拜天") || text.contains("逢礼拜日") || text.contains("每逢礼拜天") || text.contains("每逢礼拜日") {
            return ([1], "每周日")
        } else if text.contains("每天") || text.contains("天天") || text.contains("每日") || text.contains("每晚") || text.contains("每早") || text.contains("每晨") || text.contains("每夜") || text.contains("日日") {
            return ([], "每天")
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

        // 默认“定时关机”/“定时关空调”/“定时开机”/“倒计时开机”/“定时启动” -> 默认 60 分钟 (v1.9.55, v1.9.78)
        if text.contains("定时关") || text.contains("倒计时关") || text.contains("预约关") ||
           text.contains("定时开") || text.contains("倒计时开") || text.contains("预约开") ||
           text.contains("定时启动") || text.contains("倒计时启动") || text.contains("预约启动") {
            return 60
        }

        return nil
    }

    private static func parseScheduleTime(from text: String) -> (hour: Int, minute: Int)? {
        let normalized = convertChineseNumbers(in: text)

        // 必须包含“点”或“时”或者标准时间冒号，或者独立时相词（午夜、子夜、正午、中午、晌午、傍晚、黄昏、天黑、清晨、早晨、黎明、拂晓、破晓、清早、大清早、天亮、天明、天蒙蒙亮、早上、明早、今早、早间、今晨、明晨、每晨、次晨、翌晨、上午、下午、午后、明午、晚上、今晚、明晚、晚间、入夜、夜间、夜里、大晚上、深夜、半夜、大半夜、前半夜、后半夜、三更半夜、深宵、通宵、夜深、今夜、明夜、每夜、整夜、彻夜、隔夜、后夜、夜半、凌晨、白天、日间、白昼、明天、后天、大后天、次日、隔日、翌日、明儿），且不是“小时” (v1.9.77, v1.9.78, v1.9.79, v1.9.80, v1.9.81, v1.9.84, v1.9.85 广义全时相大一统纳管)
        let hasTimePhase = normalized.contains("午夜") || normalized.contains("子夜") || normalized.contains("正午") ||
                           normalized.contains("中午") || normalized.contains("晌午") ||
                           normalized.contains("傍晚") || normalized.contains("黄昏") || normalized.contains("天黑") ||
                           normalized.contains("清晨") || normalized.contains("早晨") || normalized.contains("黎明") ||
                           normalized.contains("拂晓") || normalized.contains("破晓") || normalized.contains("清早") ||
                           normalized.contains("大清早") || normalized.contains("天亮") || normalized.contains("天明") ||
                           normalized.contains("天蒙蒙亮") ||
                           normalized.contains("早上") || normalized.contains("明早") || normalized.contains("今早") ||
                           normalized.contains("早间") ||
                           normalized.contains("今晨") || normalized.contains("明晨") || normalized.contains("每晨") ||
                           normalized.contains("次晨") || normalized.contains("翌晨") ||
                           normalized.contains("上午") || normalized.contains("下午") ||
                           normalized.contains("午后") || normalized.contains("明午") || normalized.contains("晚上") ||
                           normalized.contains("今晚") || normalized.contains("明晚") || normalized.contains("晚间") ||
                           normalized.contains("入夜") || normalized.contains("夜间") || normalized.contains("夜里") ||
                           normalized.contains("大晚上") ||
                           normalized.contains("深夜") || normalized.contains("半夜") || normalized.contains("大半夜") ||
                           normalized.contains("前半夜") || normalized.contains("后半夜") || normalized.contains("三更半夜") ||
                           normalized.contains("深宵") || normalized.contains("通宵") || normalized.contains("夜深") ||
                           normalized.contains("今夜") || normalized.contains("明夜") || normalized.contains("每夜") ||
                           normalized.contains("整夜") || normalized.contains("彻夜") || normalized.contains("隔夜") ||
                           normalized.contains("后夜") || normalized.contains("夜半") ||
                           normalized.contains("凌晨") ||
                           normalized.contains("白天") || normalized.contains("日间") || normalized.contains("白昼") ||
                           normalized.contains("明天") || normalized.contains("后天") || normalized.contains("大后天") ||
                           normalized.contains("次日") || normalized.contains("隔日") || normalized.contains("翌日") ||
                           normalized.contains("明儿") ||
                           normalized.contains("明日") || normalized.contains("隔天") || normalized.contains("后日") ||
                           normalized.contains("大后日") || normalized.contains("明儿个") ||
                           normalized.contains("后儿个") || normalized.contains("后儿") ||
                           normalized.contains("大后儿") || normalized.contains("大后儿个") ||
                           normalized.contains("今天") || normalized.contains("今日") ||
                           normalized.contains("今儿") || normalized.contains("今儿个")
        guard (normalized.contains("点") || normalized.contains("时") || normalized.contains(":") || hasTimePhase) && !normalized.contains("小时") else {
            return nil
        }

        let hasColloquialEvening = (normalized.range(of: #"晚\s*\d+"#, options: .regularExpression) != nil)
        let isNightMidnight = normalized.contains("晚上") || normalized.contains("今晚") ||
                              normalized.contains("明晚") || normalized.contains("每晚") ||
                              normalized.contains("晚间") || normalized.contains("夜里") ||
                              normalized.contains("半夜") || normalized.contains("午夜") ||
                              normalized.contains("深夜") || normalized.contains("夜间") ||
                              normalized.contains("夜深") || normalized.contains("凌晨") ||
                              normalized.contains("深宵") || normalized.contains("子夜") ||
                              normalized.contains("通宵") || normalized.contains("入夜") ||
                              normalized.contains("前半夜") || normalized.contains("后半夜") || normalized.contains("三更半夜") ||
                              normalized.contains("今夜") || normalized.contains("明夜") || normalized.contains("每夜") ||
                              normalized.contains("整夜") || normalized.contains("彻夜") || normalized.contains("隔夜") ||
                              normalized.contains("后夜") || normalized.contains("夜半") ||
                              hasColloquialEvening
        let isAfternoonPM = normalized.contains("下午") || normalized.contains("傍晚") || normalized.contains("午后")
        let isNoon = normalized.contains("中午") || normalized.contains("正午") || normalized.contains("晌午")

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

        // 2. 差分倒算结构 (v1.9.48: 支持“十点差五分”与“差五分十点”等逆序时间计算, v1.9.49: 支持“分钟”与半小时/刻度倒算)
        // 2.1 Pattern: (\d{1,2})\s*(?:点|时)\s*差\s*(\d{1,2})\s*(?:分钟|分)? (如 10点差5分 / 10点差5分钟 -> 09:55)
        if hour == nil {
            let diffPattern1 = #"(\d{1,2})\s*(?:点|时)\s*差\s*(\d{1,2})\s*(?:分钟|分)?"#
            if let regex = try? NSRegularExpression(pattern: diffPattern1) {
                let ns = normalized as NSString
                if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                    let targetHStr = ns.substring(with: match.range(at: 1))
                    let diffMStr = ns.substring(with: match.range(at: 2))
                    if let targetH = Int(targetHStr), targetH <= 23, let diffM = Int(diffMStr), diffM > 0 && diffM < 60 {
                        hour = (targetH + 24 - 1) % 24
                        minute = 60 - diffM
                    }
                }
            }
        }

        // 2.2 Pattern: 差\s*(\d{1,2})\s*(?:分钟|分)?\s*(\d{1,2})\s*(?:点|时) (如 差5分10点 / 差5分钟10点 -> 09:55)
        if hour == nil {
            let diffPattern2 = #"差\s*(\d{1,2})\s*(?:分钟|分)?\s*(\d{1,2})\s*(?:点|时)"#
            if let regex = try? NSRegularExpression(pattern: diffPattern2) {
                let ns = normalized as NSString
                if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                    let diffMStr = ns.substring(with: match.range(at: 1))
                    let targetHStr = ns.substring(with: match.range(at: 2))
                    if let targetH = Int(targetHStr), targetH <= 23, let diffM = Int(diffMStr), diffM > 0 && diffM < 60 {
                        hour = (targetH + 24 - 1) % 24
                        minute = 60 - diffM
                    }
                }
            }
        }

        // 3. X点 / X时 (含零点 / 0点及后接分钟提取)
        if hour == nil {
            let pointPattern = #"(\d{1,2})\s*(?:点|时)(?:\s*(?:过|零|0)?\s*(\d{1,2})\s*(?:分钟|分)?)?"#
            if let regex = try? NSRegularExpression(pattern: pointPattern) {
                let ns = normalized as NSString
                if let match = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).first {
                    let hStr = ns.substring(with: match.range(at: 1))
                    var candidateMinute = 0
                    let minRange = match.range(at: 2)
                    if minRange.location != NSNotFound {
                        let mStr = ns.substring(with: minRange)
                        if let m = Int(mStr), m < 60 {
                            candidateMinute = m
                        }
                    }
                    if let h = Int(hStr), h <= 23 {
                        // 语义安全防线：若数值位于 16~23°C 空调核心温度区间且疑似分钟为 5，但文本未明确指明“分/分钟”且包含开/调/设等温控动作词，
                        // 明确判定为省略“度”字的小数温度（如“开20点5/开到21点5”），彻底杜绝误判为时间 (v1.9.53)
                        let isLikelyDecimalTemp = (h >= 16 && h <= 23) && (candidateMinute == 5) &&
                            (!normalized.contains("分") && !normalized.contains("过") && !normalized.contains("零") && !normalized.contains("0")) &&
                            (normalized.contains("开") || normalized.contains("调") || normalized.contains("设") || normalized.contains("空调") || normalized.contains("全屋"))
                        if !isLikelyDecimalTemp {
                            hour = h
                            minute = candidateMinute
                        }
                    }
                }
            }
        }

        // 3.5 独立无钟点独立时相结构 (v1.9.77, v1.9.78, v1.9.79, v1.9.80, v1.9.81, v1.9.84, v1.9.85 广义全时相大一统纳管)
        if hour == nil {
            if normalized.contains("午夜") || normalized.contains("子夜") || normalized.contains("三更半夜") || normalized.contains("夜半") {
                hour = 0
                minute = 0
            } else if normalized.contains("正午") || normalized.contains("中午") || normalized.contains("晌午") {
                hour = 12
                minute = 0
            } else if normalized.contains("前半夜") {
                hour = 22
                minute = 0
            } else if normalized.contains("后半夜") {
                hour = 2
                minute = 0
            } else if normalized.contains("傍晚") || normalized.contains("黄昏") || normalized.contains("天黑") {
                hour = 18
                minute = 0
            } else if normalized.contains("清晨") || normalized.contains("早晨") || normalized.contains("黎明") ||
                       normalized.contains("拂晓") || normalized.contains("破晓") || normalized.contains("清早") ||
                       normalized.contains("大清早") || normalized.contains("天亮") || normalized.contains("天明") ||
                       normalized.contains("天蒙蒙亮") {
                hour = 6
                minute = 0
            } else if normalized.contains("早上") || normalized.contains("明早") || normalized.contains("今早") || normalized.contains("早间") ||
                       normalized.contains("今晨") || normalized.contains("明晨") || normalized.contains("每晨") ||
                       normalized.contains("次晨") || normalized.contains("翌晨") {
                hour = 7
                minute = 0
            } else if normalized.contains("上午") {
                hour = 9
                minute = 0
            } else if normalized.contains("下午") || normalized.contains("午后") || normalized.contains("明午") {
                hour = 14
                minute = 0
            } else if normalized.contains("晚上") || normalized.contains("今晚") || normalized.contains("明晚") ||
                       normalized.contains("晚间") || normalized.contains("入夜") || normalized.contains("夜间") ||
                       normalized.contains("夜里") || normalized.contains("大晚上") ||
                       normalized.contains("今夜") || normalized.contains("明夜") || normalized.contains("每夜") {
                hour = 21
                minute = 0
            } else if normalized.contains("深夜") || normalized.contains("半夜") || normalized.contains("深宵") ||
                       normalized.contains("通宵") || normalized.contains("夜深") || normalized.contains("大半夜") ||
                       normalized.contains("整夜") || normalized.contains("彻夜") || normalized.contains("隔夜") {
                hour = 23
                minute = 0
            } else if normalized.contains("后半夜") || normalized.contains("后夜") {
                hour = 2
                minute = 0
            } else if normalized.contains("凌晨") {
                hour = 5
                minute = 0
            } else if normalized.contains("白天") || normalized.contains("日间") || normalized.contains("白昼") {
                hour = 8
                minute = 0
            } else if normalized.contains("明天") || normalized.contains("后天") || normalized.contains("大后天") ||
                       normalized.contains("次日") || normalized.contains("隔日") || normalized.contains("翌日") ||
                       normalized.contains("明儿") || normalized.contains("明日") || normalized.contains("隔天") ||
                       normalized.contains("后日") || normalized.contains("大后日") || normalized.contains("明儿个") ||
                       normalized.contains("后儿个") || normalized.contains("后儿") ||
                       normalized.contains("大后儿") || normalized.contains("大后儿个") ||
                       normalized.contains("今天") || normalized.contains("今日") ||
                       normalized.contains("今儿") || normalized.contains("今儿个") {
                hour = 8
                minute = 0
            }
        }

        guard var finalHour = hour else { return nil }

        // 4. 兜底后置分钟（以防复杂修饰语未被第3条捕获）
        if minute == 0 {
            let minPattern = #"(?:点|时)\s*(?:过|零|0)?\s*(\d{1,2})\s*(?:分钟|分)"#
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

        // 5. 钟点时段与时态校准 (v1.9.48 彻底根除午夜/零点误为正午及中午11点误为深夜23点缺陷, v1.9.55 规范半夜/午夜9~11点深宵时区, v1.9.76 规范深宵/夜里/凌晨, v1.9.77 闭环深宵/子夜/通宵/正午全时相消歧与无钟点独立时相调度引擎, v1.9.84 闭环今夜/明夜/每夜/整夜/彻夜/后夜/隔夜大一统时区校准, v1.9.85 闭环晨间与夜半时相, v1.9.86 闭环明日/隔天/后日跨天口语)
        if finalHour == 12 {
            if isNightMidnight {
                // “晚上12点”、“半夜12点”、“午夜12点”、“凌晨12点”、“深夜12点”、“深宵12点”、“子夜12点”、“今夜12点”、“夜半12点”均代表午夜 00:00
                finalHour = 0
            }
        } else if finalHour == 0 {
            // 明确的“零点/0点/0时/午夜/子夜/夜半”，无论前缀如何，恒定为 00:xx，严禁累加 12
            finalHour = 0
        } else if finalHour > 0 && finalHour < 12 {
            let isNocturnal = normalized.contains("夜里") || normalized.contains("半夜") ||
                              normalized.contains("午夜") || normalized.contains("深夜") ||
                              normalized.contains("夜间") || normalized.contains("夜深") ||
                              normalized.contains("深宵") || normalized.contains("子夜") ||
                              normalized.contains("通宵") || normalized.contains("入夜") ||
                              normalized.contains("前半夜") || normalized.contains("后半夜") || normalized.contains("三更半夜") ||
                              normalized.contains("整夜") || normalized.contains("彻夜") || normalized.contains("隔夜") ||
                              normalized.contains("后夜") || normalized.contains("夜半")
            let isEveningStandard = normalized.contains("晚上") || normalized.contains("今晚") ||
                                    normalized.contains("明晚") || normalized.contains("每晚") ||
                                    normalized.contains("晚间") ||
                                    normalized.contains("今夜") || normalized.contains("明夜") || normalized.contains("每夜") ||
                                    hasColloquialEvening

            if isAfternoonPM {
                // 下午、傍晚、午后 1~11 点 -> 13:00 ~ 23:00
                finalHour += 12
            } else if isNoon && finalHour <= 5 {
                // 中午 1 点、2 点等午后时段 -> 13:00 ~ 17:00
                finalHour += 12
            } else if isNocturnal {
                // 深夜/半夜/午夜/夜里/夜间/深宵/子夜/通宵：
                // 6~11 点属于傍晚/入夜/深宵时段（如“夜里7点”=19:00、“深宵10点”=22:00、“子夜11点”=23:00）累加 12
                // 1~5 点属于后半夜/黎明子夜时段（如“夜里1点”=01:00、“深宵1点”=01:00、“子夜2点”=02:00、“深夜3点”=03:00），保持 01:00 ~ 05:00，严禁累加 12 误判为下午 (v1.9.76, v1.9.77)
                if finalHour >= 6 {
                    finalHour += 12
                }
            } else if isEveningStandard {
                // 晚上/今晚/明晚/每晚/晚间：
                // 6~11 点属于标准晚间（如“晚上8点”=20:00、“晚上11点”=23:00）累加 12
                // 1~5 点口语表达习惯（如“晚上1点睡/明晚2点关机”实际指后半夜 01:00/02:00），保持 01:00 ~ 05:00，绝非下午 13:00/14:00 (v1.9.76, v1.9.77)
                if finalHour >= 6 {
                    finalHour += 12
                }
            }
        }

        if finalHour >= 24 {
            finalHour = 0
        }

        return (finalHour, minute)
    }

    private static let negativeActionRegex: NSRegularExpression? = {
        // 否定词（别/不要/不用/不必/无需/先别/先不要/暂不/暂不要/千万别/千万不要/不能/不可以/切勿/切莫/不要再/别再/暂时不用/暂时不要）
        // 允许中间插入 0~10 个任意非标点非空白字符（如“周一到周六定时”、“星期一到星期五”、“给我”、“帮我”、“急着”、“现在”等，彻底杜绝插字绕过漏洞） (v1.9.40, v1.9.57)
        // 动作谓词（关/停/开/启动/运转/打开/关闭/调/设/升/降/重置/复位/清零/吹/送/抽/除/暂停/恢复/取消/清除/删除/撤销/清空） (v1.9.39 扩展调温与变频动作否定, v1.9.45 扩展滤网重置否定, v1.9.50 扩展吹风除湿动作否定, v1.9.60 扩展计划调度暂停恢复动作否定, v1.9.61 扩展取消删除调度动作否定, v1.9.63 扩展清空任务动作否定)
        let pattern = #"(?:别|不要|不用|不必|无需|先别|先不要|暂不|暂不要|千万别|千万不要|不能|不可以|切勿|切莫|不要再|别再|暂时不用|暂时不要)[^，。！？\s]{0,10}?(?:关|停|开|启动|运转|打开|关闭|调|设|升|降|重置|复位|清零|吹|送|抽|除|暂停|恢复|取消|清除|删除|撤销|清空)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 结构化匹配特定动作的否定意图（允许中间插入 0~10 个任意非标点非空白字符，彻底杜绝插字绕过漏洞） (v1.9.61)
    private static func containsNegativeForAction(text: String, actionPattern: String) -> Bool {
        let pattern = #"(?:别|不要|不用|不必|无需|先别|先不要|暂不|暂不要|千万别|千万不要|不能|不可以|切勿|切莫|不要再|别再|暂时不用|暂时不要)[^，。！？\s]{0,10}?"# + actionPattern
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    /// 检测文本中是否包含针对开关机/调温/模式动作的否定意图（如“别关”、“不要开”、“先别急着关”、“别给我关了”、“千万别现在关”、“别开制冷”、“不要调”、“别重置”、“别吹风”、“别暂停定时”等，防止误触发） (v1.9.36, v1.9.40, v1.9.45, v1.9.50, v1.9.60, v1.9.61)
    private static func containsNegativeAction(_ text: String) -> Bool {
        // 特例：“别吹了”属于日常高频关机意图（显式关机口令，非动作否定拦截）
        if text.contains("别吹了") {
            return false
        }
        guard let regex = negativeActionRegex else {
            let fallbackPatterns = [
                "别关", "不要关", "不用关", "先别关", "先不要关", "暂不关", "不能关", "不可以关", "别停", "不要停", "不用停",
                "别开", "不要开", "不用开", "先别开", "先不要开", "暂不开", "不能开", "不可以开", "别启动", "不要启动",
                "别调", "不要调", "不用调", "别设", "不要设", "别升", "不要升", "别降", "不要降",
                "别重置", "不要重置", "不用重置", "别复位", "不要复位", "别清零",
                "别吹", "不要吹", "不用吹", "别送风", "不要送风", "别抽湿", "不要抽湿", "别除湿", "不要除湿",
                "别暂停", "不要暂停", "不用暂停", "千万别暂停", "别恢复", "不要恢复", "不用恢复", "千万别恢复",
                "别取消", "不要取消", "不用取消", "千万别取消", "别清除", "不要清除", "别删除", "不要删除", "别清空", "不要清空", "不用清空", "千万别清空",
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

    /// 判断口令是否包含定时、倒计时或延迟执行时间语义，杜绝误触发即时开关机 (v1.9.50, v1.9.56, v1.9.57, v1.9.59, v1.9.60, v1.9.79, v1.9.80, v1.9.81, v1.9.84, v1.9.85, v1.9.86 跨天全景口语时相全防线)
    private static func hasTimingOrCountdownIntent(_ text: String) -> Bool {
        if text.contains("后") || text.contains("倒计时") || text.contains("定时") || text.contains("预约") ||
           text.contains("延迟") || text.contains("延后") || text.contains("稍后") ||
           text.contains("每天") || text.contains("天天") || text.contains("每日") || text.contains("每晚") || text.contains("每早") || text.contains("每晨") || text.contains("每夜") ||
           text.contains("工作日") || text.contains("周末") || text.contains("双休") ||
           text.contains("每周") || text.contains("每逢") || text.contains("逢周") || text.contains("每个周") || text.contains("每个星期") ||
           text.contains("礼拜") || text.contains("逢星期") || text.contains("一三五") || text.contains("二四六") || text.contains("二四") ||
           text.contains("周末三天") ||
           text.contains("午夜") || text.contains("子夜") || text.contains("正午") || text.contains("中午") || text.contains("晌午") ||
           text.contains("傍晚") || text.contains("黄昏") || text.contains("天黑") ||
           text.contains("清晨") || text.contains("早晨") || text.contains("黎明") || text.contains("拂晓") || text.contains("破晓") || text.contains("清早") ||
           text.contains("大清早") || text.contains("天亮") || text.contains("天明") || text.contains("天蒙蒙亮") ||
           text.contains("早上") || text.contains("明早") || text.contains("今早") || text.contains("早间") ||
           text.contains("今晨") || text.contains("明晨") || text.contains("次晨") || text.contains("翌晨") ||
           text.contains("上午") || text.contains("下午") || text.contains("午后") || text.contains("明午") ||
           text.contains("晚上") || text.contains("今晚") || text.contains("明晚") || text.contains("晚间") ||
           text.contains("入夜") || text.contains("夜间") || text.contains("夜里") || text.contains("大晚上") ||
           text.contains("深夜") || text.contains("半夜") || text.contains("大半夜") || text.contains("前半夜") || text.contains("后半夜") || text.contains("三更半夜") ||
           text.contains("深宵") || text.contains("通宵") || text.contains("夜深") ||
           text.contains("今夜") || text.contains("明夜") ||
           text.contains("整夜") || text.contains("彻夜") || text.contains("隔夜") || text.contains("后夜") || text.contains("夜半") ||
           text.contains("凌晨") ||
           text.contains("白天") || text.contains("日间") || text.contains("白昼") ||
           text.contains("明天") || text.contains("后天") || text.contains("大后天") || text.contains("次日") ||
           text.contains("隔日") || text.contains("翌日") || text.contains("明儿") ||
           text.contains("明日") || text.contains("隔天") || text.contains("后日") || text.contains("大后日") || text.contains("明儿个") ||
           text.contains("后儿个") || text.contains("后儿") || text.contains("大后儿") || text.contains("大后儿个") ||
           text.contains("后日半") || text.contains("大后日半") ||
           text.contains("今天") || text.contains("今日") || text.contains("今儿") || text.contains("今儿个") ||
           (text.contains("暂停") && (text.contains("定时") || text.contains("倒计时") || text.contains("计划") || text.contains("调度"))) ||
           (text.contains("恢复") && (text.contains("定时") || text.contains("倒计时") || text.contains("计划") || text.contains("调度"))) {
            return true
        }
        let weekdayPrefixes = ["周", "星期", "礼拜"]
        let weekdayConnectors = ["到", "至"]
        for p in weekdayPrefixes {
            for c in weekdayConnectors {
                if text.contains("\(p)一\(c)") || text.contains("\(p)二\(c)") || text.contains("\(p)三\(c)") ||
                   text.contains("\(p)四\(c)") || text.contains("\(p)五\(c)") || text.contains("\(p)六\(c)") ||
                   text.contains("\(p)日\(c)") || text.contains("\(p)天\(c)") {
                    return true
                }
            }
        }
        if text.contains("过") && (text.contains("分") || text.contains("小时") || text.contains("钟头") || text.contains("半") || text.contains("刻")) {
            return true
        }
        if text.contains("等") && (text.contains("分") || text.contains("小时") || text.contains("钟头") || text.contains("半") || text.contains("刻")) {
            return true
        }
        if parseRepeatWeekdays(text) != nil {
            return true
        }
        if parseCountdownMinutes(from: text) != nil {
            return true
        }
        if parseScheduleTime(from: text) != nil {
            return true
        }
        return false
    }

    private static func isAllPowerOff(_ text: String) -> Bool {
        guard !containsNegativeAction(text) else { return false }
        // 排除定时与倒计时命令（如“全屋30分钟后关机”、“全屋过半小时关机”、“全屋30分钟关机”、“所有空调晚上10点关机”） (v1.9.40, v1.9.50)
        if hasTimingOrCountdownIntent(text) {
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
            "所有空调关掉", "全部空调关掉", "空调全关了", "空调都关了", "全关掉",
            "停止所有空调", "停止全部空调", "所有空调停止", "全部空调停止", "全屋停止",
            "所有空调都停了", "全部空调都停了", "全屋停机", "全部停机", "全屋都关了", "全屋都停了"
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

        // 排除风速调节命令（如“全屋自动风”、“全屋开大风”、“所有空调微风”、“全屋开到最大”） (v1.9.41, v1.9.50)
        if text.contains("自动风") || text.contains("风速") || text.contains("微风") || text.contains("大风") || text.contains("强劲") ||
           text.contains("最大") || text.contains("最小") {
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
        // 排除定时与倒计时命令（如“全屋半小时后开机”、“全屋过半小时开机”、“全屋明早7点开机”） (v1.9.40, v1.9.50)
        if hasTimingOrCountdownIntent(text) {
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
        // 排除风速调节命令（如“全屋开大风”、“所有空调开微风”、“全屋自动风”、“全屋开到最大”） (v1.9.41, v1.9.50)
        let windKeywords = [
            "自动风", "风速", "大风", "风大", "强劲", "高风", "微风", "小风", "风小", "静音", "柔风", "低风", "中风",
            "最大", "最小", "开到最大", "开到最小", "高速风", "低速风", "中速风", "档", "档位", "档风"
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
        // 排除定时与倒计时命令（如“30分钟后关机”、“过半小时关机”、“30分钟关机”、“晚上10点关空调”） (v1.9.40, v1.9.50)
        if hasTimingOrCountdownIntent(text) {
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
            "关了", "关上", "关一下", "关停", "关掉它", "断电",
            "停止运行", "停止运转", "停止工作", "停掉空调", "停掉", "停一下", "停止"
        ]
        if offKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        // 典型把字句与口语结构：包含“关了”、“关掉”、“关上”、“停了”、“停掉”或以“关/停”开头/结尾
        if (text.contains("把") && (text.contains("关了") || text.contains("关掉") || text.contains("关上") || text.contains("停了") || text.contains("停掉"))) ||
           text.hasPrefix("关") || text.hasSuffix("关") || text.hasSuffix("关了") || text.hasSuffix("关机") || text.hasSuffix("关一下") ||
           text.hasPrefix("停") || text.hasSuffix("停了") || text.hasSuffix("停机") || text.hasSuffix("停一下") || text.hasSuffix("停止") {
            return true
        }
        return false
    }

    private static func isPowerOn(_ text: String) -> Bool {
        guard !containsNegativeAction(text) else { return false }
        // 排除定时与倒计时命令（如“30分钟后开机”、“过半小时开机”、“早上7点开空调”） (v1.9.40, v1.9.50)
        if hasTimingOrCountdownIntent(text) {
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
        // 排除风速调节命令（如“开大风”、“开微风”、“开小风”、“开强劲风”、“开静音”、“自动风”、“开到最大”、“开到最小”）(v1.9.38, v1.9.50)
        let windKeywords = [
            "自动风", "风速", "大风", "风大", "强劲", "高风", "微风", "小风", "风小", "静音", "柔风", "低风", "中风",
            "最大", "最小", "开到最大", "开到最小", "高速风", "低速风", "中速风", "档", "档位", "档风"
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
        // 优先匹配带明确方向与幅度的口令（如“太冷了调高两度”、“升温2度”、“上调1度”、“往上调半度”、“降温两度”、“下调一度”、“往下调半度”） (v1.9.50, v1.9.54)
        let warmerKeywords = [
            "高", "升", "加", "热一点", "热点", "更热", "暖和一点", "暖和点", "暖和些", "暖一点", "暖点", "暖些",
            "上调", "往上", "向上", "调上"
        ]
        if warmerKeywords.contains(where: { text.contains($0) }) {
            let delta = extractNumber(from: text) ?? 1.0
            let validDelta = (delta > 0 && delta <= 5) ? delta : 1.0
            return VoiceParseResult(
                command: .adjustTemperature(delta: validDelta),
                displayText: "升温 \(formatTemp(validDelta))°C"
            )
        }

        let coolerKeywords = [
            "低", "降", "减", "冷一点", "冷点", "更冷", "冷些", "凉一点", "凉点", "更凉", "凉些", "凉快一点", "凉快点", "凉快些",
            "下调", "往下", "向下", "调下"
        ]
        if coolerKeywords.contains(where: { text.contains($0) }) {
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
        if text.contains("太冷") || text.contains("好冷") || text.contains("有点冷") || text.contains("冷死") ||
           text.contains("太冻") || text.contains("好冻") || text.contains("有点冻") || text.contains("冻死") || text.contains("冻僵") {
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
            // 1. 自动风档位 (v1.9.83 严格限定智能/自动/自适应风速，杜绝将 4 档机械割裂误判为自动风)
            if text.contains("自动风") || text.contains("风速自动") || text.contains("自动风速") ||
               text.contains("智能风") || text.contains("自适应风") || text.contains("智能风速") ||
               text.contains("自适应风速") || text.contains("自动档") || text.contains("自动档位") {
                return ("自动", "自动风速")
            }
            // 2. 强劲 / 暴风 / 5档 / 4档 / 3档 / 高风 / 大风 (v1.9.47, v1.9.83 全量对齐变频大档位动力学，支持4档、5档与暴风极速)
            if text.contains("暴风") || text.contains("超强") || text.contains("极速") ||
               text.contains("五档") || text.contains("5档") || text.contains("第5档") || text.contains("第五档") ||
               text.contains("风速5") || text.contains("风速五") ||
               text.contains("四档") || text.contains("4档") || text.contains("第4档") || text.contains("第四档") ||
               text.contains("风速4") || text.contains("风速四") ||
               text.contains("大风") || text.contains("风大") || text.contains("强劲") || text.contains("高风") ||
               text.contains("最大风") || text.contains("最大") || text.contains("调大风") || text.contains("风速大") ||
               text.contains("高速风") || text.contains("开到最大") || text.contains("强风") ||
               text.contains("三档") || text.contains("3档") || text.contains("第3档") || text.contains("第三档") ||
               text.contains("风速3") || text.contains("风速三") || text.contains("高档") || text.contains("风速调大") ||
               text.contains("风开大") || text.contains("把风开大") || text.contains("风调大") || text.contains("风大点") ||
               text.contains("调大风速") || text.contains("开大风速") || text.contains("吹大风") ||
               text.contains("吹暴风") || text.contains("吹强风") {
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
               text.contains("吹小风") || text.contains("轻风") {
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
        var normalized = convertChineseNumbers(in: text)
        normalized = normalized.replacingOccurrences(of: "点", with: ".")
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

        // 单独的固定搭配与刻度归一 (v1.9.44 解决“一刻钟后关机”与“十点一刻关机”缺陷, v1.9.46 根除“半个小时”、“二刻钟”、“两刻/二刻后”、“十点两刻/十点二刻”等映射缺失与误判为 10:02 的严重缺陷, v1.9.81 纳管“三更半夜”成语时相, v1.9.82 纳管“前半夜”与死分支修复)
        str = str.replacingOccurrences(of: "三更半夜半", with: "午夜0点30分")
        str = str.replacingOccurrences(of: "三更半夜", with: "午夜")
        str = str.replacingOccurrences(of: "一个半小时", with: "1.5小时")
        str = str.replacingOccurrences(of: "1个半小时", with: "1.5小时")
        str = str.replacingOccurrences(of: "一个半钟头", with: "1.5小时")
        str = str.replacingOccurrences(of: "1个半钟头", with: "1.5小时")
        str = str.replacingOccurrences(of: "半个小时", with: "30分钟")
        str = str.replacingOccurrences(of: "半个钟头", with: "30分钟")
        str = str.replacingOccurrences(of: "半钟头", with: "30分钟")
        str = str.replacingOccurrences(of: "半小时", with: "30分钟")
        str = str.replacingOccurrences(of: "中午半", with: "中午12点30分")
        str = str.replacingOccurrences(of: "正午半", with: "正午12点30分")
        str = str.replacingOccurrences(of: "晌午半", with: "晌午12点30分")
        str = str.replacingOccurrences(of: "午夜半", with: "午夜0点30分")
        str = str.replacingOccurrences(of: "子夜半", with: "子夜0点30分")
        str = str.replacingOccurrences(of: "前半夜半", with: "前半夜10点30分")
        str = str.replacingOccurrences(of: "后半夜半", with: "后半夜2点30分")
        str = str.replacingOccurrences(of: "傍晚半", with: "傍晚6点30分")
        str = str.replacingOccurrences(of: "黄昏半", with: "黄昏6点30分")
        str = str.replacingOccurrences(of: "天黑半", with: "天黑6点30分")
        str = str.replacingOccurrences(of: "清晨半", with: "清晨6点30分")
        str = str.replacingOccurrences(of: "早晨半", with: "早晨6点30分")
        str = str.replacingOccurrences(of: "黎明半", with: "黎明6点30分")
        str = str.replacingOccurrences(of: "清早半", with: "清早6点30分")
        str = str.replacingOccurrences(of: "拂晓半", with: "拂晓6点30分")
        str = str.replacingOccurrences(of: "破晓半", with: "破晓6点30分")
        str = str.replacingOccurrences(of: "大清早半", with: "大清早6点30分")
        str = str.replacingOccurrences(of: "天亮半", with: "天亮6点30分")
        str = str.replacingOccurrences(of: "天明半", with: "天明6点30分")
        str = str.replacingOccurrences(of: "天蒙蒙亮半", with: "天蒙蒙亮6点30分")
        str = str.replacingOccurrences(of: "早上半", with: "早上7点30分")
        str = str.replacingOccurrences(of: "明早半", with: "明早7点30分")
        str = str.replacingOccurrences(of: "今早半", with: "今早7点30分")
        str = str.replacingOccurrences(of: "早间半", with: "早间7点30分")
        str = str.replacingOccurrences(of: "上午半", with: "上午9点30分")
        str = str.replacingOccurrences(of: "白天半", with: "白天8点30分")
        str = str.replacingOccurrences(of: "日间半", with: "日间8点30分")
        str = str.replacingOccurrences(of: "白昼半", with: "白昼8点30分")
        str = str.replacingOccurrences(of: "下午半", with: "下午2点30分")
        str = str.replacingOccurrences(of: "午后半", with: "午后2点30分")
        str = str.replacingOccurrences(of: "明午半", with: "明午2点30分")
        str = str.replacingOccurrences(of: "晚上半", with: "晚上9点30分")
        str = str.replacingOccurrences(of: "今晚半", with: "今晚9点30分")
        str = str.replacingOccurrences(of: "明晚半", with: "明晚9点30分")
        str = str.replacingOccurrences(of: "晚间半", with: "晚间9点30分")
        str = str.replacingOccurrences(of: "入夜半", with: "入夜9点30分")
        str = str.replacingOccurrences(of: "夜间半", with: "夜间9点30分")
        str = str.replacingOccurrences(of: "夜里半", with: "夜里9点30分")
        str = str.replacingOccurrences(of: "大晚上半", with: "大晚上9点30分")
        str = str.replacingOccurrences(of: "深夜半", with: "深夜11点30分")
        str = str.replacingOccurrences(of: "半夜半", with: "半夜11点30分")
        str = str.replacingOccurrences(of: "大半夜半", with: "大半夜11点30分")
        str = str.replacingOccurrences(of: "凌晨半", with: "凌晨5点30分")
        str = str.replacingOccurrences(of: "深宵半", with: "深宵11点30分")
        str = str.replacingOccurrences(of: "通宵半", with: "通宵11点30分")
        str = str.replacingOccurrences(of: "夜深半", with: "夜深11点30分")
        str = str.replacingOccurrences(of: "今夜半", with: "今夜9点30分")
        str = str.replacingOccurrences(of: "明夜半", with: "明夜9点30分")
        str = str.replacingOccurrences(of: "每夜半", with: "每夜9点30分")
        str = str.replacingOccurrences(of: "整夜半", with: "整夜11点30分")
        str = str.replacingOccurrences(of: "彻夜半", with: "彻夜11点30分")
        str = str.replacingOccurrences(of: "隔夜半", with: "隔夜11点30分")
        str = str.replacingOccurrences(of: "后夜半", with: "后夜2点30分")
        str = str.replacingOccurrences(of: "隔日半", with: "隔日8点30分")
        str = str.replacingOccurrences(of: "翌日半", with: "翌日8点30分")
        str = str.replacingOccurrences(of: "明日半", with: "明日8点30分")
        str = str.replacingOccurrences(of: "明天半", with: "明天8点30分")
        str = str.replacingOccurrences(of: "隔天半", with: "隔天8点30分")
        str = str.replacingOccurrences(of: "大后日半", with: "大后日8点30分")
        str = str.replacingOccurrences(of: "后日半", with: "后日8点30分")
        str = str.replacingOccurrences(of: "大后天半", with: "大后天8点30分")
        str = str.replacingOccurrences(of: "后天半", with: "后天8点30分")
        str = str.replacingOccurrences(of: "今天半", with: "今天8点30分")
        str = str.replacingOccurrences(of: "今日半", with: "今日8点30分")
        str = str.replacingOccurrences(of: "今儿个半", with: "今儿个8点30分")
        str = str.replacingOccurrences(of: "后儿个半", with: "后儿个8点30分")
        str = str.replacingOccurrences(of: "后儿半", with: "后儿8点30分")
        str = str.replacingOccurrences(of: "明儿个半", with: "明儿个8点30分")
        str = str.replacingOccurrences(of: "明儿半", with: "明儿8点30分")
        str = str.replacingOccurrences(of: "今儿半", with: "今儿8点30分")
        str = str.replacingOccurrences(of: "大后儿半", with: "大后儿8点30分")
        str = str.replacingOccurrences(of: "大后儿个半", with: "大后儿个8点30分")
        str = str.replacingOccurrences(of: "今晨半", with: "今晨7点30分")
        str = str.replacingOccurrences(of: "明晨半", with: "明晨7点30分")
        str = str.replacingOccurrences(of: "每晨半", with: "每晨7点30分")
        str = str.replacingOccurrences(of: "次晨半", with: "次晨7点30分")
        str = str.replacingOccurrences(of: "翌晨半", with: "翌晨7点30分")
        str = str.replacingOccurrences(of: "每早半", with: "每早7点30分")
        str = str.replacingOccurrences(of: "每晚半", with: "每晚9点30分")
        str = str.replacingOccurrences(of: "夜半半", with: "午夜0点30分")
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

        // 1. 结构化解析 1~99 中文复合数字（如：二十 -> 20, 二十六 -> 26, 十八 -> 18, 十五 -> 15, 十 -> 10）
        // 必须优先于小数与点五转换，彻底避免“二十点五/开到二十点五/开到十八点五”等口语中“二十/十八”因滞后转换导致破坏性输出“20点5”，
        // 进而在 parseScheduleTime 中将 20、18 误作为有效钟点小时、误触发 20:05/18:05 定时开机的重大缺陷 (v1.9.53 彻底根除)
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

        // 2. 温度与时间小数转换：匹配小数点五或点5（如“26点5” -> 26.5，“20点五” -> 20.5，“18点5” -> 18.5，“0点5” -> 0.5，“零点五度” -> 0.5度）
        // 排除后接“分/分钟”的钟点分表达（如“十点五分” -> 10点5分），彻底杜绝无上下文粗暴替换导致误判为倒计时或误判为定时开关机 (v1.9.47, v1.9.50, v1.9.52, v1.9.53)
        let decimalPointPattern = #"([零0一二两三四五六七八九\d]+)点(?:五|5)(?![分分钟])"#
        if let regex = try? NSRegularExpression(pattern: decimalPointPattern) {
            let ns = str as NSString
            let matches = regex.matches(in: str, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let prefix = ns.substring(with: m.range(at: 1))
                let range = Range(m.range, in: str)!
                str.replaceSubrange(range, with: "\(prefix).5")
            }
        }

        // 温度“X度半/X度五/X度5”与“半度”精确解析 (v1.9.49 闭环“二十六度半/26度半/开到25度半/一度半/两度半”及“升温半度/降半度/调低半度/全屋升高半度”, v1.9.51 闭环“二十六度五/26度5/开到25度5/制冷26度5/全屋26度5/调高一度五/升温1度5/降温一度五”)
        let degreeHalfOrFivePattern = #"([一二两三四五六七八九\d]+)度(?:半|五|5)"#
        if let regex = try? NSRegularExpression(pattern: degreeHalfOrFivePattern) {
            let ns = str as NSString
            let matches = regex.matches(in: str, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let digitStr = ns.substring(with: m.range(at: 1))
                let digitVal: Double = {
                    if let d = Double(digitStr) { return d }
                    return Double(digitMap[digitStr.first ?? " "] ?? 0)
                }()
                let range = Range(m.range, in: str)!
                str.replaceSubrange(range, with: "\(formatTemp(digitVal + 0.5))度")
            }
        }
        str = str.replacingOccurrences(of: "半度", with: "0.5度")
        str = str.replacingOccurrences(of: "五分度", with: "0.5度")

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
