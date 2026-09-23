import Foundation
import Combine
import SwiftUI
import WidgetKit
import UserNotifications
import ServiceManagement
import UniformTypeIdentifiers
import HaierACCore

/// 手动添加的设备（持久化到 UserDefaults）
struct ManualDevice: Identifiable, Codable, Hashable {
    let deviceId: String
    var name: String
    var id: String { deviceId }
}

/// 本地调度任务（定时/倒计时）：到点后向指定设备发送属性指令
/// 注意：本地调度仅在 App 运行时生效（菜单栏常驻/开机自启时通常满足）；
/// 任务不落云端，App 退出/睡眠期间到点的任务会顺延到下次唤醒补发。
struct ScheduledAction: Identifiable, Codable, Hashable {
    var id = UUID()
    /// 显示名称（如「晚上 10 点关机」）
    var name: String
    var deviceId: String
    var attrName: String
    /// 属性显示名（UI 展示用）
    var attrDesc: String
    /// 属性值（JSON 编码，AttrValue 不可直接 Codable）
    var attrValueJSON: Data
    /// 触发时刻（绝对时间；重复任务时为下一次触发时刻）
    var fireDate: Date
    /// 是否每天重复
    var repeatsDaily: Bool = false
    /// 按星期重复：Calendar weekday（1=周日…7=周六）。
    /// 非空时优先于 repeatsDaily；空 + 非 daily = 一次性任务
    var repeatWeekdays: [Int] = []
    var enabled: Bool = true

    var attrValue: AttrValue? {
        AttrValueCodec.decode(attrValueJSON)
    }

    static func valueJSON(_ value: AttrValue) -> Data? {
        AttrValueCodec.encode(value)
    }

    /// 重复规则的中文描述（如「每天」「每周一三五」），一次性返回 nil
    var repeatLabel: String? {
        if !repeatWeekdays.isEmpty {
            let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            let days = repeatWeekdays.sorted().map { names[max(0, min($0 - 1, 6))] }
            if days.count == 7 { return "每天" }
            return "每周" + days.joined()
        }
        if repeatsDaily { return "每天" }
        return nil
    }
}

/// 智能睡眠温阶节点
struct SleepStage: Identifiable, Codable, Hashable {
    var id = UUID()
    /// 阶段名称（如“入睡舒适”、“深睡呵护”、“熟睡恒温”）
    var name: String
    /// 从启动时刻开始经过的分钟数（如 0, 120, 300, 480）
    var afterMinutes: Int
    /// 目标温度（°C）
    var targetTemperature: Double
    /// 建议风速（如“微风”、“自动”）
    var windSpeed: String = "微风"
    /// 动作完成后是否保持开机（阶段为关机时设为 false）
    var powerOn: Bool = true

    var timeLabel: String {
        if afterMinutes == 0 { return "立即生效" }
        if afterMinutes >= 60 && afterMinutes % 60 == 0 {
            return "\(afterMinutes / 60)小时后"
        } else if afterMinutes >= 60 {
            return String(format: "%.1f小时后", Double(afterMinutes) / 60.0)
        } else {
            return "\(afterMinutes)分钟后"
        }
    }
}

/// 智能睡眠温阶曲线配置
struct SleepCurveConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var desc: String
    var icon: String
    var stages: [SleepStage]
    var isCustom: Bool = false

    static let standard = SleepCurveConfig(
        name: "标准舒适",
        desc: "入睡25°C清爽易眠，深睡阶梯升温防着凉，早晨自动关机",
        icon: "moon.stars.fill",
        stages: [
            SleepStage(name: "入睡舒适", afterMinutes: 0, targetTemperature: 25.0, windSpeed: "微风", powerOn: true),
            SleepStage(name: "深睡呵护", afterMinutes: 120, targetTemperature: 26.0, windSpeed: "微风", powerOn: true),
            SleepStage(name: "熟睡恒温", afterMinutes: 300, targetTemperature: 27.0, windSpeed: "微风", powerOn: true),
            SleepStage(name: "早晨关机", afterMinutes: 480, targetTemperature: 27.0, windSpeed: "微风", powerOn: false)
        ]
    )

    static let gentle = SleepCurveConfig(
        name: "轻柔呵护",
        desc: "适合老人与儿童，起始26°C平缓微调，全程微风静音",
        icon: "heart.fill",
        stages: [
            SleepStage(name: "温和入眠", afterMinutes: 0, targetTemperature: 26.0, windSpeed: "微风", powerOn: true),
            SleepStage(name: "深夜防凉", afterMinutes: 90, targetTemperature: 27.0, windSpeed: "微风", powerOn: true),
            SleepStage(name: "清晨熟睡", afterMinutes: 240, targetTemperature: 27.5, windSpeed: "微风", powerOn: true),
            SleepStage(name: "醒来关机", afterMinutes: 420, targetTemperature: 27.5, windSpeed: "微风", powerOn: false)
        ]
    )

    static let coolEco = SleepCurveConfig(
        name: "清爽省电",
        desc: "初期24°C迅速降温，随睡眠加深逐步回升至节能温度",
        icon: "leaf.fill",
        stages: [
            SleepStage(name: "快速降温", afterMinutes: 0, targetTemperature: 24.0, windSpeed: "强劲", powerOn: true),
            SleepStage(name: "入睡转柔", afterMinutes: 60, targetTemperature: 25.0, windSpeed: "微风", powerOn: true),
            SleepStage(name: "深度睡眠", afterMinutes: 180, targetTemperature: 26.0, windSpeed: "微风", powerOn: true),
            SleepStage(name: "节能恒温", afterMinutes: 360, targetTemperature: 27.0, windSpeed: "微风", powerOn: true)
        ]
    )

    static let allPresets: [SleepCurveConfig] = [.standard, .gentle, .coolEco]
}

/// 智能睡眠温阶执行点
struct SleepTrajectoryPoint: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date
    var stageIndex: Int
    var stageName: String
    var targetTemperature: Double
    var windSpeed: String
    var powerOn: Bool
    var indoorTemperature: Double?
    var indoorHumidity: Double? = nil
}

/// 智能睡眠结束原因
enum SleepEndReason: String, Codable {
    case completed = "计划完成"
    case userStopped = "手动停止"
    case overridden = "新计划覆盖"
}

/// 智能睡眠晨间唤醒过渡模式（v1.9.18）
enum SleepMorningTransitionMode: String, CaseIterable, Identifiable, Codable {
    case off = "直接关机"
    case gentleFan = "自然微风送风 (30分)"
    case comfortHold = "舒适恒温26.5°C (30分)"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .off: return "直接关机"
        case .gentleFan: return "自然送风"
        case .comfortHold: return "舒适恒温"
        }
    }
}

/// 智能就寝定时与睡前预冷配置（v1.9.19）
public struct BedtimeSchedule: Codable, Equatable {
    public var enabled: Bool = false
    public var hour: Int = 23         // 0..23 (默认 23:00)
    public var minute: Int = 0        // 0..59
    public var repeatWeekdays: [Int] = [2, 3, 4, 5, 6] // 默认工作日（周一至周五，1=周日）
    public var curveName: String = "标准舒适" // 目标曲线名称
    public var preCoolingMinutes: Int = 15 // 提前预冷分钟数，0 表示不预冷，默认 15 分钟

    public init(
        enabled: Bool = false,
        hour: Int = 23,
        minute: Int = 0,
        repeatWeekdays: [Int] = [2, 3, 4, 5, 6],
        curveName: String = "标准舒适",
        preCoolingMinutes: Int = 15
    ) {
        self.enabled = enabled
        self.hour = hour
        self.minute = minute
        self.repeatWeekdays = repeatWeekdays
        self.curveName = curveName
        self.preCoolingMinutes = preCoolingMinutes
    }

    public var timeLabel: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public var repeatLabel: String {
        if repeatWeekdays.count == 7 {
            return "每天"
        }
        let sorted = repeatWeekdays.sorted()
        if sorted == [2, 3, 4, 5, 6] {
            return "工作日"
        }
        if sorted == [1, 7] {
            return "周末"
        }
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let days = sorted.map { names[max(0, min($0 - 1, 6))] }
        return "每周 " + days.joined(separator: " ")
    }
}

/// 历史睡眠记录
struct SleepRecord: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var curveName: String
    var deviceId: String
    var deviceName: String
    var startedAt: Date
    var endedAt: Date
    var endReason: SleepEndReason
    var trajectory: [SleepTrajectoryPoint]

    var durationMinutes: Int {
        max(1, Int(endedAt.timeIntervalSince(startedAt) / 60))
    }

    var durationText: String {
        let mins = durationMinutes
        if mins < 60 {
            return "\(mins)分钟"
        } else {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)小时\(m)分" : "\(h)小时"
        }
    }
}

/// 正在执行的睡眠曲线会话
struct SleepSession: Codable, Equatable {
    var deviceId: String
    var startedAt: Date
    var curveConfig: SleepCurveConfig
    var currentStageIndex: Int
    var trajectory: [SleepTrajectoryPoint] = []
    var compensationOffset: Double = 0.0
    var lastCompensationCheck: Date? = nil

    /// 结合自适应补偿后的实际有效目标温度
    var effectiveTargetTemperature: Double? {
        guard let current = currentStage, current.powerOn else { return nil }
        return current.targetTemperature + compensationOffset
    }

    var currentStage: SleepStage? {
        guard currentStageIndex >= 0 && currentStageIndex < curveConfig.stages.count else { return nil }
        return curveConfig.stages[currentStageIndex]
    }

    var nextStage: SleepStage? {
        let next = currentStageIndex + 1
        guard next < curveConfig.stages.count else { return nil }
        return curveConfig.stages[next]
    }

    /// 下一阶段预计生效时刻
    var nextFireDate: Date? {
        guard let next = nextStage else { return nil }
        return startedAt.addingTimeInterval(TimeInterval(next.afterMinutes * 60))
    }
}

/// AttrValue ↔ JSON 安全编解码
///
/// ⚠️ 不要直接用 `JSONSerialization.data(withJSONObject: value.jsonValue)`：
/// 裸值（Int/Double/Bool/String）作为顶层时 NSJSONSerialization 抛的是
/// Objective-C 异常（非 Swift Error），`try?`/`try!` 都拦不住，会导致 App 崩溃。
/// 这里统一把值包进数组（合法顶层）再序列化，解码时兼容新旧两种格式。
enum AttrValueCodec {
    static func encode(_ value: AttrValue) -> Data? {
        try? JSONSerialization.data(withJSONObject: [value.jsonValue])
    }

    static func decode(_ data: Data) -> AttrValue? {
        // 新格式：数组包裹
        if let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
           let first = array.first {
            return AttrValue(first)
        }
        // 旧格式：裸值（历史上可能已落盘）
        if let any = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) {
            return AttrValue(any)
        }
        return nil
    }
}

/// 应用主状态模型
@MainActor
final class AppModel: ObservableObject {
    /// 全局单例（AppDelegate / 窗口 / 菜单栏共享同一实例）
    static let shared = AppModel()

    enum Phase: Equatable {
        case loggedOut
        case connecting
        case ready
        case error(String)
    }

    @Published var phase: Phase = .loggedOut
    @Published var phone: String = ""
    @Published var password: String = ""
    @Published var loginError: String? = nil
    @Published var devices: [DeviceInfo] = []
    @Published var attributes: [String: [String: DeviceAttribute]] = [:]  // deviceId -> attrName -> attr
    @Published var gatewayConnected = false
    /// 主题模式（跟随系统/浅色/深色），持久化
    @Published var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
        }
    }

    // MARK: - 设备发现与手动添加

    /// 是否正在扫描局域网
    @Published var isDiscovering = false
    /// 最近一次发现结果
    @Published var discoveredDevices: [DiscoveredDevice] = []
    /// 手动添加的设备（持久化）
    @Published var manualDevices: [ManualDevice] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(manualDevices) {
                UserDefaults.standard.set(data, forKey: "manualDevices")
            }
        }
    }
    /// 开机自启开关（持久化）
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }

    // MARK: - 操作反馈（U4）

    /// 最近一次操作的结果提示（主窗口/菜单栏面板显示 toast）
    struct OperationNotice: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    @Published var operationNotice: OperationNotice?
    /// 待确认的操作（发送后等待网关回读）
    private var pendingConfirm: (deviceId: String, name: String, expected: AttrValue)?

    // MARK: - 菜单栏实时温度（v1.4）

    /// 是否在菜单栏图标旁显示当前温度（持久化）
    @Published var menuBarShowTemperature: Bool {
        didSet {
            UserDefaults.standard.set(menuBarShowTemperature, forKey: "menuBarShowTemperature")
        }
    }
    /// 菜单栏温度取自哪台设备（nil = 第一台设备）
    @Published var menuBarDeviceId: String?

    /// 识别“室内温度”属性：可读、数值型，且不是目标/设定温度。
    /// 优先名称含 indoor/室内/环境 的属性，否则回退任意温度类属性。
    static func indoorTemperatureAttribute(in attrs: [String: DeviceAttribute]) -> DeviceAttribute? {
        let tempAttrs = attrs.values.filter { attr in
            guard attr.readable, attr.value != nil, attr.doubleValue != nil else { return false }
            let n = attr.name.lowercased()
            let d = attr.desc.lowercased()
            // 排除目标温度/设定温度（target/set/目标/设定）
            let isTarget = n.contains("target") || n.contains("set") || d.contains("目标") || d.contains("设定")
            guard !isTarget else { return false }
            // 温度类：名称含 temp/temperature/温度/环境
            return n.contains("temp") || d.contains("温度") || d.contains("环境")
        }
        if tempAttrs.isEmpty { return nil }
        // 优先“室内/环境温度”
        if let indoor = tempAttrs.first(where: {
            let n = $0.name.lowercased()
            let d = $0.desc.lowercased()
            return n.contains("indoor") || n.contains("room") || d.contains("室内") || d.contains("环境")
        }) {
            return indoor
        }
        return tempAttrs.sorted { $0.desc < $1.desc }.first
    }

    /// 识别“室内湿度”属性：可读、数值型，名称/描述含湿度/humidity。
    /// 设备无湿度传感器时返回 nil（UI 自动隐藏）。
    static func indoorHumidityAttribute(in attrs: [String: DeviceAttribute]) -> DeviceAttribute? {
        attrs.values.first { attr in
            guard attr.readable, attr.value != nil, attr.doubleValue != nil else { return false }
            let n = attr.name.lowercased()
            let d = attr.desc.lowercased()
            return n.contains("humidity") || n.contains("humid") || d.contains("湿度")
        }
    }

    /// 当前菜单栏温度文案（如 "26.0°"），无数据时返回 nil
    var menuBarTemperatureText: String? {
        guard menuBarShowTemperature, let deviceId = menuBarDeviceId ?? devices.first?.id,
              let attr = Self.indoorTemperatureAttribute(in: attributes[deviceId] ?? [:]),
              let value = attr.doubleValue else { return nil }
        return String(format: "%.0f°", value)
    }

    // MARK: - 本地调度（定时/倒计时，v1.4）

    /// 智能睡眠温阶会话（持久化到 UserDefaults，v1.9.6）
    @Published var activeSleepSession: SleepSession? {
        didSet {
            if let activeSleepSession, let data = try? JSONEncoder().encode(activeSleepSession) {
                UserDefaults.standard.set(data, forKey: "activeSleepSession")
            } else {
                UserDefaults.standard.removeObject(forKey: "activeSleepSession")
            }
        }
    }

    /// 用户自定义睡眠温阶曲线（持久化到 UserDefaults，v1.9.7）
    @Published var customSleepCurves: [SleepCurveConfig] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(customSleepCurves) {
                UserDefaults.standard.set(data, forKey: "customSleepCurves")
            }
        }
    }

    /// 所有可用睡眠曲线（内置预设 + 用户自定义）
    var allSleepCurves: [SleepCurveConfig] {
        SleepCurveConfig.allPresets + customSleepCurves
    }

    /// 睡眠模式夜间熄屏与静音联动（默认开启，v1.9.12）
    @Published var sleepNightDimming: Bool = true {
        didSet {
            UserDefaults.standard.set(sleepNightDimming, forKey: "sleepNightDimming")
        }
    }

    // MARK: - 空调滤网健康监测与自清洁保养 (v1.9.21)

    /// 累计开机运行分钟数 (持久化，向下兼容)
    @Published var filterAccumulatedMinutes: Int = 0 {
        didSet {
            UserDefaults.standard.set(filterAccumulatedMinutes, forKey: "filterAccumulatedMinutes")
        }
    }

    /// 上次滤网清洗重置日期 (向下兼容)
    @Published var lastFilterCleanedDate: Date? {
        didSet {
            UserDefaults.standard.set(lastFilterCleanedDate, forKey: "lastFilterCleanedDate")
        }
    }

    /// 是否展示滤网保养与自清洁弹窗 (支持菜单栏/外部直接路由呼出)
    @Published public var showFilterCareSheet: Bool = false

    /// 各设备独立滤网累计开机运行分钟数 [deviceId: minutes]
    @Published var deviceFilterMinutes: [String: Int] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(deviceFilterMinutes) {
                UserDefaults.standard.set(data, forKey: "deviceFilterMinutes")
            }
        }
    }

    /// 各设备上次清洗滤网日期 [deviceId: Date]
    @Published var deviceFilterCleanedDates: [String: Date] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(deviceFilterCleanedDates) {
                UserDefaults.standard.set(data, forKey: "deviceFilterCleanedDates")
            }
        }
    }

    /// 获取指定设备的滤网累计运行分钟数（基于空气动力学等效工时）
    public func filterAccumulatedMinutes(for deviceId: String) -> Int {
        if let minutes = deviceFilterMinutes[deviceId] {
            return minutes
        }
        let primaryId = devices.first?.id ?? manualDevices.first?.deviceId
        if primaryId == deviceId {
            return filterAccumulatedMinutes
        }
        return 0
    }

    /// 获取指定设备的上次滤网清洗日期
    public func lastFilterCleanedDate(for deviceId: String) -> Date? {
        if let date = deviceFilterCleanedDates[deviceId] {
            return date
        }
        let primaryId = devices.first?.id ?? manualDevices.first?.deviceId
        if primaryId == deviceId {
            return lastFilterCleanedDate
        }
        return nil
    }

    /// 指定设备的滤网清洁度百分比 (0 ~ 100%)，基于 250 小时 (15,000 分钟) 建议保养周期
    public func filterCleanlinessPercentage(for deviceId: String) -> Int {
        let maxMinutes = 250 * 60
        let minutes = filterAccumulatedMinutes(for: deviceId)
        let remaining = max(0, maxMinutes - minutes)
        return Int(Double(remaining) / Double(maxMinutes) * 100.0)
    }

    /// 全局综合最低滤网清洁度百分比 (0 ~ 100%)
    var filterCleanlinessPercentage: Int {
        let allIds = devices.map(\.id) + manualDevices.map(\.deviceId)
        guard !allIds.isEmpty else {
            let maxMinutes = 250 * 60
            let remaining = max(0, maxMinutes - filterAccumulatedMinutes)
            return Int(Double(remaining) / Double(maxMinutes) * 100.0)
        }
        let percentages = allIds.map { filterCleanlinessPercentage(for: $0) }
        return percentages.min() ?? 100
    }

    /// 重置滤网保养计时 (支持指定设备，默认主设备)
    func resetFilterMaintenance(for deviceId: String? = nil) {
        let primaryId = devices.first?.id ?? manualDevices.first?.deviceId ?? ""
        let targetId = deviceId ?? primaryId
        if !targetId.isEmpty {
            deviceFilterMinutes[targetId] = 0
            deviceFilterCleanedDates[targetId] = Date()
        }
        if targetId == primaryId || targetId.isEmpty {
            filterAccumulatedMinutes = 0
            lastFilterCleanedDate = Date()
        }

        let devName = devices.first(where: { $0.id == targetId })?.deviceName ??
                      manualDevices.first(where: { $0.deviceId == targetId })?.name ?? "海尔空调"
        operationNotice = OperationNotice(text: "🧼 \(devName) 滤网运行计时已重置，洁净度恢复 100%", isError: false)
    }

    /// 计算空气动力学与冷凝水湿度多维滤网负荷衰减系数
    public func calculateFilterWearFactor(
        mode: String,
        targetTemp: Double,
        indoorTemp: Double?,
        windSpeed: String
    ) -> Double {
        // 1. 风量通量因子（高速风量通过滤网单位时间截留更多浮尘颗粒）
        let windFactor: Double
        let speed = windSpeed.lowercased()
        if speed.contains("强力") || speed.contains("turbo") || speed.contains("超强") {
            windFactor = 1.70
        } else if speed.contains("高") || speed.contains("high") {
            windFactor = 1.35
        } else if speed.contains("中") || speed.contains("medium") || speed.contains("mid") {
            windFactor = 1.00
        } else if speed.contains("低") || speed.contains("low") {
            windFactor = 0.80
        } else if speed.contains("微") || speed.contains("静") || speed.contains("quiet") || speed.contains("mute") {
            windFactor = 0.60
        } else {
            windFactor = 1.00 // 自动风速默认基准
        }

        // 2. 冷凝结露与环境潮湿附着因子（制冷/除湿蒸发器凝露使滤网更易吸附粉尘并滋生微生物）
        let modeFactor: Double
        let m = mode.lowercased()
        if m == "0" || m.contains("制冷") || m.contains("cool") {
            if let indoor = indoorTemp, indoor > targetTemp {
                modeFactor = 1.35
            } else {
                modeFactor = 1.20
            }
        } else if m == "2" || m.contains("除湿") || m.contains("dehum") {
            modeFactor = 1.30
        } else if m == "4" || m.contains("制热") || m.contains("heat") {
            modeFactor = 1.05
        } else if m == "6" || m.contains("送风") || m.contains("fan") {
            modeFactor = 0.85
        } else {
            modeFactor = 1.00
        }

        return max(0.5, min(3.0, windFactor * modeFactor))
    }

    /// 累加特定设备的滤网运行时间（结合空气动力学负荷系数折算等效工时）
    func accumulateFilterMinutes(for deviceId: String, minutes: Int, wearFactor: Double = 1.0) {
        let current = filterAccumulatedMinutes(for: deviceId)
        let effectiveMinutes = max(1, Int(round(Double(minutes) * wearFactor)))
        let updated = current + effectiveMinutes
        deviceFilterMinutes[deviceId] = updated
        let primaryId = devices.first?.id ?? manualDevices.first?.deviceId
        if deviceId == primaryId {
            filterAccumulatedMinutes = updated
        }
        checkFilterHealthAlert(deviceId: deviceId, minutes: updated)
    }

    private var lastFilterAlertDates: [String: Date] = [:]

    private func checkFilterHealthAlert(deviceId: String, minutes: Int) {
        let maxMinutes = 250 * 60
        let percentage = Int(Double(max(0, maxMinutes - minutes)) / Double(maxMinutes) * 100.0)
        guard percentage <= 20 else { return }

        let lastAlert = lastFilterAlertDates[deviceId]
        if let last = lastAlert, Date().timeIntervalSince(last) < 7 * 86400 {
            return
        }
        lastFilterAlertDates[deviceId] = Date()

        let devName = devices.first(where: { $0.id == deviceId })?.deviceName ??
                      manualDevices.first(where: { $0.deviceId == deviceId })?.name ?? "海尔空调"
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 滤网建议清洗保养"
        content.body = "「\(devName)」滤网综合洁净度已降至 \(percentage)%，积尘可能会导致风阻增大并增加用电负荷，建议拆下水洗并晾干。"
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "filter-health-alert-\(deviceId)",
            content: content,
            trigger: nil
        )
        Task {
            try? await UNUserNotificationCenter.current().add(req)
        }
    }

    // MARK: - 蒸发器 56°C 高温自清洁生命周期全局管理 (v1.9.21)

    @Published public var isSelfCleaningActive: Bool = false
    @Published public var selfCleaningRemainingSeconds: Int = 0
    @Published public var selfCleaningDeviceId: String? = nil
    private var selfCleaningTask: Task<Void, Never>?

    /// 启动 56°C 高温除菌自清洁托管程序
    public func startSelfCleaning(deviceId: String) {
        if isSelfCleaningActive {
            stopSelfCleaning()
        }

        let devName = devices.first(where: { $0.id == deviceId })?.deviceName ??
                      manualDevices.first(where: { $0.deviceId == deviceId })?.name ?? "海尔空调"

        // 尝试下发海尔标准自清洁控制指令
        let attrs = attributes[deviceId] ?? [:]
        for key in ["selfCleaningStatus", "cleanStatus", "pm25CleanStatus", "sterilizationStatus"] {
            if let attr = attrs[key], attr.writable {
                sendAttribute(key, value: .bool(true), deviceId: deviceId)
            }
        }

        selfCleaningDeviceId = deviceId
        isSelfCleaningActive = true
        selfCleaningRemainingSeconds = 1200 // 20分钟

        selfCleaningTask?.cancel()
        selfCleaningTask = Task { @MainActor [weak self] in
            while let self = self, self.isSelfCleaningActive && self.selfCleaningRemainingSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                self.selfCleaningRemainingSeconds -= 1
            }
            guard let self = self, self.isSelfCleaningActive else { return }
            self.isSelfCleaningActive = false
            self.selfCleaningRemainingSeconds = 0
            self.operationNotice = OperationNotice(text: "🧼 \(devName) 蒸发器 56°C 高温除菌自清洁已完成", isError: false)

            let content = UNMutableNotificationContent()
            content.title = "✅ 蒸发器自清洁完成"
            content.body = "\(devName) 56°C 高温自清洁程序已圆满完成，蒸发器翅片已烘干除菌，空气洁净清新。"
            content.sound = .default
            let req = UNNotificationRequest(
                identifier: "self-cleaning-finished-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(req)
        }

        operationNotice = OperationNotice(text: "已启动「\(devName)」56°C 高温自清洁（约20分钟）", isError: false)
    }

    /// 中止自清洁托管程序
    public func stopSelfCleaning() {
        guard isSelfCleaningActive else { return }
        if let devId = selfCleaningDeviceId {
            let attrs = attributes[devId] ?? [:]
            for key in ["selfCleaningStatus", "cleanStatus", "pm25CleanStatus", "sterilizationStatus"] {
                if let attr = attrs[key], attr.writable {
                    sendAttribute(key, value: .bool(false), deviceId: devId)
                }
            }
        }
        isSelfCleaningActive = false
        selfCleaningRemainingSeconds = 0
        selfCleaningTask?.cancel()
        selfCleaningTask = nil
        operationNotice = OperationNotice(text: "已退出自清洁模式", isError: false)
    }

    // MARK: - 睡眠自然环境音与晨间音律助眠联动 (v1.9.20)

    /// 是否开启睡眠自然白噪音助眠
    @Published var sleepAmbientSoundEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(sleepAmbientSoundEnabled, forKey: "sleepAmbientSoundEnabled")
        }
    }

    /// 助眠白噪音类型 (春夜细雨/海风浪涌/森林微风/夏夜静谧/清晨林鸟)
    @Published var sleepAmbientSoundType: AmbientSoundType = .springRain {
        didSet {
            UserDefaults.standard.set(sleepAmbientSoundType.rawValue, forKey: "sleepAmbientSoundType")
        }
    }

    /// 助眠白噪音音量 (0.0 ~ 1.0)
    @Published var sleepAmbientSoundVolume: Float = 0.5 {
        didSet {
            UserDefaults.standard.set(sleepAmbientSoundVolume, forKey: "sleepAmbientSoundVolume")
            AmbientSoundEngine.shared.volume = sleepAmbientSoundVolume
        }
    }

    /// 进入深睡阶段后自然声音自动淡出 (默认开启)
    @Published var sleepAmbientAutoFadeOut: Bool = true {
        didSet {
            UserDefaults.standard.set(sleepAmbientAutoFadeOut, forKey: "sleepAmbientAutoFadeOut")
        }
    }

    /// 清晨唤醒伴随自然林鸟音律 (默认开启)
    @Published var sleepMorningWakeChime: Bool = true {
        didSet {
            UserDefaults.standard.set(sleepMorningWakeChime, forKey: "sleepMorningWakeChime")
        }
    }

    /// 智能睡眠阶段切换免打扰模式（默认开启，v1.9.13）
    /// 开启后夜间温阶自动推进时静默下发指令，不发送 macOS 系统横幅与提示音，防止惊醒用户
    @Published var sleepNotificationDND: Bool = true {
        didSet {
            UserDefaults.standard.set(sleepNotificationDND, forKey: "sleepNotificationDND")
        }
    }

    /// 智能睡眠室内温差自适应补偿（默认开启，v1.9.17）
    /// 根据实测室温动态微调 ±1°C，防止夜间过冷受凉或闷热
    @Published var sleepAdaptiveCompensation: Bool = true {
        didSet {
            UserDefaults.standard.set(sleepAdaptiveCompensation, forKey: "sleepAdaptiveCompensation")
        }
    }

    /// 智能睡眠温湿度健康双控守护（默认开启，v1.9.19）
    /// 睡眠期间实时监测室内相对湿度，过湿时联动舒适微调控湿，干燥时平缓风速，守护夜间呼吸道
    @Published var sleepHumidityGuard: Bool = true {
        didSet {
            UserDefaults.standard.set(sleepHumidityGuard, forKey: "sleepHumidityGuard")
        }
    }

    /// 定时就寝自动入眠与睡前预冷配置（持久化到 UserDefaults，v1.9.19）
    @Published var bedtimeSchedule: BedtimeSchedule = BedtimeSchedule() {
        didSet {
            if let data = try? JSONEncoder().encode(bedtimeSchedule) {
                UserDefaults.standard.set(data, forKey: "bedtimeSchedule")
            }
            wakeScheduler()
        }
    }

    private var lastPrecooledDateKey: String? {
        get { UserDefaults.standard.string(forKey: "bedtime_last_precool_key") }
        set { UserDefaults.standard.set(newValue, forKey: "bedtime_last_precool_key") }
    }
    private var lastBedtimeDateKey: String? {
        get { UserDefaults.standard.string(forKey: "bedtime_last_bedtime_key") }
        set { UserDefaults.standard.set(newValue, forKey: "bedtime_last_bedtime_key") }
    }

    /// 晨间唤醒平滑过渡模式（持久化到 UserDefaults，默认自然送风30分钟，v1.9.18）
    @Published var sleepMorningTransition: SleepMorningTransitionMode = .gentleFan {
        didSet {
            UserDefaults.standard.set(sleepMorningTransition.rawValue, forKey: "sleepMorningTransition")
        }
    }

    /// 睡眠温阶历史记录（持久化到 UserDefaults，最多保留50条，v1.9.16）
    @Published var sleepHistory: [SleepRecord] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(sleepHistory) {
                UserDefaults.standard.set(data, forKey: "sleepHistoryRecords")
            }
        }
    }

    /// 调度任务列表（持久化到 UserDefaults）
    @Published var scheduledActions: [ScheduledAction] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(scheduledActions) {
                UserDefaults.standard.set(data, forKey: "scheduledActions")
            }
        }
    }
    private var schedulerTask: Task<Void, Never>?
    private var lastMinuteSampleDate: Date?

    /// 周期性能耗采样积分与滤网运行时长累加 (全屋多设备并发动力学积分，v1.9.21)
    private func accumulateMinuteTick() {
        let now = Date()
        guard let last = lastMinuteSampleDate else {
            lastMinuteSampleDate = now
            return
        }
        let elapsed = now.timeIntervalSince(last)
        // 采样防抖：未满 45 秒暂不结算，避免快速调度抖动
        if elapsed < 45 {
            return
        }
        lastMinuteSampleDate = now

        // 限制单次流逝时间最大 300 秒，兼顾短时睡眠唤醒能量补偿与异常超长休眠截断
        let effectiveElapsed = min(elapsed, 300.0)
        let elapsedMinutes = max(1, Int(round(effectiveElapsed / 60.0)))

        var samples: [EnergyAnalyticsEngine.DeviceEnergySample] = []
        let allDevices = devices.map { (id: $0.id, name: $0.deviceName) } +
            manualDevices.map { (id: $0.deviceId, name: $0.name) }

        for dev in allDevices {
            let attrs = attributes[dev.id] ?? [:]
            let isPowerOn = attrs["onOffStatus"]?.boolValue ?? false
            let mode = attrs["operationMode"]?.stringValue ?? "0"
            let targetTemp = attrs["targetTemperature"]?.doubleValue ?? 26.0
            let indoorTemp = currentIndoorTemperature(for: dev.id)
            let windSpeed = attrs["windSpeed"]?.stringValue ?? "微风"

            if isPowerOn {
                let wearFactor = calculateFilterWearFactor(
                    mode: mode,
                    targetTemp: targetTemp,
                    indoorTemp: indoorTemp,
                    windSpeed: windSpeed
                )
                accumulateFilterMinutes(for: dev.id, minutes: elapsedMinutes, wearFactor: wearFactor)
            }

            samples.append(
                EnergyAnalyticsEngine.DeviceEnergySample(
                    deviceId: dev.id,
                    isPowerOn: isPowerOn,
                    modeCode: mode,
                    targetTemp: targetTemp,
                    indoorTemp: indoorTemp,
                    windSpeed: windSpeed
                )
            )
        }

        EnergyAnalyticsEngine.shared.accumulateSample(
            deviceSamples: samples,
            elapsedSeconds: effectiveElapsed
        )
    }

    /// 启动调度（登录/恢复会话成功后调用；App 退出前持续运行）。
    /// 优化：按下一任务触发时刻精确休眠，并保证每 60 秒定期累积能耗、滤网与定时器。
    func startScheduler() {
        guard schedulerTask == nil else { return }
        if let data = UserDefaults.standard.data(forKey: "scheduledActions"),
           let saved = try? JSONDecoder().decode([ScheduledAction].self, from: data) {
            scheduledActions = saved
        }
        schedulerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                self.fireDueActions()
                self.checkSleepCurveSession()
                self.checkBedtimeSchedule()
                self.accumulateMinuteTick()
                // 计算到下一个待触发任务的时间（封顶 60 秒，保证每分钟精确累积能耗与滤网工时）
                let now = Date()
                var candidates: [Date] = self.scheduledActions
                    .filter { $0.enabled && $0.fireDate > now }
                    .map(\.fireDate)
                if let nextSleepFire = self.activeSleepSession?.nextFireDate, nextSleepFire > now {
                    candidates.append(nextSleepFire)
                }
                if let nextBedtimeCandidate = self.nextBedtimeCandidateDate(after: now), nextBedtimeCandidate > now {
                    candidates.append(nextBedtimeCandidate)
                }
                let nextFire = candidates.min() ?? now.addingTimeInterval(60)
                let delay = min(max(nextFire.timeIntervalSince(now), 1), 60)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    func stopScheduler() {
        schedulerTask?.cancel()
        schedulerTask = nil
    }

    /// 新增调度任务（fireDate 为绝对触发时刻；倒计时由调用方换算为 fireDate）
    func addScheduledAction(_ action: ScheduledAction) {
        // 去重：同设备同属性同触发时刻
        guard !scheduledActions.contains(where: {
            $0.deviceId == action.deviceId && $0.attrName == action.attrName && $0.fireDate == action.fireDate
        }) else { return }
        scheduledActions.append(action)
        AppLog.log("新增调度: \(action.name) @ \(action.fireDate)")
        requestNotificationPermission()  // 定时任务需要系统通知权限（用户拒绝则仅 toast 反馈）
        wakeScheduler()
    }

    func removeScheduledAction(_ action: ScheduledAction) {
        scheduledActions.removeAll { $0.id == action.id }
        wakeScheduler()
    }

    /// 更新已有调度任务（编辑模式；保留 id 与 enabled 状态）
    func updateScheduledAction(_ action: ScheduledAction) {
        guard let idx = scheduledActions.firstIndex(where: { $0.id == action.id }) else { return }
        scheduledActions[idx] = action
        AppLog.log("更新调度: \(action.name) @ \(action.fireDate)")
        wakeScheduler()
    }

    /// 启用/禁用调度任务（临时暂停，无需删除）
    func setScheduledActionEnabled(_ id: UUID, enabled: Bool) {
        guard let idx = scheduledActions.firstIndex(where: { $0.id == id }) else { return }
        scheduledActions[idx].enabled = enabled
        AppLog.log(enabled ? "启用调度: \(scheduledActions[idx].name)" : "暂停调度: \(scheduledActions[idx].name)")
        wakeScheduler()
    }

    /// 任务列表变化后唤醒调度器，立即按新时间重新休眠（不用等封顶延迟）
    private func wakeScheduler() {
        guard schedulerTask != nil else { return }
        stopScheduler()
        startScheduler()
    }

    /// 到点任务下发；重复任务按规则顺延（每天 / 按星期），一次性任务触发后删除
    private func fireDueActions() {
        let now = Date()
        let due = scheduledActions.filter { $0.enabled && $0.fireDate <= now }
        guard !due.isEmpty else { return }
        let calendar = Calendar.current
        for action in due {
            guard let value = action.attrValue else { continue }
            AppLog.log("调度触发: \(action.name) -> \(action.deviceId).\(action.attrName)=\(value.stringValue)")
            // 静默下发（不走操作反馈 toast，避免批量触发刷屏）
            gatewayHandle?.sendControl(deviceId: action.deviceId, attributes: [action.attrName: value.jsonValue], completion: nil)
            // 系统通知：让用户知道定时任务已执行（即使 App 在后台）
            Self.postScheduledActionNotification(action)

            guard let idx = scheduledActions.firstIndex(where: { $0.id == action.id }) else { continue }

            if !action.repeatWeekdays.isEmpty {
                // 按星期重复：保留原时刻的时:分，顺延到下一个匹配的星期
                let next = Self.nextFireDate(after: now, weekdays: action.repeatWeekdays, calendar: calendar)
                scheduledActions[idx].fireDate = next
            } else if action.repeatsDaily {
                // 每天重复：顺延 24h；积压多个周期时只推进到最近未来（补发一次）
                var next = calendar.date(byAdding: .day, value: 1, to: action.fireDate) ?? action.fireDate.addingTimeInterval(86400)
                while next <= now {
                    next = calendar.date(byAdding: .day, value: 1, to: next) ?? next.addingTimeInterval(86400)
                }
                scheduledActions[idx].fireDate = next
            } else {
                scheduledActions.removeAll { $0.id == action.id }  // 一次性任务：触发后删除
            }
        }
        wakeScheduler()  // 顺延/删除后重新计算休眠时间
    }

    /// 计算 after 之后（不含 after）第一个匹配 weekdays 的时刻，保留原 fireDate 的时:分
    private static func nextFireDate(after date: Date, weekdays: [Int], calendar: Calendar) -> Date {
        let fire = date
        var candidate = calendar.date(byAdding: .day, value: 1, to: fire) ?? fire.addingTimeInterval(86400)
        let maxAttempts = 14  // 星期集合最多覆盖 7 天，14 次必然命中
        for _ in 0..<maxAttempts {
            let weekday = calendar.component(.weekday, from: candidate)
            if weekdays.contains(weekday) {
                return candidate
            }
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86400)
        }
        return candidate
    }

    // MARK: - 定时就寝与睡前预冷调度（v1.9.19）

    /// 计算从 after 开始的下一个就寝目标时间
    func nextBedtimeDate(after date: Date) -> Date? {
        guard bedtimeSchedule.enabled, !bedtimeSchedule.repeatWeekdays.isEmpty else { return nil }
        let calendar = Calendar.current
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date),
                  let target = calendar.date(bySettingHour: bedtimeSchedule.hour, minute: bedtimeSchedule.minute, second: 0, of: day) else {
                continue
            }
            let weekday = calendar.component(.weekday, from: target)
            if bedtimeSchedule.repeatWeekdays.contains(weekday) && target > date {
                return target
            }
        }
        return nil
    }

    /// 计算下一个调度检查候选时刻（包含就寝时刻与预冷时刻）
    func nextBedtimeCandidateDate(after date: Date) -> Date? {
        guard bedtimeSchedule.enabled, !bedtimeSchedule.repeatWeekdays.isEmpty else { return nil }
        guard let nextBed = nextBedtimeDate(after: date) else { return nil }
        var dates = [nextBed]
        if bedtimeSchedule.preCoolingMinutes > 0 {
            let precool = nextBed.addingTimeInterval(-Double(bedtimeSchedule.preCoolingMinutes * 60))
            if precool > date {
                dates.append(precool)
            }
        }
        return dates.min()
    }

    /// 定时就寝与睡前预冷检查
    private func checkBedtimeSchedule() {
        guard bedtimeSchedule.enabled, !bedtimeSchedule.repeatWeekdays.isEmpty else { return }
        let now = Date()
        let calendar = Calendar.current
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"

        // 检查可能命中就寝的目标时间（覆盖今天与跨天明天）
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let target = calendar.date(bySettingHour: bedtimeSchedule.hour, minute: bedtimeSchedule.minute, second: 0, of: day) else {
                continue
            }
            let weekday = calendar.component(.weekday, from: target)
            guard bedtimeSchedule.repeatWeekdays.contains(weekday) else { continue }

            let triggerKey = "\(keyFormatter.string(from: target))_\(bedtimeSchedule.hour)_\(bedtimeSchedule.minute)"

            // 1. 睡前预冷检测 (在就寝前 preCoolingMinutes 到就寝时刻之间)
            let precoolMins = bedtimeSchedule.preCoolingMinutes
            if precoolMins > 0 {
                let precoolTime = target.addingTimeInterval(-Double(precoolMins * 60))
                if now >= precoolTime && now < target {
                    if lastPrecooledDateKey != triggerKey {
                        lastPrecooledDateKey = triggerKey
                        triggerBedtimePrecooling()
                    }
                }
            }

            // 2. 就寝时刻检测 (在就寝时刻到之后 15 分钟内)
            if now >= target && now < target.addingTimeInterval(900) {
                if lastBedtimeDateKey != triggerKey {
                    lastBedtimeDateKey = triggerKey
                    triggerBedtimeCurve()
                }
            }
        }
    }

    /// 执行睡前预冷
    private func triggerBedtimePrecooling() {
        guard activeSleepSession == nil else { return }
        guard let deviceId = devices.first?.id ?? manualDevices.first?.deviceId else { return }
        let curve = allSleepCurves.first(where: { $0.name == bedtimeSchedule.curveName }) ?? allSleepCurves.first ?? .standard
        let targetTemp = curve.stages.first?.targetTemperature ?? 25.0

        sendAttribute("onOffStatus", value: .bool(true), deviceId: deviceId)
        sendAttribute("operationMode", value: .string("0"), deviceId: deviceId) // 制冷模式
        sendAttribute("targetTemperature", value: .double(targetTemp), deviceId: deviceId)
        sendAttribute("windSpeed", value: .string("微风"), deviceId: deviceId)

        AppLog.log("定时就寝联动: 距离就寝还有 \(bedtimeSchedule.preCoolingMinutes) 分钟，已启动睡前预冷 (\(targetTemp)°C 微风)")
        Self.postSleepNotification(
            title: "🌙 睡前预冷已启动",
            body: "距离就寝还有 \(bedtimeSchedule.preCoolingMinutes) 分钟，已为您开启「\(curve.name)」预冷（\(String(format: "%.0f°C", targetTemp)) 微风），提前营造舒适入睡环境。",
            silent: false
        )
        operationNotice = OperationNotice(text: "已启动睡前预冷（\(String(format: "%.0f°C", targetTemp))）", isError: false)
    }

    /// 执行定时就寝睡眠温阶
    private func triggerBedtimeCurve() {
        guard let deviceId = devices.first?.id ?? manualDevices.first?.deviceId else { return }
        let curve = allSleepCurves.first(where: { $0.name == bedtimeSchedule.curveName }) ?? allSleepCurves.first ?? .standard
        startSleepCurve(curve: curve, deviceId: deviceId)

        AppLog.log("定时就寝联动: 到达预设就寝时间 \(bedtimeSchedule.timeLabel)，已自动开启「\(curve.name)」睡眠温阶")
        Self.postSleepNotification(
            title: "🌙 定时就寝已自动开启",
            body: "已达预设就寝时间 \(bedtimeSchedule.timeLabel)，已自动为您开启「\(curve.name)」智能睡眠温阶。",
            silent: false
        )
    }

    /// 一键启停智能睡眠温阶（全局快捷键 ⌃⌥S 或菜单栏/快捷指令调用）
    func toggleSleepCurve() {
        if activeSleepSession != nil {
            stopSleepCurve()
        } else {
            guard let deviceId = devices.first?.id ?? manualDevices.first?.deviceId else {
                operationNotice = OperationNotice(text: "未找到可用空调设备", isError: true)
                return
            }
            let curve = allSleepCurves.first(where: { $0.name == bedtimeSchedule.curveName }) ?? allSleepCurves.first ?? .standard
            startSleepCurve(curve: curve, deviceId: deviceId)
        }
    }

    // MARK: - 智能睡眠温阶调度（v1.9.6）

    /// 获取设备当前室内温度
    func currentIndoorTemperature(for deviceId: String) -> Double? {
        AppModel.indoorTemperatureAttribute(in: attributes[deviceId] ?? [:])?.doubleValue
    }

    /// 开启智能睡眠温阶
    func startSleepCurve(curve: SleepCurveConfig, deviceId: String) {
        // 若当前已有进行中的会话，将其归档为新计划覆盖
        if let existing = activeSleepSession {
            archiveSleepSession(existing, endReason: .overridden)
        }

        let now = Date()
        var session = SleepSession(
            deviceId: deviceId,
            startedAt: now,
            curveConfig: curve,
            currentStageIndex: 0
        )

        // 记录初始执行节点
        if let initialStage = curve.stages.first {
            let initialPoint = SleepTrajectoryPoint(
                timestamp: now,
                stageIndex: 0,
                stageName: initialStage.name,
                targetTemperature: initialStage.targetTemperature,
                windSpeed: initialStage.windSpeed,
                powerOn: initialStage.powerOn,
                indoorTemperature: currentIndoorTemperature(for: deviceId),
                indoorHumidity: AppModel.indoorHumidityAttribute(in: attributes[deviceId] ?? [:])?.doubleValue
            )
            session.trajectory.append(initialPoint)
        }

        self.activeSleepSession = session
        AppLog.log("开启智能睡眠: \(curve.name) 设备=\(deviceId)")

        // 立即执行第 0 阶段
        if let initialStage = curve.stages.first {
            applySleepStage(initialStage, deviceId: deviceId, curveName: curve.name)
        }

        // 联动夜间熄屏与静音
        if sleepNightDimming {
            applyNightQuietMode(deviceId: deviceId)
        }

        // 联动睡眠自然白噪音助眠
        if sleepAmbientSoundEnabled {
            AmbientSoundEngine.shared.play(type: sleepAmbientSoundType, fadeInDuration: 2.5)
        }

        requestNotificationPermission()
        let noticeText = sleepNightDimming ? "🌙 已启动「\(curve.name)」睡眠温阶（已熄灯静音）" : "🌙 已启动「\(curve.name)」睡眠温阶曲线"
        operationNotice = OperationNotice(text: noticeText, isError: false)
        wakeScheduler()
        writeWidgetSnapshot(force: true)
    }

    /// 执行夜间熄屏与微风静音联动
    private func applyNightQuietMode(deviceId: String) {
        let attrs = attributes[deviceId] ?? [:]
        // 1. 关闭机身屏显灯光
        if let light = attrs["lightStatus"], light.writable {
            sendAttribute("lightStatus", value: .bool(false), deviceId: deviceId)
            AppLog.log("智能睡眠联动: 已自动关闭空调机身指示灯")
        }
        // 2. 尝试关闭蜂鸣音/提示音（若设备支持）
        for key in ["soundStatus", "echoStatus", "beepStatus", "buzzerStatus", "voiceStatus"] {
            if let sound = attrs[key], sound.writable {
                sendAttribute(key, value: .bool(false), deviceId: deviceId)
                AppLog.log("智能睡眠联动: 已自动关闭蜂鸣提示音 (\(key))")
            }
        }
    }

    /// 停止智能睡眠温阶
    func stopSleepCurve() {
        guard let session = activeSleepSession else { return }
        AppLog.log("停止智能睡眠: \(session.curveConfig.name)")
        archiveSleepSession(session, endReason: .userStopped)
        self.activeSleepSession = nil

        // 停止自然环境音
        if AmbientSoundEngine.shared.isPlaying {
            AmbientSoundEngine.shared.stop(fadeOutDuration: 1.5)
        }

        operationNotice = OperationNotice(text: "已停止智能睡眠温阶", isError: false)
        wakeScheduler()
        writeWidgetSnapshot(force: true)
    }

    /// 检查并推进智能睡眠阶段
    private func checkSleepCurveSession() {
        guard let session = activeSleepSession else { return }
        let now = Date()
        let elapsedMinutes = Int(now.timeIntervalSince(session.startedAt) / 60)

        // 找出当前已到达的最晚阶段
        var highestStageIndex = session.currentStageIndex
        for (idx, stage) in session.curveConfig.stages.enumerated() {
            if stage.afterMinutes <= elapsedMinutes {
                highestStageIndex = max(highestStageIndex, idx)
            }
        }

        if highestStageIndex > session.currentStageIndex {
            // 若进入深睡阶段 (阶段索引 >= 1) 且开启深睡自动淡出，平滑淡出助眠音
            if highestStageIndex >= 1 && sleepAmbientAutoFadeOut && AmbientSoundEngine.shared.isPlaying {
                AmbientSoundEngine.shared.stop(fadeOutDuration: 25.0)
                AppLog.log("智能睡眠联动: 已进入深睡阶段，自然白噪音柔和淡出完毕")
            }

            // 推进到新阶段
            activeSleepSession?.currentStageIndex = highestStageIndex
            activeSleepSession?.compensationOffset = 0.0 // 新阶段开始时重置补偿偏移量
            activeSleepSession?.lastCompensationCheck = nil
            let stage = session.curveConfig.stages[highestStageIndex]
            AppLog.log("智能睡眠推进: [\(session.curveConfig.name)] 阶段 \(highestStageIndex + 1)/\(session.curveConfig.stages.count): \(stage.name)")
            applySleepStage(stage, deviceId: session.deviceId, curveName: session.curveConfig.name)

            // 追加阶段轨迹节点
            let point = SleepTrajectoryPoint(
                timestamp: Date(),
                stageIndex: highestStageIndex,
                stageName: stage.name,
                targetTemperature: stage.targetTemperature,
                windSpeed: stage.windSpeed,
                powerOn: stage.powerOn,
                indoorTemperature: currentIndoorTemperature(for: session.deviceId),
                indoorHumidity: AppModel.indoorHumidityAttribute(in: attributes[session.deviceId] ?? [:])?.doubleValue
            )
            activeSleepSession?.trajectory.append(point)

            // 如果该阶段为关机，则自动结束当前会话并进行晨间唤醒过渡处理
            if !stage.powerOn {
                AppLog.log("智能睡眠温阶计划结束，执行晨间唤醒过渡: \(sleepMorningTransition.rawValue)")
                handleMorningWakeTransition(deviceId: session.deviceId, curveName: session.curveConfig.name)
                if let finishedSession = activeSleepSession {
                    archiveSleepSession(finishedSession, endReason: .completed)
                }
                activeSleepSession = nil
            }
            writeWidgetSnapshot(force: true)
        } else if let active = activeSleepSession, (sleepAdaptiveCompensation || sleepHumidityGuard) {
            // 同一阶段内定期进行室内温湿度双控自适应补偿检测
            evaluateAdaptiveCompensation(for: active)
        }
    }

    // MARK: - 智能睡眠室内温差自适应补偿与温湿度守护（v1.9.17 / v1.9.19）

    /// 智能睡眠室内温差自适应补偿与温湿度守护检测
    private func evaluateAdaptiveCompensation(for session: SleepSession) {
        guard let currentStage = session.currentStage, currentStage.powerOn else { return }

        let now = Date()
        // 检查冷却时间：距上一次自适应评估至少间隔 10 分钟 (600s)
        if let lastCheck = session.lastCompensationCheck, now.timeIntervalSince(lastCheck) < 600 {
            return
        }

        // 阶段刚启动前 10 分钟不进行补偿，留给空调基础调温响应时间
        let elapsedMinutes = Int(now.timeIntervalSince(session.startedAt) / 60)
        let stageStartMinutes = currentStage.afterMinutes
        guard elapsedMinutes - stageStartMinutes >= 10 else {
            return
        }

        guard let indoorTemp = currentIndoorTemperature(for: session.deviceId) else {
            return
        }

        let baseTemp = currentStage.targetTemperature
        let delta = indoorTemp - baseTemp // 室内温度与阶段目标温度之差
        var newOffset = session.compensationOffset

        // 1. 防过冷保护：室温比目标还低 1.5°C 以上（如设 26°C，室温已降到 24.3°C），提高设定温度防止受凉
        if delta < -1.5 {
            newOffset = min(session.compensationOffset + 0.5, 1.0)
        }
        // 2. 防闷热保护：室温比目标高 2.0°C 以上（如设 26°C，室温依然有 28.2°C），适度下调
        else if delta > 2.0 {
            newOffset = max(session.compensationOffset - 0.5, -1.0)
        }
        // 3. 舒适区间平稳回归：室温在 ±0.8°C 舒适死区内，且已有补偿偏移，逐步回归基准温度
        else if abs(delta) <= 0.8 && session.compensationOffset != 0.0 {
            if session.compensationOffset > 0 {
                newOffset = max(session.compensationOffset - 0.5, 0.0)
            } else {
                newOffset = min(session.compensationOffset + 0.5, 0.0)
            }
        }

        // 4. 温湿度双控健康守护联动（v1.9.19）
        let indoorHum = AppModel.indoorHumidityAttribute(in: attributes[session.deviceId] ?? [:])?.doubleValue
        var humTag = ""

        if sleepHumidityGuard, let hum = indoorHum {
            // 湿度过高 (> 70%): 体感黏腻闷热，适度下调 0.5°C 舒爽控湿
            if hum > 70.0 && newOffset > -1.0 {
                newOffset = max(newOffset - 0.5, -1.0)
                humTag = " · 高湿控湿"
                AppLog.log("智能睡眠温湿度守护: 室内湿度 \(hum)% 偏高，微调降温促进舒爽控湿")
            }
            // 湿度过低 (< 40%): 环境干燥，微调上调 0.5°C 减轻空调抽湿，守护呼吸道
            else if hum < 40.0 && newOffset < 1.0 {
                newOffset = min(newOffset + 0.5, 1.0)
                humTag = " · 低湿柔护"
                AppLog.log("智能睡眠温湿度守护: 室内湿度 \(hum)% 偏干，微调升温减轻干燥")
            }
        }

        activeSleepSession?.lastCompensationCheck = now

        if newOffset != session.compensationOffset {
            activeSleepSession?.compensationOffset = newOffset
            let effectiveTemp = baseTemp + newOffset
            // 下发补偿微调温度
            sendAttribute("targetTemperature", value: .double(effectiveTemp), deviceId: session.deviceId)

            let sign = newOffset > 0 ? "+" : ""
            let offsetText = "\(sign)\(String(format: "%.1f", newOffset))°C"
            AppLog.log("智能睡眠温差自适应补偿: [\(session.curveConfig.name)] 阶段「\(currentStage.name)」室温=\(String(format: "%.1f", indoorTemp))°C，基准=\(baseTemp)°C，自适应微调 \(offsetText)\(humTag) -> 有效设定=\(effectiveTemp)°C")

            // 记录补偿轨迹点
            let point = SleepTrajectoryPoint(
                timestamp: now,
                stageIndex: session.currentStageIndex,
                stageName: "\(currentStage.name) (自适应 \(offsetText)\(humTag))",
                targetTemperature: effectiveTemp,
                windSpeed: currentStage.windSpeed,
                powerOn: true,
                indoorTemperature: indoorTemp,
                indoorHumidity: indoorHum
            )
            activeSleepSession?.trajectory.append(point)

            if !sleepNotificationDND {
                let humNotice = (humTag.isEmpty || indoorHum == nil) ? "" : "，室内湿度 \(String(format: "%.0f%%", indoorHum!))\(humTag)"
                Self.postSleepNotification(
                    title: "🌙 智能睡眠自适应守护",
                    body: "监测到室温 \(String(format: "%.1f°C", indoorTemp))\(humNotice)，已自动微调设定温度至 \(String(format: "%.1f°C", effectiveTemp))（\(offsetText)）"
                )
            }
            writeWidgetSnapshot(force: true)
        }
    }

    // MARK: - 智能睡眠历史记录管理（v1.9.16）

    /// 归档一次睡眠会话到历史记录
    func archiveSleepSession(_ session: SleepSession, endReason: SleepEndReason) {
        let devName = devices.first(where: { $0.id == session.deviceId })?.deviceName
            ?? manualDevices.first(where: { $0.deviceId == session.deviceId })?.name
            ?? "海尔空调"
        let record = SleepRecord(
            curveName: session.curveConfig.name,
            deviceId: session.deviceId,
            deviceName: devName,
            startedAt: session.startedAt,
            endedAt: Date(),
            endReason: endReason,
            trajectory: session.trajectory
        )
        // 插入最前，保留最近 50 条
        sleepHistory.insert(record, at: 0)
        if sleepHistory.count > 50 {
            sleepHistory = Array(sleepHistory.prefix(50))
        }
        AppLog.log("归档睡眠温阶记录: \(record.curveName), 原因: \(endReason.rawValue), 阶段数: \(record.trajectory.count)")
    }

    /// 删除单条睡眠历史记录
    func deleteSleepRecord(id: UUID) {
        sleepHistory.removeAll { $0.id == id }
        AppLog.log("删除睡眠历史记录: \(id)")
    }

    /// 清空全部睡眠历史记录
    func clearAllSleepHistory() {
        sleepHistory.removeAll()
        AppLog.log("清空所有睡眠历史记录")
    }

    // MARK: - 智能睡眠历史数据导出与分享（v1.9.19）

    /// 导出睡眠历史为标准 CSV 字符串（UTF-8 BOM，支持 Excel / Numbers 完美解析）
    func exportSleepHistoryCSV() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var csv = "\u{FEFF}" // UTF-8 BOM
        csv += "记录ID,方案名称,设备ID,设备名称,开始时间,结束时间,持续时长(分钟),结束原因,阶段序号,阶段名称,设定温度(°C),风速,开关状态,实测室温(°C),实测湿度(%)\n"

        for rec in sleepHistory {
            let startStr = formatter.string(from: rec.startedAt)
            let endStr = formatter.string(from: rec.endedAt)
            let baseFields = [
                rec.id.uuidString,
                rec.curveName,
                rec.deviceId,
                rec.deviceName,
                startStr,
                endStr,
                "\(rec.durationMinutes)",
                rec.endReason.rawValue
            ]

            if rec.trajectory.isEmpty {
                let row = (baseFields + ["", "", "", "", "", "", ""]).map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",")
                csv += row + "\n"
            } else {
                for pt in rec.trajectory {
                    let ptFields = [
                        "\(pt.stageIndex + 1)",
                        pt.stageName,
                        String(format: "%.1f", pt.targetTemperature),
                        pt.windSpeed,
                        pt.powerOn ? "开机" : "关机",
                        pt.indoorTemperature != nil ? String(format: "%.1f", pt.indoorTemperature!) : "",
                        pt.indoorHumidity != nil ? String(format: "%.0f", pt.indoorHumidity!) : ""
                    ]
                    let row = (baseFields + ptFields).map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",")
                    csv += row + "\n"
                }
            }
        }
        return csv
    }

    /// 保存睡眠历史 CSV 文件（打开系统原生保存面板）
    func exportSleepHistoryToCSVFile() {
        guard !sleepHistory.isEmpty else {
            operationNotice = OperationNotice(text: "暂无睡眠历史可供导出", isError: true)
            return
        }
        let csvContent = exportSleepHistoryCSV()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "HaierAC_SleepHistory_\(formatter.string(from: Date())).csv"

        let panel = NSSavePanel()
        panel.title = "导出睡眠历史数据"
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csvContent.write(to: url, atomically: true, encoding: .utf8)
                operationNotice = OperationNotice(text: "已导出睡眠历史 CSV 文件", isError: false)
            } catch {
                operationNotice = OperationNotice(text: "保存失败: \(error.localizedDescription)", isError: true)
            }
        }
    }

    /// 复制睡眠历史 CSV 至剪贴板
    func copySleepHistoryCSVToClipboard() {
        guard !sleepHistory.isEmpty else {
            operationNotice = OperationNotice(text: "暂无睡眠历史可供复制", isError: true)
            return
        }
        let csv = exportSleepHistoryCSV()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(csv, forType: .string)
        operationNotice = OperationNotice(text: "已复制 \(sleepHistory.count) 条睡眠历史 CSV 到剪贴板", isError: false)
    }

    /// 生成精美睡眠总结分享卡片并复制到剪贴板
    func copySleepSummaryCardToClipboard(record: SleepRecord) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let startStr = formatter.string(from: record.startedAt)
        let endStr = formatter.string(from: record.endedAt)

        var lines: [String] = []
        lines.append("╭─────────────────────────────────────────╮")
        lines.append("│ 🌙 海尔空调 · 智能睡眠健康报告            │")
        lines.append("├─────────────────────────────────────────┤")
        lines.append("│ 方案名称: \(record.curveName)")
        lines.append("│ 设备名称: \(record.deviceName)")
        lines.append("│ 运行状态: \(record.endReason.rawValue)")
        lines.append("│ 睡眠时长: \(record.durationText)")
        lines.append("│ 时间周期: \(startStr) ~ \(endStr)")
        if !record.trajectory.isEmpty {
            lines.append("├─────────────────────────────────────────┤")
            lines.append("│ 🌡️ 温阶历程轨迹:")
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            for pt in record.trajectory {
                let tStr = timeFormatter.string(from: pt.timestamp)
                var ptDesc = "│ • \(tStr) \(pt.stageName)"
                if pt.powerOn {
                    ptDesc += " -> \(String(format: "%.1f°C", pt.targetTemperature))"
                } else {
                    ptDesc += " -> 关机"
                }
                if let indoor = pt.indoorTemperature {
                    ptDesc += " (室温 \(String(format: "%.1f°C", indoor)))"
                }
                if let hum = pt.indoorHumidity {
                    ptDesc += " (湿度 \(String(format: "%.0f%%", hum)))"
                }
                lines.append(ptDesc)
            }
        }
        lines.append("╰─────────────────────────────────────────╯")
        let cardText = lines.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(cardText, forType: .string)
        operationNotice = OperationNotice(text: "已生成并复制「\(record.curveName)」睡眠报告卡片", isError: false)
    }

    // MARK: - 智能睡眠晨间唤醒平滑过渡（v1.9.18）

    /// 执行晨间唤醒平滑过渡处理
    private func handleMorningWakeTransition(deviceId: String, curveName: String) {
        switch sleepMorningTransition {
        case .off:
            // 直接关机
            sendAttribute("onOffStatus", value: .bool(false), deviceId: deviceId)
            Self.postSleepNotification(
                title: "🌙 智能睡眠已完成",
                body: "「\(curveName)」计划已达清晨唤醒时刻，空调已自动关机。",
                silent: sleepNotificationDND
            )

        case .gentleFan:
            // 切换为送风模式 + 微风，并设置 30 分钟后自动关机
            sendAttribute("onOffStatus", value: .bool(true), deviceId: deviceId)
            sendAttribute("operationMode", value: .string("2"), deviceId: deviceId) // 送风
            if let windAttr = attributes[deviceId]?["windSpeed"],
               case .list(let options) = windAttr.valueRange,
               let match = options.first(where: { $0.desc.contains("微风") || $0.desc.contains("静音") }) {
                sendAttribute("windSpeed", value: match.data, deviceId: deviceId)
            }
            scheduleMorningAutoOff(deviceId: deviceId, minutes: 30)
            Self.postSleepNotification(
                title: "🌅 晨间唤醒平滑过渡",
                body: "「\(curveName)」已平滑过渡至自然微风送风，30 分钟后将自动关机。",
                silent: sleepNotificationDND
            )

        case .comfortHold:
            // 保持开机，设定 26.5°C 恒温微风，并设置 30 分钟后自动关机
            sendAttribute("onOffStatus", value: .bool(true), deviceId: deviceId)
            sendAttribute("targetTemperature", value: .double(26.5), deviceId: deviceId)
            if let windAttr = attributes[deviceId]?["windSpeed"],
               case .list(let options) = windAttr.valueRange,
               let match = options.first(where: { $0.desc.contains("微风") || $0.desc.contains("静音") }) {
                sendAttribute("windSpeed", value: match.data, deviceId: deviceId)
            }
            scheduleMorningAutoOff(deviceId: deviceId, minutes: 30)
            Self.postSleepNotification(
                title: "🌅 晨间唤醒舒适恒温",
                body: "「\(curveName)」已平滑过渡至 26.5°C 舒适微风恒温，30 分钟后将自动关机。",
                silent: sleepNotificationDND
            )
        }

        // 联动清晨林鸟唤醒音律
        if sleepMorningWakeChime {
            AmbientSoundEngine.shared.play(type: .morningBirds, fadeInDuration: 12.0)
            AppLog.log("智能睡眠晨间唤醒联动: 播发清晨自然林鸟音律")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 分钟后自动淡出停止
                AmbientSoundEngine.shared.stop(fadeOutDuration: 10.0)
            }
        }
    }

    /// 晨间过渡自动延时关机调度
    private func scheduleMorningAutoOff(deviceId: String, minutes: Int) {
        let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        guard let valJSON = ScheduledAction.valueJSON(.bool(false)) else { return }
        let action = ScheduledAction(
            name: "晨间过渡自动关机 (\(minutes)分钟)",
            deviceId: deviceId,
            attrName: "onOffStatus",
            attrDesc: "开关",
            attrValueJSON: valJSON,
            fireDate: fireDate,
            repeatsDaily: false,
            repeatWeekdays: [],
            enabled: true
        )
        addScheduledAction(action)
    }

    /// 下发阶段指令并发送系统通知
    private func applySleepStage(_ stage: SleepStage, deviceId: String, curveName: String) {
        if !stage.powerOn {
            // 关机阶段统一交由 handleMorningWakeTransition 处理
            return
        } else {
            // 确保开机
            sendAttribute("onOffStatus", value: .bool(true), deviceId: deviceId)
            // 设温度
            sendAttribute("targetTemperature", value: .double(stage.targetTemperature), deviceId: deviceId)
            // 设风速（微风/静音）
            if let windAttr = attributes[deviceId]?["windSpeed"],
               case .list(let options) = windAttr.valueRange,
               let match = options.first(where: { $0.desc.contains(stage.windSpeed) || stage.windSpeed.contains($0.desc) }) {
                sendAttribute("windSpeed", value: match.data, deviceId: deviceId)
            }
            let tempDesc = String(format: "%.1f°C", stage.targetTemperature).replacingOccurrences(of: ".0°C", with: "°C")
            if !sleepNotificationDND {
                Self.postSleepNotification(
                    title: "🌙 智能睡眠【\(curveName)】",
                    body: "进入【\(stage.name)】阶段，已平滑调节至 \(tempDesc)（\(stage.windSpeed)）"
                )
            } else {
                AppLog.log("智能睡眠阶段推进 (免打扰静默): [\(curveName)] -> \(stage.name) (\(tempDesc))")
            }
        }
    }

    private static func postSleepNotification(title: String, body: String, silent: Bool = false) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if !silent {
            content.sound = .default
        }
        let request = UNNotificationRequest(
            identifier: "sleep-curve-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    // MARK: - 自定义睡眠曲线管理（v1.9.7）

    func addCustomSleepCurve(_ curve: SleepCurveConfig) {
        var newCurve = curve
        newCurve.isCustom = true
        customSleepCurves.append(newCurve)
        AppLog.log("新增自定义睡眠曲线: \(newCurve.name) (\(newCurve.stages.count) 个阶段)")
        operationNotice = OperationNotice(text: "已保存专属睡眠曲线「\(newCurve.name)」", isError: false)
    }

    func updateCustomSleepCurve(_ curve: SleepCurveConfig) {
        guard let idx = customSleepCurves.firstIndex(where: { $0.id == curve.id }) else { return }
        var updated = curve
        updated.isCustom = true
        customSleepCurves[idx] = updated
        AppLog.log("更新自定义睡眠曲线: \(updated.name)")
        operationNotice = OperationNotice(text: "已更新「\(updated.name)」", isError: false)

        // 如果当前正在运行该曲线，同步更新配置
        if activeSleepSession?.curveConfig.id == updated.id {
            activeSleepSession?.curveConfig = updated
        }
    }

    func deleteCustomSleepCurve(id: UUID) {
        guard let idx = customSleepCurves.firstIndex(where: { $0.id == id }) else { return }
        let name = customSleepCurves[idx].name
        // 如果当前运行的是被删除的曲线，停止运行
        if activeSleepSession?.curveConfig.id == id {
            stopSleepCurve()
        }
        customSleepCurves.remove(at: idx)
        AppLog.log("删除自定义睡眠曲线: \(name)")
        operationNotice = OperationNotice(text: "已删除曲线「\(name)」", isError: false)
    }

    // MARK: - 自定义睡眠曲线 JSON 导入与导出

    /// 将曲线导出为格式化 JSON 字符串
    func exportSleepCurveJSON(_ curve: SleepCurveConfig) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(curve),
              let jsonStr = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonStr
    }

    /// 导出所有自定义睡眠曲线为 JSON 数组字符串
    func exportAllCustomSleepCurvesJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(customSleepCurves),
              let jsonStr = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonStr
    }

    /// 从 JSON 字符串导入睡眠曲线（支持单个曲线对象或曲线数组）
    @discardableResult
    func importSleepCurves(from jsonString: String) throws -> [SleepCurveConfig] {
        let data = Data(jsonString.utf8)
        let decoder = JSONDecoder()

        var importedList: [SleepCurveConfig] = []

        if let list = try? decoder.decode([SleepCurveConfig].self, from: data) {
            importedList = list
        } else if let single = try? decoder.decode(SleepCurveConfig.self, from: data) {
            importedList = [single]
        } else {
            throw NSError(domain: "SleepCurveImport", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析睡眠曲线 JSON 格式，请检查内容是否有效。"])
        }

        var addedCount = 0
        for var curve in importedList {
            curve.id = UUID() // 赋予新 ID 避免与现有曲线碰撞
            curve.isCustom = true
            // 防止重名混乱
            let baseName = curve.name
            var uniqueName = baseName
            var counter = 1
            while allSleepCurves.contains(where: { $0.name == uniqueName }) {
                uniqueName = "\(baseName) (导入\(counter))"
                counter += 1
            }
            curve.name = uniqueName
            customSleepCurves.append(curve)
            addedCount += 1
        }

        AppLog.log("成功导入 \(addedCount) 套自定义睡眠曲线")
        operationNotice = OperationNotice(text: "成功导入 \(addedCount) 套睡眠曲线配置", isError: false)
        return importedList
    }

    /// 复制指定曲线的 JSON 到系统剪贴板
    func copyCurveJSONToClipboard(_ curve: SleepCurveConfig) {
        guard let jsonStr = exportSleepCurveJSON(curve) else {
            operationNotice = OperationNotice(text: "导出失败", isError: true)
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonStr, forType: .string)
        operationNotice = OperationNotice(text: "已复制「\(curve.name)」配置到剪贴板", isError: false)
    }

    /// 从系统剪贴板尝试导入曲线配置
    @discardableResult
    func importCurvesFromClipboard() -> Bool {
        guard let content = NSPasteboard.general.string(forType: .string), !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            operationNotice = OperationNotice(text: "剪贴板为空，无法导入", isError: true)
            return false
        }
        do {
            let imported = try importSleepCurves(from: content)
            return !imported.isEmpty
        } catch {
            operationNotice = OperationNotice(text: error.localizedDescription, isError: true)
            return false
        }
    }

    // MARK: - 定时任务系统通知（v1.8）

    /// 请求通知权限（首次添加定时任务时调用；拒绝后静默，仅靠 App 内 toast 反馈）
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 定时任务触发后发送系统通知（App 后台/菜单栏常驻时也能让用户感知）
    private static func postScheduledActionNotification(_ action: ScheduledAction) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "定时任务已执行"
        content.body = "\(action.name)（\(action.attrDesc)）"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "scheduled-\(action.id.uuidString)",
            content: content,
            trigger: nil  // 立即发送
        )
        center.add(request)
    }

    // MARK: - 温度历史曲线（v1.8）

    /// 单条温度采样
    struct TemperatureSample: Codable, Hashable, Identifiable {
        var timestamp: Date
        var temperature: Double
        var id: Date { timestamp }
    }

    /// 温度历史（按设备存储，持久化到 UserDefaults）
    @Published var temperatureHistory: [String: [TemperatureSample]] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(temperatureHistory) {
                UserDefaults.standard.set(data, forKey: "temperatureHistory")
            }
        }
    }
    /// 温度采样限频：5 分钟内最多记一条（属性推送可能每秒多次）
    private var lastSampleAt: [String: Date] = [:]
    /// 历史窗口：保留最近 24 小时
    private let historyWindow: TimeInterval = 24 * 3600

    /// 属性推送时调用：按设备记录温度采样（限频 + 窗口裁剪）
    func recordTemperatureSample(deviceId: String, temperature: Double) {
        let now = Date()
        // 限频：同设备 5 分钟内不重复采样
        if let last = lastSampleAt[deviceId], now.timeIntervalSince(last) < 300 { return }
        lastSampleAt[deviceId] = now

        var samples = temperatureHistory[deviceId] ?? []
        samples.append(TemperatureSample(timestamp: now, temperature: temperature))
        // 裁剪：只保留窗口内数据，避免无限增长
        let cutoff = now.addingTimeInterval(-historyWindow)
        samples.removeAll { $0.timestamp < cutoff }
        temperatureHistory[deviceId] = samples
        AppLog.log("温度采样: \(deviceId) \(temperature)°（共 \(samples.count) 条）")
    }

    /// 指定设备的温度序列（按时间升序；无数据时空数组）
    func temperatureSeries(deviceId: String) -> [TemperatureSample] {
        (temperatureHistory[deviceId] ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - 更新检查（G3）

    @Published var updateAvailable: (version: String, url: URL)?

    // MARK: - 小组件快照（v1.7）

    /// 小组件快照写入队列：文件 I/O 不占主线程（AppModel 是 @MainActor）
    private static let snapshotQueue = DispatchQueue(label: "haierac.widget-snapshot")
    /// 快照限流：属性推送可能很频繁（每次温度/状态变化都触发），5 秒内最多刷一次
    private var lastSnapshotWrite = Date.distantPast
    private static let snapshotThrottle: TimeInterval = 5

    /// 写入桌面小组件读取的状态快照。
    /// ⚠️ 不写 AppGroup 容器：非沙盒进程访问 `~/Library/Group Containers/<group>`
    /// 会永久阻塞（实测 ls/touch 均挂起），导致 App 启动卡死、网关无法连接。
    /// 改写到 App 自己的 Application Support 目录，小组件侧通过
    /// 只读临时例外 entitlement 访问同一路径。
    /// 数据结构与 Sources/HaierACWidget/Widget.swift 的 ACWidgetSnapshot 对齐
    func writeWidgetSnapshot(force: Bool = false) {
        // 限流：属性推送可能每秒多次，5 秒内只落盘一次（文件 I/O + 时间线刷新都有开销）
        let now = Date()
        if !force {
            guard now.timeIntervalSince(lastSnapshotWrite) >= Self.snapshotThrottle else { return }
        }
        lastSnapshotWrite = now
        guard let deviceId = devices.first?.id else { return }
        let attrs = attributes[deviceId] ?? [:]
        var dict: [String: Any] = [:]
        if let temp = AppModel.indoorTemperatureAttribute(in: attrs)?.doubleValue {
            dict["temperature"] = temp
        }
        if let target = attrs["targetTemperature"]?.doubleValue {
            dict["targetTemp"] = target
        }
        if let on = attrs["onOffStatus"]?.boolValue {
            dict["powerOn"] = on
        }
        if let hum = AppModel.indoorHumidityAttribute(in: attrs)?.doubleValue {
            dict["humidity"] = hum
        }
        dict["deviceName"] = devices.first?.deviceName ?? ""
        dict["updatedAt"] = ISO8601DateFormatter().string(from: Date())

        // 智能睡眠温阶状态同步到小组件
        if let session = activeSleepSession {
            dict["isSleepActive"] = true
            dict["sleepCurveName"] = session.curveConfig.name
            if let current = session.currentStage {
                dict["sleepStageName"] = current.name
                dict["sleepTargetTemp"] = current.targetTemperature
            }
            dict["sleepCompensationOffset"] = session.compensationOffset
            if let eff = session.effectiveTargetTemperature {
                dict["sleepEffectiveTemp"] = eff
            }
            if let next = session.nextStage {
                dict["sleepNextStageName"] = next.name
            }
            if let fireDate = session.nextFireDate {
                dict["sleepNextFireDate"] = ISO8601DateFormatter().string(from: fireDate)
            }
        } else {
            dict["isSleepActive"] = false
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HaierAC", isDirectory: true)
        Self.snapshotQueue.async {
            do {
                try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
                try data.write(to: base.appendingPathComponent("widget-state.json"), options: .atomic)
            } catch {
                AppLog.log("小组件快照写入失败: \(error.localizedDescription)")
            }
        }
        // 通知系统刷新小组件时间线（未安装小组件时静默忽略）
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - 情景模式（v1.4）

    /// 情景模式：一组「设备 → 属性 → 值」的组合，一键下发
    struct ScenePreset: Identifiable, Codable, Hashable {
        var id = UUID()
        var name: String
        var icon: String = "sparkles"
        /// 动作列表（deviceId → attrName → 值 JSON）
        var actions: [SceneAction]
    }

    struct SceneAction: Codable, Hashable {
        var deviceId: String
        var attrName: String
        var attrDesc: String
        var valueJSON: Data

        var value: AttrValue? {
            AttrValueCodec.decode(valueJSON)
        }
    }

    /// 情景模式列表（持久化）
    @Published var scenes: [ScenePreset] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(scenes) {
                UserDefaults.standard.set(data, forKey: "scenes")
            }
        }
    }

    /// 首次启动写入内置默认情景
    private func seedDefaultScenesIfNeeded() {
        guard UserDefaults.standard.data(forKey: "scenes") == nil else { return }
        scenes = Self.defaultScenes
    }

    /// 内置默认情景（属性名为海尔数字模型通用名；设备不支持时静默跳过）
    static let defaultScenes: [ScenePreset] = [
        ScenePreset(name: "睡眠", icon: "moon.stars.fill", actions: [
            SceneAction(deviceId: "", attrName: "targetTemperature", attrDesc: "目标温度", valueJSON: AttrValueCodec.encode(.double(26)) ?? Data()),
            SceneAction(deviceId: "", attrName: "windSpeed", attrDesc: "风速", valueJSON: AttrValueCodec.encode(.string("low")) ?? Data()),
        ]),
        ScenePreset(name: "离家", icon: "house.fill", actions: [
            SceneAction(deviceId: "", attrName: "onOffStatus", attrDesc: "电源", valueJSON: AttrValueCodec.encode(.bool(false)) ?? Data()),
        ]),
        ScenePreset(name: "回家", icon: "house.and.flag.fill", actions: [
            SceneAction(deviceId: "", attrName: "onOffStatus", attrDesc: "电源", valueJSON: AttrValueCodec.encode(.bool(true)) ?? Data()),
            SceneAction(deviceId: "", attrName: "targetTemperature", attrDesc: "目标温度", valueJSON: AttrValueCodec.encode(.double(24)) ?? Data()),
        ]),
    ]

    /// 用当前选中设备的属性生成默认动作占位（由 UI 填充）
    func addScene(name: String, icon: String, actions: [SceneAction]) {
        scenes.append(ScenePreset(name: name, icon: icon, actions: actions))
        AppLog.log("新增情景: \(name) (\(actions.count) 个动作)")
    }

    func removeScene(_ scene: ScenePreset) {
        scenes.removeAll { $0.id == scene.id }
    }

    /// 更新已有情景（编辑模式；保留 id）
    func updateScene(_ scene: ScenePreset) {
        guard let idx = scenes.firstIndex(where: { $0.id == scene.id }) else { return }
        scenes[idx] = scene
        AppLog.log("更新情景: \(scene.name) (\(scene.actions.count) 个动作)")
    }

    /// 一键应用情景：逐个下发动作（静默，不回 toast）。
    /// - 动作 deviceId 为空时默认作用于第一台设备（可在 UI 中选目标设备）；
    /// - `allDevices=true` 时，空 deviceId 的动作会下发给所有设备（批量场景）。
    func applyScene(_ scene: ScenePreset, targetDeviceId: String? = nil, allDevices: Bool = false) {
        guard gatewayConnected else {
            operationNotice = OperationNotice(text: "⚠️ 连接中断，情景未应用", isError: true)
            return
        }
        let fallbackId = targetDeviceId ?? devices.first?.id
        // 空 deviceId 动作的目标设备列表：全部设备 or 单台
        let emptyTargets: [String] = allDevices
            ? devices.map(\.id) + manualDevices.map(\.deviceId)
            : (fallbackId.map { [$0] } ?? [])
        var sent = 0
        for action in scene.actions {
            guard let value = action.value else { continue }
            let targets = action.deviceId.isEmpty ? emptyTargets : [action.deviceId]
            for deviceId in targets where !deviceId.isEmpty {
                gatewayHandle?.sendControl(deviceId: deviceId, attributes: [action.attrName: value.jsonValue], completion: nil)
                // 乐观更新
                if var map = attributes[deviceId], let old = map[action.attrName] {
                    map[action.attrName] = old.updating(value: value)
                    attributes[deviceId] = map
                }
                sent += 1
            }
        }
        AppLog.log("应用情景: \(scene.name) (\(sent) 个动作, allDevices=\(allDevices))")
        operationNotice = OperationNotice(text: sent > 0 ? "✅ 情景「\(scene.name)」已下发（\(sent) 项）" : "⚠️ 情景「\(scene.name)」无可下发的动作", isError: sent == 0)
    }

    private var provider: (any DeviceProvider)?
    private var context: ProviderContext?
    private var gatewayHandle: (any GatewayHandle)?
    private var deviceIds: [String] = []
    /// 会话代数：logout 时自增；异步链写回前校验，防止登出后旧任务回写状态
    private var sessionGeneration = 0

    init() {
        let saved = UserDefaults.standard.string(forKey: "themeMode")
        themeMode = ThemeMode(rawValue: saved ?? "") ?? .system
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        menuBarShowTemperature = UserDefaults.standard.object(forKey: "menuBarShowTemperature") as? Bool ?? true

        if let data = UserDefaults.standard.data(forKey: "manualDevices"),
           let saved = try? JSONDecoder().decode([ManualDevice].self, from: data) {
            manualDevices = saved
        }
        if let data = UserDefaults.standard.data(forKey: "temperatureHistory"),
           let saved = try? JSONDecoder().decode([String: [TemperatureSample]].self, from: data) {
            temperatureHistory = saved
        }
        if let data = UserDefaults.standard.data(forKey: "scenes"),
           let saved = try? JSONDecoder().decode([ScenePreset].self, from: data) {
            scenes = saved
        } else {
            seedDefaultScenesIfNeeded()
        }
        if let data = UserDefaults.standard.data(forKey: "activeSleepSession"),
           let saved = try? JSONDecoder().decode(SleepSession.self, from: data) {
            activeSleepSession = saved
        }
        if let data = UserDefaults.standard.data(forKey: "customSleepCurves"),
           let saved = try? JSONDecoder().decode([SleepCurveConfig].self, from: data) {
            customSleepCurves = saved
        }
        if let data = UserDefaults.standard.data(forKey: "sleepHistoryRecords"),
           let saved = try? JSONDecoder().decode([SleepRecord].self, from: data) {
            sleepHistory = saved
        }
        sleepNightDimming = UserDefaults.standard.object(forKey: "sleepNightDimming") as? Bool ?? true
        sleepNotificationDND = UserDefaults.standard.object(forKey: "sleepNotificationDND") as? Bool ?? true
        sleepAdaptiveCompensation = UserDefaults.standard.object(forKey: "sleepAdaptiveCompensation") as? Bool ?? true
        sleepHumidityGuard = UserDefaults.standard.object(forKey: "sleepHumidityGuard") as? Bool ?? true
        if let raw = UserDefaults.standard.string(forKey: "sleepMorningTransition"),
           let mode = SleepMorningTransitionMode(rawValue: raw) {
            sleepMorningTransition = mode
        }
        if let data = UserDefaults.standard.data(forKey: "bedtimeSchedule"),
           let saved = try? JSONDecoder().decode(BedtimeSchedule.self, from: data) {
            bedtimeSchedule = saved
        }

        filterAccumulatedMinutes = UserDefaults.standard.integer(forKey: "filterAccumulatedMinutes")
        lastFilterCleanedDate = UserDefaults.standard.object(forKey: "lastFilterCleanedDate") as? Date

        if let data = UserDefaults.standard.data(forKey: "deviceFilterMinutes"),
           let saved = try? JSONDecoder().decode([String: Int].self, from: data) {
            deviceFilterMinutes = saved
        }
        if let data = UserDefaults.standard.data(forKey: "deviceFilterCleanedDates"),
           let saved = try? JSONDecoder().decode([String: Date].self, from: data) {
            deviceFilterCleanedDates = saved
        }

        sleepAmbientSoundEnabled = UserDefaults.standard.bool(forKey: "sleepAmbientSoundEnabled")
        if let rawSound = UserDefaults.standard.string(forKey: "sleepAmbientSoundType"),
           let soundType = AmbientSoundType(rawValue: rawSound) {
            sleepAmbientSoundType = soundType
        }
        if let vol = UserDefaults.standard.object(forKey: "sleepAmbientSoundVolume") as? Float {
            sleepAmbientSoundVolume = vol
        }
        sleepAmbientAutoFadeOut = UserDefaults.standard.object(forKey: "sleepAmbientAutoFadeOut") as? Bool ?? true
        sleepMorningWakeChime = UserDefaults.standard.object(forKey: "sleepMorningWakeChime") as? Bool ?? true
        AmbientSoundEngine.shared.volume = sleepAmbientSoundVolume

        setupSleepWakeObservers()
    }

    // MARK: - 系统休眠与唤醒感知

    private var sleepWakeCancellables: Set<AnyCancellable> = []

    private func setupSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.publisher(for: NSWorkspace.willSleepNotification)
            .sink { _ in
                AppLog.log("系统即将休眠，保护连接状态")
            }
            .store(in: &sleepWakeCancellables)

        center.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                AppLog.log("系统已唤醒，立即恢复连接与补发定时任务")
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // 1. 补发休眠期间到期的定时任务与睡眠阶段推进
                    self.fireDueActions()
                    self.checkSleepCurveSession()
                    // 2. 检查会话并重连
                    if self.provider != nil && self.context != nil {
                        await self.refreshTokenIfNeeded()
                        if !self.gatewayConnected {
                            await self.connectAndLoad()
                        }
                    }
                }
            }
            .store(in: &sleepWakeCancellables)
    }

    // MARK: - 生命周期

    /// 错误页「重试」：会话仍有效时直接重连（无需重新登录）
    func retryConnection() {
        guard provider != nil, context != nil else {
            phase = .loggedOut
            return
        }
        phase = .connecting
        Task {
            await refreshTokenIfNeeded()
            await connectAndLoad()
        }
    }

    /// 启动时恢复会话（由 AppDelegate 在应用启动完成时调用）
    func restoreSession() {
        guard provider == nil else { return }  // 防重入：已有会话则跳过
        // 一次性迁移：旧版本 Keychain 数据 → 文件存储（无弹窗方案）
        CredentialStore.migrateFromKeychainIfNeeded()
        guard let savedToken = CredentialStore.load(forKey: "accountToken"),
              let savedPhone = CredentialStore.load(forKey: "phone") else { return }
        phone = savedPhone
        let provider = HaierProvider()
        self.provider = provider
        self.context = ProviderContext(
            providerId: provider.providerId,
            account: savedPhone,
            token: savedToken,
            refreshToken: CredentialStore.load(forKey: "refreshToken")
        )
        phase = .connecting
        Task {
            // token 临近过期时先静默续期，避免启动即连不上
            await refreshTokenIfNeeded()
            await connectAndLoad()
        }
        startScheduler()  // 登录态调度轮询（无论本次连接成功与否，任务列表可用）
    }

    func login() async {
        loginError = nil
        var trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        if trimmedPhone.hasPrefix("+86") {
            trimmedPhone = String(trimmedPhone.dropFirst(3))
        } else if trimmedPhone.hasPrefix("86") && trimmedPhone.count == 13 {
            trimmedPhone = String(trimmedPhone.dropFirst(2))
        }

        guard !trimmedPhone.isEmpty, !password.isEmpty else {
            loginError = "请输入手机号和密码"
            return
        }
        phase = .connecting
        do {
            let provider = HaierProvider()
            let context = try await provider.login(account: trimmedPhone, password: password)
            self.provider = provider
            self.context = context
            saveCredentials(context, phone: trimmedPhone)
            password = ""
            loginError = nil
            await connectAndLoad()
            startScheduler()  // 登录成功：启动调度轮询
        } catch {
            let msg = AppModel.classifyError(error)
            AppLog.log("登录失败: \(msg) (\(error.localizedDescription))")
            loginError = msg
            phase = .loggedOut
        }
    }

    /// 持久化会话凭据（含过期时刻，用于自动刷新决策）
    private func saveCredentials(_ context: ProviderContext, phone: String) {
        CredentialStore.save(context.token, forKey: "accountToken")
        if let refresh = context.refreshToken {
            CredentialStore.save(refresh, forKey: "refreshToken")
        }
        CredentialStore.save(phone, forKey: "phone")
        if let expiresAt = context.tokenExpiresAt {
            UserDefaults.standard.set(expiresAt.timeIntervalSince1970, forKey: "tokenExpiresAt")
        }
    }

    /// token 临近过期/已过期时静默续期（主动刷新，避免 10 天到期必须重登）
    @discardableResult
    func refreshTokenIfNeeded() async -> Bool {
        guard provider != nil, let context else { return false }
        // 手动添加设备等场景下 context 可能无 refreshToken，跳过
        guard let token = context.refreshToken, !token.isEmpty else { return false }
        let saved = UserDefaults.standard.double(forKey: "tokenExpiresAt")
        let expiresAt = saved > 0 ? Date(timeIntervalSince1970: saved) : context.tokenExpiresAt
        guard TokenRefreshPolicy.shouldRefresh(expiresAt: expiresAt) else { return false }
        return await refreshToken(using: token)
    }

    /// 凭据失效（401/403）时强制用 refreshToken 续期一次；成功更新内存 + 持久化
    private func refreshTokenForced() async -> Bool {
        guard let context, let token = context.refreshToken, !token.isEmpty else { return false }
        return await refreshToken(using: token)
    }

    /// 用 refreshToken 换新 token；成功更新内存 + 持久化并返回 true
    private func refreshToken(using refresh: String) async -> Bool {
        guard let provider, let context else { return false }
        do {
            let newContext = try await provider.refresh(account: context.account, refreshToken: refresh)
            self.context = newContext
            saveCredentials(newContext, phone: context.account)
            AppLog.log("Token 自动刷新成功")
            return true
        } catch {
            AppLog.log("Token 自动刷新失败: \(error.localizedDescription)")
            return false
        }
    }

    private func connectAndLoad() async {
        await connectAndLoad(retryingOnCredentialFailure: true)
    }

    private func connectAndLoad(retryingOnCredentialFailure: Bool) async {
        // 会话代数：本次连接链路的身份标识；logout 后自增，旧链路不得再写回状态
        let generation = sessionGeneration
        do {
            guard let provider, let context else { throw HaierError.invalidResponse }
            let devices = try await provider.fetchDevices(context: context)
            guard generation == sessionGeneration else { return }  // 期间已登出
            self.devices = devices
            deviceIds = devices.map(\.deviceId)
            AppLog.log("设备列表: \(devices.map { $0.deviceName }.joined(separator: ", "))")

            // 拉取所有设备数字模型（初始快照）；多设备并行以加快加载
            await withTaskGroup(of: (String, [DeviceAttribute]).self) { group in
                for device in devices {
                    group.addTask {
                        let attrs = (try? await provider.fetchDigitalModel(context: context, deviceId: device.id)) ?? []
                        return (device.id, attrs)
                    }
                }
                for await (deviceId, attrs) in group {
                    guard generation == sessionGeneration else { return }  // 期间已登出
                    AppLog.log("数字模型 \(deviceId): \(attrs.count) 个属性")
                    var map: [String: DeviceAttribute] = [:]
                    for attr in attrs where !attr.name.isEmpty {
                        map[attr.name] = attr
                    }
                    attributes[deviceId] = map
                }
            }
            // 初始采样：数字模型已加载，为有温度的设备记录第一条采样
            for device in devices {
                if let temp = Self.indoorTemperatureAttribute(in: attributes[device.id] ?? [:])?.doubleValue {
                    recordTemperatureSample(deviceId: device.id, temperature: temp)
                }
            }
            writeWidgetSnapshot()  // 初始状态同步到小组件

            // 连接实时网关
            let handle = try await provider.connectGateway(
                context: context,
                deviceIds: deviceIds,
                onConnected: { [weak self] in
                    AppLog.log("网关已连接")
                    Task { @MainActor in
                        guard let self else { return }
                        self.gatewayConnected = true
                        self.phase = .ready
                    }
                },
                onAttributes: { [weak self] deviceId, attrs in
                    AppLog.log("收到属性推送: \(deviceId) \(attrs.count) 个")
                    Task { @MainActor in
                        guard let self else { return }
                        var map = self.attributes[deviceId] ?? [:]
                        for (name, attr) in attrs {
                            map[name] = attr
                        }
                        self.attributes[deviceId] = map
                        self.confirmPendingIfNeeded(deviceId: deviceId, attrs: attrs)
                        // 温度历史采样（限频 5 分钟一条，24h 窗口）
                        if let temp = AppModel.indoorTemperatureAttribute(in: map)?.doubleValue {
                            self.recordTemperatureSample(deviceId: deviceId, temperature: temp)
                        }
                        self.writeWidgetSnapshot()  // 状态变化同步到小组件
                    }
                },
                onDisconnected: { [weak self] _ in
                    AppLog.log("网关断开")
                    Task { @MainActor in
                        self?.gatewayConnected = false
                        self?.failPendingOnDisconnect()
                    }
                }
            )
            guard generation == sessionGeneration else { return }  // 期间已登出
            self.gatewayHandle = handle
            handle.start()
            // 设备列表已就绪即可进入 ready（网关连接状态由 onConnected/onDisconnected 回调驱动）
            phase = .ready
        } catch {
            AppLog.log("连接失败: \(error.localizedDescription)")
            // 凭据失效：尝试用 refreshToken 强制续期一次后重连；仍失败才报错引导重登
            if retryingOnCredentialFailure, TokenRefreshPolicy.isCredentialError(error),
               await refreshTokenForced() {
                await connectAndLoad(retryingOnCredentialFailure: false)
            } else {
                if TokenRefreshPolicy.isCredentialError(error) {
                    // 凭据彻底失效且无法刷新：清空无效凭据并返回登录界面
                    CredentialStore.deleteAll()
                    loginError = AppModel.classifyError(error)
                    phase = .loggedOut
                } else {
                    phase = .error(AppModel.classifyError(error))
                }
            }
        }
    }

    func logout() {
        sessionGeneration += 1  // 使所有进行中的异步链失效
        stopScheduler()
        activeSleepSession = nil
        gatewayHandle?.stop()
        gatewayHandle = nil
        gatewayConnected = false
        // 清空小组件快照（登出后无状态可展示）。
        // ⚠️ 不能碰 Group Containers（非沙盒访问会挂起），快照现在在 Application Support
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HaierAC", isDirectory: true)
        try? FileManager.default.removeItem(at: base.appendingPathComponent("widget-state.json"))
        WidgetCenter.shared.reloadAllTimelines()
        CredentialStore.deleteAll()
        UserDefaults.standard.removeObject(forKey: "tokenExpiresAt")
        provider = nil
        context = nil
        devices = []
        attributes = [:]
        phone = ""
        phase = .loggedOut
    }

    // MARK: - 控制

    /// 发送属性控制指令（值是原始 JSON 类型），并给出操作反馈
    func sendAttribute(_ name: String, value: AttrValue, deviceId: String) {
        AppLog.log("sendAttribute: \(name)=\(value.stringValue) device=\(deviceId)")

        // 失效预案：网关未连接时明确提示，不静默失败
        guard gatewayConnected, let handle = gatewayHandle else {
            operationNotice = OperationNotice(text: "⚠️ 连接中断，指令未发送（自动重连中）", isError: true)
            return
        }

        handle.sendControl(deviceId: deviceId, attributes: [name: value.jsonValue]) { [weak self] sent in
            Task { @MainActor in
                guard let self else { return }
                if !sent {
                    self.operationNotice = OperationNotice(text: "⚠️ 指令发送失败，请稍后重试", isError: true)
                }
            }
        }
        // 乐观更新
        if var map = attributes[deviceId], let old = map[name] {
            map[name] = old.updating(value: value)
            attributes[deviceId] = map
        }

        // 操作反馈：显示属性中文名（如「情景灯光」）
        let desc = attributes[deviceId]?[name]?.desc ?? name
        operationNotice = OperationNotice(text: "已发送：\(desc)", isError: false)
        // 记录待确认项，等网关回读确认生效
        pendingConfirm = (deviceId, name, value)
    }

    /// 批量下发同一指令到多台设备（v1.5）；返回值：成功下发的设备数
    @discardableResult
    func sendAttributeToDevices(_ name: String, value: AttrValue, deviceIds: [String]) -> Int {
        guard gatewayConnected, let handle = gatewayHandle else {
            operationNotice = OperationNotice(text: "⚠️ 连接中断，指令未发送（自动重连中）", isError: true)
            return 0
        }
        var sent = 0
        for deviceId in deviceIds {
            handle.sendControl(deviceId: deviceId, attributes: [name: value.jsonValue]) { [weak self] ok in
                if !ok {
                    Task { @MainActor in
                        self?.operationNotice = OperationNotice(text: "⚠️ 部分设备指令发送失败", isError: true)
                    }
                }
            }
            if var map = attributes[deviceId], let old = map[name] {
                map[name] = old.updating(value: value)
                attributes[deviceId] = map
            }
            sent += 1
        }
        let desc = attributes[deviceIds.first ?? ""]?[name]?.desc ?? name
        AppLog.log("批量下发: \(name)=\(value.stringValue) → \(deviceIds.count) 台设备")
        operationNotice = OperationNotice(text: "已发送：\(desc) → \(sent) 台设备", isError: false)
        return sent
    }

    /// 网关推送属性时调用：确认待生效操作
    private func confirmPendingIfNeeded(deviceId: String, attrs: [String: DeviceAttribute]) {
        guard let pending = pendingConfirm,
              pending.deviceId == deviceId,
              let pushed = attrs[pending.name],
              pushed.value == pending.expected else { return }
        pendingConfirm = nil
        let desc = attrs[pending.name]?.desc ?? pending.name
        operationNotice = OperationNotice(text: "✅ \(desc) 已生效", isError: false)
    }

    /// 网关断开时调用：未确认的操作标记失败
    private func failPendingOnDisconnect() {
        guard let pending = pendingConfirm else { return }
        pendingConfirm = nil
        let desc = attributes[pending.deviceId]?[pending.name]?.desc ?? pending.name
        operationNotice = OperationNotice(text: "⚠️ \(desc) 可能未生效（连接中断）", isError: true)
    }

    /// 检查 GitHub 是否有新版本（G3 失效预案）
    func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/bitterSmilezzz/haier-ac-mac/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        request.setValue("HaierAC-Mac/\(appVersion)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let htmlURL = json["html_url"] as? String,
              let latestURL = URL(string: htmlURL) else { return }
        let current = appVersion
        // tag 形如 "v1.2.1"，去掉 v 前缀比较
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        if latest.compare(current, options: .numeric) == .orderedDescending {
            updateAvailable = (latest, latestURL)
            AppLog.log("发现新版本: \(latest) -> \(latestURL)")
        }
    }

    /// 错误分类（G3 失效预案）：区分网络 / 账号 / 协议问题，协议类引导用户查看仓库
    static func classifyError(_ error: Error) -> String {
        if let haierError = error as? HaierError {
            switch haierError {
            case .network:
                return "网络连接失败，请检查网络后重试"
            case .http(let code) where code == 401 || code == 403:
                return "账号凭据失效，请重新登录"
            case .retCode(_, let info) where TokenRefreshPolicy.isCredentialError(haierError):
                let detail = info.isEmpty ? "" : "（\(info)）"
                return "账号凭据已失效\(detail)，请重新登录"
            case .retCode(let code, let info):
                let detail = info.isEmpty ? "" : "：\(info)"
                return "海尔云接口返回异常（\(code)）\(detail)"
            default:
                return "请求失败：\(error.localizedDescription)"
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "网络连接失败，请检查网络后重试"
            case .timedOut:
                return "连接超时，请稍后重试"
            default:
                return "网络错误：\(urlError.localizedDescription)"
            }
        }
        return error.localizedDescription
    }

    func attribute(_ name: String, deviceId: String) -> DeviceAttribute? {
        attributes[deviceId]?[name]
    }

    var isLoggedIn: Bool {
        if case .ready = phase { return true }
        return false
    }

    // MARK: - 局域网发现

    /// 扫描当前 WiFi 下的海尔设备
    func discoverDevices() async {
        guard !isDiscovering else { return }
        isDiscovering = true
        discoveredDevices = []
        AppLog.log("开始局域网发现")
        let found = await DeviceDiscovery.discover(timeout: 3)
        discoveredDevices = found
        isDiscovering = false
        AppLog.log("发现 \(found.count) 台设备: \(found.map { "\($0.ip)/\($0.mac)" }.joined(separator: ", "))")
    }

    /// 将发现到的设备（或手动输入 deviceId）加入列表并尝试拉取数字模型
    func addDevice(deviceId: String, name: String) async {
        let trimmed = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let generation = sessionGeneration
        // 已在云端列表？无需重复添加
        if devices.contains(where: { $0.id == trimmed }) {
            return
        }
        // 已在手动列表？仅更新名称
        if let idx = manualDevices.firstIndex(where: { $0.deviceId == trimmed }) {
            manualDevices[idx].name = name.isEmpty ? manualDevices[idx].name : name
            return
        }
        manualDevices.append(ManualDevice(deviceId: trimmed, name: name.isEmpty ? trimmed : name))
        // 尝试拉取数字模型（验证设备可访问）
        if let provider, let context {
            if let attrs = try? await provider.fetchDigitalModel(context: context, deviceId: trimmed) {
                guard generation == sessionGeneration else { return }  // 期间已登出
                var map: [String: DeviceAttribute] = [:]
                for attr in attrs where !attr.name.isEmpty {
                    map[attr.name] = attr
                }
                attributes[trimmed] = map
            }
        }
        // 同步网关订阅，让手动设备也能收到属性推送与控制确认
        resubscribeGatewayIfNeeded()
    }

    /// 从手动列表移除设备
    func removeManualDevice(_ device: ManualDevice) {
        manualDevices.removeAll { $0.deviceId == device.deviceId }
        attributes[device.deviceId] = nil
        resubscribeGatewayIfNeeded()
    }

    /// 重命名手动设备（本地别名，不影响云端）
    func renameManualDevice(_ device: ManualDevice, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = manualDevices.firstIndex(where: { $0.deviceId == device.deviceId }) else { return }
        manualDevices[idx].name = trimmed
        AppLog.log("重命名手动设备: \(device.deviceId) -> \(trimmed)")
    }

    /// 用「云端 + 手动」全量设备列表刷新网关订阅
    private func resubscribeGatewayIfNeeded() {
        guard let handle = gatewayHandle else { return }
        let allIds = devices.map(\.id) + manualDevices.map(\.deviceId)
        deviceIds = allIds
        handle.updateSubscription(deviceIds: allIds)
    }

    // MARK: - 开机自启

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLog.log("自启设置失败: \(error.localizedDescription)")
        }
    }
}
