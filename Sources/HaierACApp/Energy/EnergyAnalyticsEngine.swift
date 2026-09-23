import Foundation

/// 每日用电能耗历史记录
public struct EnergyDayRecord: Codable, Equatable, Identifiable {
    public var id: String { date }
    public var date: String // "yyyy-MM-dd"
    public var totalMinutes: Int
    public var coolingMinutes: Int
    public var heatingMinutes: Int
    public var fanMinutes: Int
    public var dehumMinutes: Int
    public var totalKWh: Double
    public var totalCost: Double

    public init(
        date: String,
        totalMinutes: Int = 0,
        coolingMinutes: Int = 0,
        heatingMinutes: Int = 0,
        fanMinutes: Int = 0,
        dehumMinutes: Int = 0,
        totalKWh: Double = 0.0,
        totalCost: Double = 0.0
    ) {
        self.date = date
        self.totalMinutes = totalMinutes
        self.coolingMinutes = coolingMinutes
        self.heatingMinutes = heatingMinutes
        self.fanMinutes = fanMinutes
        self.dehumMinutes = dehumMinutes
        self.totalKWh = totalKWh
        self.totalCost = totalCost
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

        if let data = UserDefaults.standard.data(forKey: "energyHistoryRecords"),
           let saved = try? JSONDecoder().decode([EnergyDayRecord].self, from: data) {
            self.historyRecords = saved
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
        windSpeed: String?
    ) -> Double {
        guard isPowerOn else {
            return 1.5 // 待机微功耗 1.5W
        }

        let mode = modeCode ?? "0"
        let windOffset: Double = {
            guard let wind = windSpeed?.lowercased() else { return 40.0 }
            if wind.contains("微") || wind.contains("静") { return 15.0 }
            if wind.contains("低") { return 35.0 }
            if wind.contains("中") { return 65.0 }
            if wind.contains("高") { return 110.0 }
            if wind.contains("强") { return 180.0 }
            return 40.0
        }()

        var power: Double = 400.0

        switch mode {
        case "2":
            // 送风模式：仅室内风机运转，极其省电
            power = 15.0 + windOffset * 0.4
            return min(max(power, 15.0), 65.0)

        case "3":
            // 除湿模式：低频恒定除湿
            power = 420.0 + windOffset * 0.5
            return min(max(power, 300.0), 600.0)

        case "1":
            // 制热模式：基准功率较高
            let delta = max(0.0, (targetTemp ?? 20.0) - (indoorTemp ?? 18.0))
            power = 550.0 + (delta * 110.0) + windOffset
            return min(max(power, 220.0), 1650.0)

        case "0":
            fallthrough
        default:
            // 制冷模式：温差驱动变频功率
            let delta = max(0.0, (indoorTemp ?? 26.0) - (targetTemp ?? 25.0))
            power = 380.0 + (delta * 95.0) + windOffset
            return min(max(power, 180.0), 1450.0)
        }
    }

    // MARK: - 周期用电积分累计

    /// 记录 1 分钟空调运行采样并积分计入当日电量
    public func accumulateMinuteSample(
        isPowerOn: Bool,
        modeCode: String?,
        targetTemp: Double?,
        indoorTemp: Double?,
        windSpeed: String?
    ) {
        let now = Date()
        let powerW = estimateInstantaneousPower(
            isPowerOn: isPowerOn,
            modeCode: modeCode,
            targetTemp: targetTemp,
            indoorTemp: indoorTemp,
            windSpeed: windSpeed
        )
        self.currentInstantaneousPower = powerW

        // 关机时仅更新瞬时功率，不大量累计能耗账单
        guard isPowerOn else { return }

        let dateKey = DateFormatter.dayDateFormatter.string(from: now)
        let rate = pricingConfig.rate(for: now)

        // 1 分钟耗电量 (kWh) = P(W) * (1/60 h) / 1000
        let deltaKWh = (powerW / 60.0) / 1000.0
        let deltaCost = deltaKWh * rate

        let mode = modeCode ?? "0"

        if let idx = historyRecords.firstIndex(where: { $0.date == dateKey }) {
            historyRecords[idx].totalMinutes += 1
            historyRecords[idx].totalKWh += deltaKWh
            historyRecords[idx].totalCost += deltaCost

            switch mode {
            case "0": historyRecords[idx].coolingMinutes += 1
            case "1": historyRecords[idx].heatingMinutes += 1
            case "2": historyRecords[idx].fanMinutes += 1
            case "3": historyRecords[idx].dehumMinutes += 1
            default: break
            }
        } else {
            var newRecord = EnergyDayRecord(date: dateKey)
            newRecord.totalMinutes = 1
            newRecord.totalKWh = deltaKWh
            newRecord.totalCost = deltaCost
            switch mode {
            case "0": newRecord.coolingMinutes = 1
            case "1": newRecord.heatingMinutes = 1
            case "2": newRecord.fanMinutes = 1
            case "3": newRecord.dehumMinutes = 1
            default: break
            }
            historyRecords.insert(newRecord, at: 0)
            if historyRecords.count > 60 {
                historyRecords = Array(historyRecords.prefix(60))
            }
        }
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
