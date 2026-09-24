import Foundation
import HaierACCore

/// 容错解码包装器：解码失败时不抛出异常而是置为 nil，防止列表局部损毁导致整组数据静默丢失
private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        let container = try? decoder.singleValueContainer()
        self.value = try? container?.decode(T.self)
    }
}

/// 每日用电能耗历史记录
///
/// 统计口径说明：
/// - `totalMinutes`: 全屋空调开机墙钟运行总时长（分钟）。若任意一台或多台空调在同一分钟处于开机运行状态，
///   该分钟仅累计一次（墙钟时间），反映家庭空调环境处于启用的自然时长。
/// - `coolingMinutes` / `heatingMinutes` / `fanMinutes` / `dehumMinutes`: 各模式对应的全屋累计墙钟运行分钟数。
/// - `totalKWh`: 全屋所有设备累计消耗电量（度/kWh）。采用多台空调物理叠加口径，结合各设备当前运行模式、
///   风速档位、设定温度与室内温差动力学模型动态逐分钟积分累加。
/// - `totalCost`: 全屋累计预估电费金额（元），支持单一电价与峰谷分时时段自动折算。
/// - `totalDeviceMinutes`: 全屋所有空调累计设备机时（台·分钟），各工况机时之和恒等于总机时 (v1.9.35)。
public struct EnergyDayRecord: Codable, Equatable, Identifiable {
    public var id: String { date }
    public var date: String // "yyyy-MM-dd"
    public var totalMinutes: Int
    public var totalDeviceMinutes: Int // 全屋设备累计机时 (台·分钟) (v1.9.35)
    public var coolingMinutes: Int
    public var heatingMinutes: Int
    public var fanMinutes: Int
    public var dehumMinutes: Int
    public var unknownMinutes: Int // 未识别模式分钟数 (v1.9.26)
    public var totalKWh: Double
    public var totalCost: Double

    public init(
        date: String,
        totalMinutes: Int = 0,
        totalDeviceMinutes: Int = 0,
        coolingMinutes: Int = 0,
        heatingMinutes: Int = 0,
        fanMinutes: Int = 0,
        dehumMinutes: Int = 0,
        unknownMinutes: Int = 0,
        totalKWh: Double = 0.0,
        totalCost: Double = 0.0
    ) {
        self.date = date
        self.totalMinutes = totalMinutes
        self.totalDeviceMinutes = totalDeviceMinutes > 0 ? totalDeviceMinutes : (coolingMinutes + heatingMinutes + fanMinutes + dehumMinutes + unknownMinutes)
        self.coolingMinutes = coolingMinutes
        self.heatingMinutes = heatingMinutes
        self.fanMinutes = fanMinutes
        self.dehumMinutes = dehumMinutes
        self.unknownMinutes = unknownMinutes
        self.totalKWh = totalKWh
        self.totalCost = totalCost
    }

    enum CodingKeys: String, CodingKey {
        case date, totalMinutes, totalDeviceMinutes, coolingMinutes, heatingMinutes, fanMinutes, dehumMinutes, unknownMinutes, totalKWh, totalCost
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        totalMinutes = try container.decodeIfPresent(Int.self, forKey: .totalMinutes) ?? 0
        let decodedDevMins = try container.decodeIfPresent(Int.self, forKey: .totalDeviceMinutes)
        coolingMinutes = try container.decodeIfPresent(Int.self, forKey: .coolingMinutes) ?? 0
        heatingMinutes = try container.decodeIfPresent(Int.self, forKey: .heatingMinutes) ?? 0
        fanMinutes = try container.decodeIfPresent(Int.self, forKey: .fanMinutes) ?? 0
        dehumMinutes = try container.decodeIfPresent(Int.self, forKey: .dehumMinutes) ?? 0
        unknownMinutes = try container.decodeIfPresent(Int.self, forKey: .unknownMinutes) ?? 0
        totalKWh = try container.decodeIfPresent(Double.self, forKey: .totalKWh) ?? 0.0
        totalCost = try container.decodeIfPresent(Double.self, forKey: .totalCost) ?? 0.0

        if let d = decodedDevMins, d > 0 {
            totalDeviceMinutes = d
        } else {
            // 兼容性迁移策略 (v1.9.36 闭环 CR P2-4):
            // v1.9.34 及更早版本写入的历史记录无 totalDeviceMinutes 字段，其模式工况分钟为墙钟口径；
            // 回填采用工况分钟之和与总墙钟时长之最大值平滑过渡，确保老版本 60 天数据不丢失且占比正常解析；
            // 新写入记录则完全统一为设备机时精确积分口径（各工况机时之和恒等于总机时）。
            let sumModes = coolingMinutes + heatingMinutes + fanMinutes + dehumMinutes + unknownMinutes
            totalDeviceMinutes = max(sumModes, totalMinutes)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(totalMinutes, forKey: .totalMinutes)
        try container.encode(totalDeviceMinutes, forKey: .totalDeviceMinutes)
        try container.encode(coolingMinutes, forKey: .coolingMinutes)
        try container.encode(heatingMinutes, forKey: .heatingMinutes)
        try container.encode(fanMinutes, forKey: .fanMinutes)
        try container.encode(dehumMinutes, forKey: .dehumMinutes)
        try container.encode(unknownMinutes, forKey: .unknownMinutes)
        try container.encode(totalKWh, forKey: .totalKWh)
        try container.encode(totalCost, forKey: .totalCost)
    }

    /// 有效总设备机时（台·分钟），用于计算模式分布占比 (v1.9.35)
    public var effectiveDeviceMinutes: Int {
        if totalDeviceMinutes > 0 { return totalDeviceMinutes }
        let modeSum = coolingMinutes + heatingMinutes + fanMinutes + dehumMinutes + unknownMinutes
        return max(modeSum, totalMinutes)
    }

    /// 制冷工况机时占比（0.0 ~ 1.0）
    public var coolingRatio: Double {
        let total = effectiveDeviceMinutes
        guard total > 0 else { return 0.0 }
        return min(1.0, Double(coolingMinutes) / Double(total))
    }

    /// 制热工况机时占比（0.0 ~ 1.0）
    public var heatingRatio: Double {
        let total = effectiveDeviceMinutes
        guard total > 0 else { return 0.0 }
        return min(1.0, Double(heatingMinutes) / Double(total))
    }

    /// 除湿工况机时占比（0.0 ~ 1.0）
    public var dehumRatio: Double {
        let total = effectiveDeviceMinutes
        guard total > 0 else { return 0.0 }
        return min(1.0, Double(dehumMinutes) / Double(total))
    }

    /// 送风工况机时占比（0.0 ~ 1.0）
    public var fanRatio: Double {
        let total = effectiveDeviceMinutes
        guard total > 0 else { return 0.0 }
        return min(1.0, Double(fanMinutes) / Double(total))
    }

    /// 其他/未知工况机时占比（0.0 ~ 1.0） (v1.9.36)
    public var unknownRatio: Double {
        let total = effectiveDeviceMinutes
        guard total > 0 else { return 0.0 }
        return min(1.0, Double(unknownMinutes) / Double(total))
    }
}

/// 电价配置与峰谷电价策略
public struct ElectricityPricingConfig: Codable, Equatable {
    public var flatRate: Double = 0.60      // 常规单一电价 (元/度)
    public var peakValleyEnabled: Bool = false // 是否启用峰谷分时电价
    public var peakRate: Double = 0.65      // 峰段单价 (元/度, 08:00 ~ 22:00)
    public var valleyRate: Double = 0.35    // 谷段单价 (元/度, 22:00 ~ 08:00)

    public init(
        flatRate: Double = 0.60,
        peakValleyEnabled: Bool = false,
        peakRate: Double = 0.65,
        valleyRate: Double = 0.35
    ) {
        self.flatRate = flatRate
        self.peakValleyEnabled = peakValleyEnabled
        self.peakRate = peakRate
        self.valleyRate = valleyRate
    }

    /// 获取特定时间点的适用电价
    public func rate(for date: Date = Date()) -> Double {
        guard peakValleyEnabled else { return flatRate }
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 22 || hour < 8 {
            return valleyRate
        } else {
            return peakRate
        }
    }
}

/// 智能用电能耗估算与节能减排管家引擎 (v1.9.20)
@MainActor
public final class EnergyAnalyticsEngine: ObservableObject {
    public static let shared = EnergyAnalyticsEngine()

    @Published public var pricingConfig: ElectricityPricingConfig {
        didSet {
            if let data = try? JSONEncoder().encode(pricingConfig) {
                UserDefaults.standard.set(data, forKey: "electricityPricingConfig")
            }
        }
    }

    /// 历史每日用电记录 (最多保留 60 天)
    @Published public var historyRecords: [EnergyDayRecord] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(historyRecords) {
                UserDefaults.standard.set(data, forKey: "energyHistoryRecords")
            }
        }
    }

    /// 瞬时预估功率 (瓦特 W)
    @Published public private(set) var currentInstantaneousPower: Double = 1.5

    private init() {
        if let data = UserDefaults.standard.data(forKey: "electricityPricingConfig"),
           let saved = try? JSONDecoder().decode(ElectricityPricingConfig.self, from: data) {
            self.pricingConfig = saved
        } else {
            self.pricingConfig = ElectricityPricingConfig()
        }

        if let data = UserDefaults.standard.data(forKey: "energyHistoryRecords") {
            // 采用逐条元素容错解码（Safe List Decoder），确保损坏或格式不兼容的历史单项记录不会导致整组 60 天数据静默丢失
            if let failableList = try? JSONDecoder().decode([FailableDecodable<EnergyDayRecord>].self, from: data) {
                let validRecords = failableList.compactMap { $0.value }.filter { !$0.date.isEmpty }
                if validRecords.count < failableList.count {
                    let corrupted = failableList.count - validRecords.count
                    AppLog.warning("能耗历史加载：已安全隔离并过滤 \(corrupted) 条损毁/无效记录，成功保留 \(validRecords.count) 天历史数据")
                }
                self.historyRecords = validRecords
            } else {
                AppLog.warning("能耗历史数据反序列化异常，未能解析有效 JSON 列表")
            }
        }
    }

    // MARK: - 实时瞬时功率估算算法

    /// 估算空调当前瞬时功率 (W)
    /// 基于 1.5 匹直流变频压缩机典型工况动力学模型计算
    public func estimateInstantaneousPower(
        isPowerOn: Bool,
        modeCode: String?,
        targetTemp: Double?,
        indoorTemp: Double?,
        indoorHumidity: Double? = nil,
        windSpeed: String?,
        isSelfCleaning: Bool = false
    ) -> Double {
        let windOffset: Double = {
            guard let wind = windSpeed?.lowercased() else { return 40.0 }
            if wind.contains("微") || wind.contains("静") { return 15.0 }
            if wind.contains("低") { return 35.0 }
            if wind.contains("中") { return 65.0 }
            if wind.contains("高") { return 110.0 }
            if wind.contains("强") { return 180.0 }
            return 40.0
        }()

        if isSelfCleaning {
            // 56°C 蒸发器高温除菌自清洁工况（急冷结霜、微波解冻与 56°C 恒温烘干灭菌）：
            // 平均热力学电功率稳定在 880W ~ 1050W 之间
            return 920.0 + (windOffset * 0.5)
        }

        guard isPowerOn else {
            return 1.5 // 待机微功耗 1.5W
        }

        // 未识别模式采用物理中性功率估算策略（冷热综合无偏估计）：
        // 1. 若室内温度与设定温度均有效，采用制冷动力曲线（380W + 95W/°C）与制热动力曲线（550W + 110W/°C）在温差绝对值 |ΔT| 下的均值基准：
        //    P = ((380 + 550) / 2) + (|indoor - target| * ((95 + 110) / 2)) + windOffset = 465.0 + |ΔT| * 102.5 + windOffset
        //    clamp 限制在 [200.0, 1550.0] W 区间，实现对称且客观的中性功率估算，避免系统性偏向制冷低估或制热高估；
        // 2. 若温度字段缺失（室内或设定温度为 nil），则采用 1.5 匹直流变频压缩机典型低频维持中性基准功率 (350W + windOffset，clamp [180.0, 600.0] W)，避免盲目套用大温差曲线导致功率虚标。
        guard let mode = ACModeCode.match(from: modeCode) else {
            if let indoor = indoorTemp, let target = targetTemp {
                let delta = abs(indoor - target)
                let neutralPower = 465.0 + (delta * 102.5) + windOffset
                return min(max(neutralPower, 200.0), 1550.0)
            } else {
                let neutralPower = 350.0 + windOffset
                return min(max(neutralPower, 180.0), 600.0)
            }
        }

        switch mode {
        case .fan:
            // 送风模式：仅室内风机运转，极其省电
            let power = 15.0 + windOffset * 0.4
            return min(max(power, 15.0), 65.0)

        case .dehumidify:
            // 除湿模式：多维环境湿度自适应变频能耗动力学模型 (v1.9.37)
            // 典型变频空调除湿机制：
            // 1. 高湿重载区 (RH >= 70%)：蒸发器深度过冷持续冷凝凝结，压缩机高频运转 (520W 基准)
            // 2. 中湿过渡区 (55% <= RH < 70%)：温湿度平衡变频除湿，维持舒适体感 (380W ~ 500W)
            // 3. 舒适/低湿微载区 (RH < 55%)：防过冷与防过度干燥，压缩机平滑降频至超低频稳态 (240W ~ 320W)
            // 4. 无湿度传感器兜底：回归标准基准 420W
            let basePower: Double
            if let hum = indoorHumidity {
                if hum >= 70.0 {
                    let excess = min(30.0, hum - 70.0)
                    basePower = 520.0 + (excess * 3.3)
                } else if hum >= 55.0 {
                    let progress = (hum - 55.0) / 15.0
                    basePower = 380.0 + (progress * 120.0)
                } else {
                    let lowFactor = max(0.0, hum / 55.0)
                    basePower = 240.0 + (lowFactor * 80.0)
                }
            } else {
                basePower = 420.0
            }
            let power = basePower + (windOffset * 0.5)
            return min(max(power, 220.0), 650.0)

        case .heating:
            // 制热模式：变频温差动力学模型 + 恒温平衡区低频维持态阻尼 (v1.9.36)
            let indoor = indoorTemp ?? 18.0
            let target = targetTemp ?? 20.0
            let delta = target - indoor
            let power: Double
            if delta <= 0.0 {
                // 已达到或高于设定温度：压缩机进入超节能恒温维持态
                power = 300.0 + (windOffset * 0.6)
            } else if delta < 1.0 {
                // 接近目标温差 (0 < ΔT < 1.0°C)：平滑过渡至稳态低频
                power = 300.0 + (delta * 250.0) + (windOffset * 0.8)
            } else {
                // 变频重载升温区 (ΔT >= 1.0°C)
                power = 550.0 + ((delta - 1.0) * 110.0) + windOffset
            }
            return min(max(power, 220.0), 1650.0)

        case .cooling:
            // 制冷模式：变频温差动力学模型 + 恒温平衡区低频维持态阻尼 (v1.9.36)
            let indoor = indoorTemp ?? 26.0
            let target = targetTemp ?? 25.0
            let delta = indoor - target
            let power: Double
            if delta <= 0.0 {
                // 已达到或低于设定温度：压缩机进入超节能恒温维持态
                power = 220.0 + (windOffset * 0.6)
            } else if delta < 1.0 {
                // 接近目标温差 (0 < ΔT < 1.0°C)：平滑过渡至稳态低频
                power = 220.0 + (delta * 160.0) + (windOffset * 0.8)
            } else {
                // 变频重载降温区 (ΔT >= 1.0°C)
                power = 380.0 + ((delta - 1.0) * 95.0) + windOffset
            }
            return min(max(power, 180.0), 1450.0)

        case .auto:
            // 自动模式：根据室内与设定温差智能判别制冷或制热动力曲线 (v1.9.36 统一阻尼模型)
            let indoor = indoorTemp ?? 25.0
            let target = targetTemp ?? 24.0
            if indoor >= target {
                let delta = indoor - target
                let power: Double
                if delta <= 0.0 {
                    power = 220.0 + (windOffset * 0.6)
                } else if delta < 1.0 {
                    power = 220.0 + (delta * 160.0) + (windOffset * 0.8)
                } else {
                    power = 380.0 + ((delta - 1.0) * 95.0) + windOffset
                }
                return min(max(power, 180.0), 1450.0)
            } else {
                let delta = target - indoor
                let power: Double
                if delta <= 0.0 {
                    power = 300.0 + (windOffset * 0.6)
                } else if delta < 1.0 {
                    power = 300.0 + (delta * 250.0) + (windOffset * 0.8)
                } else {
                    power = 550.0 + ((delta - 1.0) * 110.0) + windOffset
                }
                return min(max(power, 220.0), 1650.0)
            }
        }
    }

    // MARK: - 多设备能耗动力学模型与周期积分累计

    /// 单台空调设备的运行采样状态
    public struct DeviceEnergySample {
        public let deviceId: String
        public let isPowerOn: Bool
        public let modeCode: String?
        public let targetTemp: Double?
        public let indoorTemp: Double?
        public let indoorHumidity: Double?
        public let windSpeed: String?
        public let isSelfCleaning: Bool

        public init(
            deviceId: String,
            isPowerOn: Bool,
            modeCode: String?,
            targetTemp: Double?,
            indoorTemp: Double?,
            indoorHumidity: Double? = nil,
            windSpeed: String?,
            isSelfCleaning: Bool = false
        ) {
            self.deviceId = deviceId
            self.isPowerOn = isPowerOn
            self.modeCode = modeCode
            self.targetTemp = targetTemp
            self.indoorTemp = indoorTemp
            self.indoorHumidity = indoorHumidity
            self.windSpeed = windSpeed
            self.isSelfCleaning = isSelfCleaning
        }
    }

    /// 多设备全场景瞬时功率聚合与运行采样积分 (v1.9.21)
    /// - Parameters:
    ///   - deviceSamples: 所有已绑定空调的运行状态样本列表
    ///   - elapsedSeconds: 距离上次采样的流逝秒数（支持动态微补偿与休眠唤醒精确积分）
    public func accumulateSample(
        deviceSamples: [DeviceEnergySample],
        elapsedSeconds: Double = 60.0
    ) {
        let now = Date()
        let rate = pricingConfig.rate(for: now)
        let dateKey = DateFormatter.dayDateFormatter.string(from: now)
        let deltaHours = max(0.0, elapsedSeconds) / 3600.0

        var totalInstantaneousPower: Double = 0.0
        var totalIncrementalKWh: Double = 0.0
        var runningCooling = 0
        var runningHeating = 0
        var runningFan = 0
        var runningDehum = 0
        var runningUnknown = 0
        var hasAnyRunningDevice = false

        for sample in deviceSamples {
            let power = estimateInstantaneousPower(
                isPowerOn: sample.isPowerOn,
                modeCode: sample.modeCode,
                targetTemp: sample.targetTemp,
                indoorTemp: sample.indoorTemp,
                indoorHumidity: sample.indoorHumidity,
                windSpeed: sample.windSpeed,
                isSelfCleaning: sample.isSelfCleaning
            )
            totalInstantaneousPower += power

            if sample.isPowerOn || sample.isSelfCleaning {
                hasAnyRunningDevice = true
                let devKWh = (power * deltaHours) / 1000.0
                totalIncrementalKWh += devKWh

                if sample.isSelfCleaning {
                    // 自清洁归入高温热力学工况
                    runningHeating += 1
                } else if let sampleMode = ACModeCode.match(from: sample.modeCode) {
                    switch sampleMode {
                    case .cooling: runningCooling += 1
                    case .heating: runningHeating += 1
                    case .fan: runningFan += 1
                    case .dehumidify: runningDehum += 1
                    case .auto:
                        if (sample.indoorTemp ?? 25.0) >= (sample.targetTemp ?? 24.0) {
                            runningCooling += 1
                        } else {
                            runningHeating += 1
                        }
                    }
                } else {
                    runningUnknown += 1
                }
            }
        }

        self.currentInstantaneousPower = totalInstantaneousPower

        // 若全屋所有空调均处于关机待机状态，仅刷新待机总功率，不计入运行分钟与账单
        guard hasAnyRunningDevice, totalIncrementalKWh > 0.0 else { return }

        let totalCostDelta = totalIncrementalKWh * rate
        let incrementalMinutes = max(1, Int(round(elapsedSeconds / 60.0)))
        let totalRunningDevices = runningCooling + runningHeating + runningFan + runningDehum + runningUnknown
        let incrementalDeviceMinutes = totalRunningDevices * incrementalMinutes

        // 各工况设备机时增量（台·分钟）(v1.9.35: 彻底消除多设备并发运行时各模式累加和超出全屋运行时长的量纲冲突)
        let incCooling = runningCooling * incrementalMinutes
        let incHeating = runningHeating * incrementalMinutes
        let incFan = runningFan * incrementalMinutes
        let incDehum = runningDehum * incrementalMinutes
        let incUnknown = runningUnknown * incrementalMinutes

        if let idx = historyRecords.firstIndex(where: { $0.date == dateKey }) {
            historyRecords[idx].totalMinutes += incrementalMinutes
            historyRecords[idx].totalDeviceMinutes += incrementalDeviceMinutes
            historyRecords[idx].totalKWh += totalIncrementalKWh
            historyRecords[idx].totalCost += totalCostDelta

            if incCooling > 0 { historyRecords[idx].coolingMinutes += incCooling }
            if incHeating > 0 { historyRecords[idx].heatingMinutes += incHeating }
            if incFan > 0 { historyRecords[idx].fanMinutes += incFan }
            if incDehum > 0 { historyRecords[idx].dehumMinutes += incDehum }
            if incUnknown > 0 { historyRecords[idx].unknownMinutes += incUnknown }
        } else {
            var newRecord = EnergyDayRecord(date: dateKey)
            newRecord.totalMinutes = incrementalMinutes
            newRecord.totalDeviceMinutes = incrementalDeviceMinutes
            newRecord.totalKWh = totalIncrementalKWh
            newRecord.totalCost = totalCostDelta

            if incCooling > 0 { newRecord.coolingMinutes = incCooling }
            if incHeating > 0 { newRecord.heatingMinutes = incHeating }
            if incFan > 0 { newRecord.fanMinutes = incFan }
            if incDehum > 0 { newRecord.dehumMinutes = incDehum }
            if incUnknown > 0 { newRecord.unknownMinutes = incUnknown }

            historyRecords.insert(newRecord, at: 0)
            if historyRecords.count > 60 {
                historyRecords = Array(historyRecords.prefix(60))
            }
        }
    }

    /// 记录单台空调 1 分钟运行采样并积分计入当日电量 (向下兼容接口)
    public func accumulateMinuteSample(
        isPowerOn: Bool,
        modeCode: String?,
        targetTemp: Double?,
        indoorTemp: Double?,
        windSpeed: String?
    ) {
        let sample = DeviceEnergySample(
            deviceId: "legacy_single_device",
            isPowerOn: isPowerOn,
            modeCode: modeCode,
            targetTemp: targetTemp,
            indoorTemp: indoorTemp,
            windSpeed: windSpeed
        )
        accumulateSample(deviceSamples: [sample], elapsedSeconds: 60.0)
    }

    // MARK: - 统计计算属性

    public var todayRecord: EnergyDayRecord {
        let key = DateFormatter.dayDateFormatter.string(from: Date())
        return historyRecords.first(where: { $0.date == key }) ?? EnergyDayRecord(date: key)
    }

    public var recent7DaysRecords: [EnergyDayRecord] {
        let calendar = Calendar.current
        var results: [EnergyDayRecord] = []
        for i in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let key = DateFormatter.dayDateFormatter.string(from: day)
            if let found = historyRecords.first(where: { $0.date == key }) {
                results.append(found)
            } else {
                results.append(EnergyDayRecord(date: key))
            }
        }
        return results
    }

    /// 今日综合绿色节能评分 (0~100)
    public func calculateEcoScore(activeSleepSession: Bool, targetTemp: Double?) -> Int {
        var score = 82

        // 温度达标奖励
        if let temp = targetTemp {
            if temp >= 26.0 {
                score += 8
            } else if temp <= 22.0 {
                score -= 15
            } else if temp <= 24.0 {
                score -= 6
            }
        }

        // 智能睡眠温阶加分
        if activeSleepSession {
            score += 10
        }

        return min(max(score, 0), 100)
    }
}

extension DateFormatter {
    static let dayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
