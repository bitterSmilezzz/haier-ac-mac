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
        let sumModes = coolingMinutes + heatingMinutes + fanMinutes + dehumMinutes + unknownMinutes
        self.totalDeviceMinutes = totalDeviceMinutes > 0 ? totalDeviceMinutes : max(sumModes, totalMinutes)
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
        isSelfCleaning: Bool = false,
        continuousMinutes: Int = 0,
        cleanlinessFactor: Double = 1.0,
        filterCleanlinessPct: Int = 100
    ) -> Double {
        // 待机状态快速短路返回（待机微功耗 1.5W，避免关机时无意义的风机风速与室内温差计算开销） (v1.9.115)
        guard isPowerOn || isSelfCleaning else {
            return 1.5
        }

        let windOffset: Double = {
            let wind = windSpeed?.lowercased()
            if let wind = wind {
                if wind.contains("暴") || wind.contains("5档") || wind.contains("五档") || wind == "5" ||
                   wind.contains("超强") || wind.contains("最大") || wind.contains("极速") ||
                   wind.contains("level5") || wind.contains("level_5") || wind.contains("speed5") || wind.contains("speed_5") || wind.contains("gear5") || wind.contains("gear_5") {
                    return 180.0
                }
                if wind.contains("4档") || wind.contains("四档") || wind == "4" ||
                   wind.contains("强") || wind.contains("turbo") || wind.contains("高速") ||
                   wind.contains("level4") || wind.contains("level_4") || wind.contains("speed4") || wind.contains("speed_4") || wind.contains("gear4") || wind.contains("gear_4") {
                    return 140.0
                }
                if wind.contains("3档") || wind.contains("三档") || wind == "3" ||
                   wind.contains("高") || wind.contains("high") || wind.contains("大风") || wind.contains("大") ||
                   wind.contains("level3") || wind.contains("level_3") || wind.contains("speed3") || wind.contains("speed_3") || wind.contains("gear3") || wind.contains("gear_3") {
                    return 100.0
                }
                if wind.contains("中") || wind.contains("medium") || wind.contains("mid") ||
                   wind.contains("2档") || wind.contains("二档") || wind.contains("两档") || wind == "2" || wind.contains("中速") ||
                   wind.contains("level2") || wind.contains("level_2") || wind.contains("speed2") || wind.contains("speed_2") || wind.contains("gear2") || wind.contains("gear_2") {
                    return 65.0
                }
                if wind.contains("低") || wind.contains("low") ||
                   wind.contains("1档") || wind.contains("一档") || wind == "1" || wind.contains("小风") || wind.contains("低速") ||
                   wind.contains("level1") || wind.contains("level_1") || wind.contains("speed1") || wind.contains("speed_1") || wind.contains("gear1") || wind.contains("gear_1") {
                    return 35.0
                }
                if wind.contains("微") || wind.contains("静") || wind.contains("quiet") || wind.contains("mute") || wind.contains("micro") || wind.contains("柔") ||
                   wind.contains("0档") || wind.contains("零档") || wind == "0" || wind == "零" ||
                   wind.contains("level0") || wind.contains("level_0") || wind.contains("speed0") || wind.contains("speed_0") || wind.contains("gear0") || wind.contains("gear_0") {
                    return 15.0
                }
            }
            // 自动风速热物理自适应风机电动力学模型 (v1.9.61)
            // 变频内机电控芯片在自动风速下根据运行工况与室内外热负荷动态调节风机转速：
            // 1. 除湿工况（.dehumidify）：强制低通量微风防止冷凝水重蒸发 (25W)
            // 2. 送风工况（.fan）：平稳中风对流 (50W)
            // 3. 制冷/制热/自动工况：
            //    大温差重载（|indoor - target| >= 4.0°C）：高频强风加速室内对流 (120W)
            //    稳态维持态（|indoor - target| <= 0.8°C）：静音低风节能 (20W)
            //    过渡温差：连续线性热阻尼插值 (20W ~ 120W)
            let mode = ACModeCode.match(from: modeCode)
            if mode == .dehumidify {
                return 25.0
            } else if mode == .fan {
                return 50.0
            } else if let indoor = indoorTemp, let target = targetTemp {
                let tempDelta = abs(indoor - target)
                if tempDelta >= 4.0 {
                    return 120.0
                } else if tempDelta <= 0.8 {
                    return 20.0
                } else {
                    let progress = (tempDelta - 0.8) / 3.2
                    return 20.0 + (progress * 100.0)
                }
            } else {
                return 50.0 // 无温度传感器中性基准
            }
        }()

        if isSelfCleaning {
            // 56°C 蒸发器高温除菌自清洁工况（急冷结霜、微波解冻与 56°C 恒温烘干灭菌）：
            // 动态四阶段相变热力学动力学模型 (v1.9.119, v1.9.120 耦合环境显热与潜热连续微补偿):
            // 阶段 1 (0~5 分钟, 深冷结霜凝水): 压缩机高频运转快速降温至 0°C 以下使翅片凝霜凝固尘垢，基准功率 ~880W ~ 960W + windOffset*0.4
            //        若室内高湿(RH >= 60%)，空气凝华结霜潜热负荷提升 (+0W ~ 50W)；若室内温高(indoor >= 25°C)，降温初始显热负荷提升 (+0W ~ 40W)；
            // 阶段 2 (5~10 分钟, 逆循环微解冻冲刷): 四通阀换向快速化霜，利用大量融水强力冲刷剥离翅片积尘，基准功率 ~780W + windOffset*0.3;
            // 阶段 3 (10~18 分钟, 56°C 高温恒温烘干杀菌): 变频压缩机制热大压比持续输出，蒸发器表面维持 56°C 恒温 8 分钟以上灭菌烘干，基准功率 ~1000W ~ 1040W + windOffset*0.5
            //        若室内偏冷(indoor <= 18°C)，蒸发器向室内自然散热加剧，需额外提高压比维持 56°C 灭菌温区 (+0W ~ 50W)；
            // 阶段 4 (>= 18 分钟, 降温送风排湿恢复): 压缩机停机降压，贯流风机从 56°C 翅片高温显热冷却连续平滑衰减至常温微风稳态，
            //        排出残余水汽并冷却翅片（基准功率 ~42W ~ 58W + windOffset*0.2 + 湿敏气阻微补偿），
            //        同时受滤网积尘流阻与极端阻抗连续调制 (1.00 ~ 1.065)。 (v1.9.123)
            let cleaningMinutes = continuousMinutes
            let cleaningPower: Double
            if cleaningMinutes < 5 {
                let ramp = min(1.0, Double(cleaningMinutes) / 5.0)
                let latentFrost: Double = {
                    guard let hum = indoorHumidity, hum >= 60.0 else { return 0.0 }
                    return min(50.0, (hum - 60.0) * 1.25)
                }()
                let sensibleFrost: Double = {
                    guard let indoor = indoorTemp, indoor >= 25.0 else { return 0.0 }
                    return min(40.0, (indoor - 25.0) * 4.0)
                }()
                cleaningPower = 880.0 + (ramp * 80.0) + (windOffset * 0.4) + latentFrost + sensibleFrost
            } else if cleaningMinutes < 10 {
                // 阶段 2 (5~10 分钟, 逆循环微解冻冲刷剥离):
                // 四通阀快速换向使高温冷媒逆向流入蒸发器，使冰霜迅速脱落剥离并随融水冲刷排出 (v1.9.121 逆循环相变融霜潜热与防再结冰动力学自洽)。
                // 1. 冰层相变吸热熔化与冲刷潜热曲线 (Latent Heat Melting Phase Ramp):
                //    第 5~7 分钟相变剧烈熔化吸热达到峰值 (+0W ~ 40W)，随后平缓回落至稳定冲刷态；
                // 2. 高湿环境霜层厚度潜热补偿:
                //    若阶段 1 产生较厚霜层 (高湿 RH >= 60%)，需要更充分的相变熔化潜热 (+0W ~ 40W)；
                // 3. 低温环境防二次结冰热力补偿:
                //    若室内温低 (indoor <= 16°C)，翅片融霜向室内温差传热损耗提高且需防化霜水二次再结冰 (+0W ~ 35W)；
                // 4. 滤网严重积尘气道流阻微补偿:
                //    若 filterCleanlinessPct < 50，气道阻力对排风冲刷产生微阻尼调制 (1.00 ~ 1.04)。
                let meltRamp: Double = {
                    if cleaningMinutes <= 7 {
                        return Double(cleaningMinutes - 5) / 2.0 * 40.0
                    } else {
                        return max(0.0, (1.0 - (Double(cleaningMinutes - 7) / 3.0)) * 40.0)
                    }
                }()
                let latentMelt: Double = {
                    guard let hum = indoorHumidity, hum >= 60.0 else { return 0.0 }
                    return min(40.0, (hum - 60.0) * 1.0)
                }()
                let sensibleMelt: Double = {
                    guard let indoor = indoorTemp, indoor <= 16.0 else { return 0.0 }
                    return min(35.0, (16.0 - indoor) * 4.375)
                }()
                let washFilter = filterCleanlinessPct < 50 ? 1.0 + (Double(50 - max(0, filterCleanlinessPct)) / 50.0) * 0.04 : 1.0
                cleaningPower = (780.0 + meltRamp + (windOffset * 0.3) + latentMelt + sensibleMelt) * washFilter
            } else if cleaningMinutes < 18 {
                // 阶段 3 (10~18 分钟, 56°C 高温恒温烘干灭菌):
                // 变频压缩机制热大压比持续输出，蒸发器表面维持 56°C 恒温 8 分钟以上灭菌烘干 (v1.9.122 升温冲顶与残水蒸发汽化潜热动力学连续演进)。
                // 1. 56°C 升温冲顶与恒温杀菌平台两段式动力学 (Heat Ramp Up & 56°C Thermal Plateau):
                //    第 10~12 分钟 (升温冲顶期): 压缩机由解冻冲刷常温快速超频拉升至 56°C 灭菌温区，额外产生快速升温爬坡负荷 (+0W ~ 50W)；
                //    第 12~18 分钟 (恒温灭菌平台期): 维持 56°C 稳态热平衡，基准功率维持在 1010W ~ 1040W；
                // 2. 翅片融水剧烈汽化蒸发潜热连续动力学补偿 (Latent Heat of Vaporization):
                //    阶段 2 融水冲刷后残留在换热器翅片及集水槽的大量水膜在 56°C 高温下剧烈蒸发汽化 (水汽化潜热 2260 kJ/kg)。
                //    若室内环境相对湿度较高 (indoorHumidity >= 60%)，室内空气水蒸气分压高，换热器表面水分汽化扩散阻力增大，
                //    压缩机需提高排气温度与冷媒质量流量以维持 56°C 换热器壁面温度，产生连续水汽蒸发潜热补偿 (+0W ~ 45W)；
                // 3. 室内低温向外界散热损耗补偿 (Cold Loss Compensation):
                //    若室内偏冷 (indoor <= 18°C)，蒸发器向室内自然对流换热温差扩大，需额外提高压比维持 56°C 灭菌温区 (+0W ~ 50W)；
                // 4. 滤网积尘气道流阻微补偿 (Filter Airflow Impedance):
                //    若滤网积尘严重 (filterCleanlinessPct < 50)，进风受阻导致换热器内部热对流排出受阻，微风风机与压缩机产生连续气道流阻调制 (1.00 ~ 1.05)。
                let rampBoost: Double = {
                    if cleaningMinutes < 12 {
                        let progress = Double(cleaningMinutes - 10) / 2.0
                        return (1.0 - progress) * 50.0
                    }
                    return 0.0
                }()
                let latentVapor: Double = {
                    guard let hum = indoorHumidity, hum >= 60.0 else { return 0.0 }
                    return min(45.0, (hum - 60.0) * 1.125)
                }()
                let coldLoss: Double = {
                    guard let indoor = indoorTemp, indoor <= 18.0 else { return 0.0 }
                    return min(50.0, (18.0 - indoor) * 5.0)
                }()
                let heatFilter = filterCleanlinessPct < 50 ? 1.0 + (Double(50 - max(0, filterCleanlinessPct)) / 50.0) * 0.05 : 1.0
                let baseDryPower = 1010.0 + rampBoost + (windOffset * 0.5) + latentVapor + coldLoss
                cleaningPower = baseDryPower * heatFilter
            } else {
                // 阶段 4 (>= 18 分钟, 送风排湿冷却恢复):
                // 贯流风机以微风排出残余水汽并对流冷却翅片 (v1.9.123 翅片显热衰减连续动力学与高湿残余微水滴排湿阻力微补偿)。
                // 1. 56°C 翅片高温对流冷却显热衰减与风机转速降频过渡 (Sensible Cooling Thermal Decay):
                //    第 18 分钟刚结束高温灭菌时翅片处于 56°C 高温，贯流风机以较高转速对流带走翅片显热 (+16W 爬坡初态)，
                //    随着翅片温度向室温连续对流冷却，在第 18~20 分钟单调平滑衰减至 0W，回到 42W 稳态微风基准；
                // 2. 高湿环境残余微水滴附壁与风道气流阻力微补偿 (Residual Moisture Drag):
                //    若室内空气相对湿度偏高 (indoorHumidity >= 60%)，风道潮湿与微水滴排出使贯流风机微阻力上升 (+0W ~ 10W)；
                // 3. 滤网积尘流阻与极端阻抗微喘振调制 (1.00 ~ 1.065)。
                let coolRamp = max(0.0, (1.0 - (Double(cleaningMinutes - 18) / 2.0)) * 16.0)
                let latentDrag: Double = {
                    guard let hum = indoorHumidity, hum >= 60.0 else { return 0.0 }
                    return min(10.0, (hum - 60.0) * 0.25)
                }()
                let clampedPct = max(0, filterCleanlinessPct)
                let basePenalty = filterCleanlinessPct < 50 ? (Double(50 - clampedPct) / 50.0) * 0.05 : 0.0
                let extremePenalty = clampedPct <= 10 ? (Double(10 - clampedPct) / 10.0) * 0.015 : 0.0
                let fanFilter = 1.0 + basePenalty + extremePenalty
                let baseFanPower = 42.0 + coolRamp + latentDrag + (windOffset * 0.2)
                cleaningPower = baseFanPower * fanFilter
            }
            return min(max(cleaningPower, 35.0), 1250.0)
        }

        guard isPowerOn else {
            return 1.5 // 待机微功耗 1.5W
        }

        // 变频压缩机与换热器连续高负荷热饱和阻抗衰减微补偿 (Continuous Thermal Soak Drift) (v1.9.79, v1.9.90 全工况包含未识别工况统一纳管):
        // 变频空调机组连续运转超 120 分钟时，外机冷凝器热积累或蒸发器化霜热阻导致稳态 COP 产生 2% ~ 5% 的微漂移：
        // 120 分钟内为 1.00 基准；120 ~ 360 分钟平滑线性上升至 1.045；超过 360 分钟钳制在 1.05。
        let soakMultiplier: Double = {
            guard isPowerOn && !isSelfCleaning && continuousMinutes > 120 else { return 1.0 }
            let progress = min(1.0, Double(continuousMinutes - 120) / 240.0)
            return 1.0 + (progress * 0.045)
        }()

        // 蒸发器自清洁洁净度热阻力与换热效率连续动力学微补偿 (Evaporator Cleanliness Efficiency Bonus) (v1.9.112):
        // 完成 56°C 自清洁后，换热翅片洁净无尘垢水膜，空气阻力降低且传热系数提升，
        // 在 14 天自清洁保护期内（cleanlinessFactor 介于 0.90 ~ 1.00），变频压缩机维持恒温所需能耗享受 0% ~ 4% 平滑节能收益：
        // 0.90 对应 0.96 负荷乘数（节能 4%），随微尘累积平滑过渡至 1.00（无衰减）。
        let cleanMultiplier: Double = {
            guard isPowerOn && !isSelfCleaning && cleanlinessFactor < 1.0 else { return 1.0 }
            let bonus = (1.0 - max(0.90, cleanlinessFactor)) * 0.40
            return max(0.95, 1.0 - bonus)
        }()

        // 滤网积尘气道流阻与换热动力学衰减连续微补偿 (Air Filter Flow Resistance Impedance Model) (v1.9.113, v1.9.118 极端阻抗非线性微喘振动力学自洽):
        // 进风滤网积尘阻塞时，回风道气阻增大且通过蒸发器的循环风量衰减，机组为达到同等设定温控效果需额外付出风机与压缩机负荷：
        // - 洁净度 >= 50%：额定空气动力学通量，气阻负荷因子为 1.00；
        // - 10% < 洁净度 < 50%：气道受阻，负荷乘数平滑单调线性插值上升至 1.04；
        // - 洁净度 <= 10%（极度重度堵塞态）：流体动力学边界层分离阻力激增，产生非线性二次阻抗补偿 (额外 0% ~ 1.5%，最高综合气阻惩罚达到 1.065 即 +6.5%)。
        let filterMultiplier: Double = {
            guard isPowerOn && !isSelfCleaning && filterCleanlinessPct < 50 else { return 1.0 }
            let clampedPct = max(0, filterCleanlinessPct)
            let basePenalty = (Double(50 - clampedPct) / 50.0) * 0.05
            let extremePenalty: Double = {
                guard clampedPct <= 10 else { return 0.0 }
                let progress = Double(10 - clampedPct) / 10.0
                return progress * 0.015
            }()
            return min(1.065, 1.0 + basePenalty + extremePenalty)
        }()

        // 变频压缩机开机软启动与高压建立动态升频微阻尼模型 (Compressor Soft-Start Dynamic Ramping Model) (v1.9.114):
        // 直流变频空调压缩机由待机状态启动时，电控变频驱动器为避免冷冻润滑油剧烈吸入（防液击）以及对家庭电网产生冲击电流，
        // 遵循 GB/T 7725 与微电脑电控程序执行 0 ~ 3 分钟平滑变频软启动策略：
        // - continuousMinutes == 0 (前 60 秒)：低频起动段 (20~30Hz)，压缩机负荷乘数约为 0.65，平滑建立排气压差；
        // - continuousMinutes == 1 (第 1~2 分钟)：变频线性升频段 (30~55Hz)，负荷乘数平滑上升至 0.85；
        // - continuousMinutes == 2 (第 2~3 分钟)：接近目标工况频率段，负荷乘数平滑上升至 0.95；
        // - continuousMinutes >= 3：达到额定变频温差调频状态，负荷乘数为 1.00。
        // 送风工况（仅室内风机运转，无压缩机）与自清洁工况不参与软启动乘数折减。
        let softStartMultiplier: Double = {
            guard isPowerOn && !isSelfCleaning && continuousMinutes < 3 else { return 1.0 }
            switch continuousMinutes {
            case 0: return 0.65
            case 1: return 0.85
            case 2: return 0.95
            default: return 1.0
            }
        }()

        let dynamicMultiplier = soakMultiplier * cleanMultiplier * filterMultiplier * softStartMultiplier

        // 未识别模式采用物理中性功率估算策略（冷热综合无偏估计 + 恒温维持态平滑热阻尼模型 + 热饱和漂移微补偿 + 软启动无截断自洽，v1.9.86, v1.9.90, v1.9.112, v1.9.117）：
        // 1. 若室内温度与设定温度均有效，采用制冷动力曲线与制热动力曲线在温差绝对值 |ΔT| 下的双向无偏中性基准：
        //    - 恒温稳态区 (|ΔT| <= 0.0°C)：制冷(220W)与制热(300W)平衡态无偏均值基准 260.0W + (windOffset * 0.6)；
        //    - 接近平衡区 (0.0 < |ΔT| < 1.0°C)：平滑阻尼动态插值过渡至 465.0W (windFactor = 0.6 + |ΔT|*0.4, P = 260.0 + |ΔT|*205.0 + windOffset*windFactor)；
        //    - 变频重载区 (|ΔT| >= 1.0°C)：465.0 + ((|ΔT| - 1.0) * 102.5) + windOffset；
        //    实现严格 C^0 级平滑连续，彻底消除恒温态估算高达 465W+ 导致的能耗倒挂与虚标；
        //    clamp 限制在 [200.0 * softStartMultiplier, 1550.0] W 区间；
        // 2. 若温度字段缺失（室内或设定温度为 nil），则采用 1.5 匹直流变频压缩机典型低频维持中性基准功率 (350W + windOffset，clamp [180.0 * softStartMultiplier, 600.0] W)，避免盲目套用大温差曲线导致功率虚标。
        guard let mode = ACModeCode.match(from: modeCode) else {
            if let indoor = indoorTemp, let target = targetTemp {
                let delta = abs(indoor - target)
                let neutralPower: Double
                if delta <= 0.0 {
                    neutralPower = 260.0 + (windOffset * 0.6)
                } else if delta < 1.0 {
                    let windFactor = 0.6 + (delta * 0.4)
                    neutralPower = 260.0 + (delta * 205.0) + (windOffset * windFactor)
                } else {
                    neutralPower = 465.0 + ((delta - 1.0) * 102.5) + windOffset
                }
                let minFloor = 200.0 * softStartMultiplier
                return min(max(neutralPower * dynamicMultiplier, minFloor), 1550.0)
            } else {
                let neutralPower = 350.0 + windOffset
                let minFloor = 180.0 * softStartMultiplier
                return min(max(neutralPower * dynamicMultiplier, minFloor), 600.0)
            }
        }

        switch mode {
        case .fan:
            // 送风模式：仅室内风机运转，阶梯风速动力学梯度 (v1.9.39, v1.9.42 拓展强劲风量上限, v1.9.116 滤网积尘流阻电动力学连续微补偿, v1.9.118 贯流风机无刷电机起步爬升与极度堵塞流阻二次微补偿)
            // 贯流风机由无刷直流电机（BLDC）驱动，当进风滤网积尘气阻上升时，电机需增加扭矩以克服回风道静压差维持对流循环：
            // - 洁净度 >= 50%：额定空气动力学通量，气阻负荷因子为 1.00；
            // - 洁净度 < 50%：进风截面受阻，气阻电功率产生 0% ~ 6% 的微补偿线性平滑上升；
            // - 洁净度 <= 10%：极端微压湍流阻抗额外补偿 0% ~ 1.5% (最高 +7.5%)。
            // 软启动爬升段 (continuousMinutes < 2)：无刷电机克服风叶静惯量起步平滑过渡 (0.88 -> 0.96 -> 1.00)
            let fanFilterMultiplier: Double = {
                guard filterCleanlinessPct < 50 else { return 1.0 }
                let clampedPct = max(0, filterCleanlinessPct)
                let base = (Double(50 - clampedPct) / 50.0) * 0.06
                let extreme = clampedPct <= 10 ? (Double(10 - clampedPct) / 10.0) * 0.015 : 0.0
                return 1.0 + base + extreme
            }()
            let fanSoftStartMultiplier: Double = {
                guard continuousMinutes < 2 else { return 1.0 }
                return continuousMinutes == 0 ? 0.88 : 0.96
            }()
            let power = (14.0 + windOffset * 0.42) * fanFilterMultiplier * fanSoftStartMultiplier
            return min(max(power, 12.0), 85.0)

        case .dehumidify:
            // 除湿模式：多维环境湿度自适应变频能耗动力学模型 + 室内温度显热负荷与防结霜降频动态补偿 (v1.9.37, v1.9.44, v1.9.87 C^0 级平滑连续热阻尼重构, v1.9.117 软启动升频无截断自洽)
            // 典型变频空调除湿机制：
            // 1. 高湿析水重载区 (RH >= 70%)：蒸发器深度过冷持续冷凝析水，压缩机高频运转 (520W 基准 + 潜热补偿，最高 619W)
            // 2. 中湿温湿度平衡过渡区 (50% <= RH < 70%)：温湿度平衡变频除湿，双线性无缝连续热阻尼插值 (340W ~ 520W)
            // 3. 舒适/低湿微载维持区 (RH < 50%)：防过冷与防过度干燥，压缩机平滑降频至超低频稳态 (260W ~ 340W)
            // 4. 无湿度传感器兜底：回归标准中性基准 420W
            // 5. 室内温度热力学动态补偿 (v1.9.44)：
            //    - 高温显热补偿：当 indoor >= 28°C 时，湿空气显热负荷增加，压缩机负荷上升 (0W ~ 80W)；
            //    - 低温防霜降频：当 indoor <= 18°C 时，蒸发器面临结霜风险，变频压缩机自动阶梯降频保护 (-60W ~ 0W)。
            // 彻底消除此前在 55% RH (60W 跳变) 与 70% RH (20W 跳变) 处的非物理阶跃断崖，达成严密 C^0 级平滑连续。
            let basePower: Double
            if let hum = indoorHumidity {
                if hum >= 70.0 {
                    let excess = min(30.0, hum - 70.0)
                    basePower = 520.0 + (excess * 3.3)
                } else if hum >= 50.0 {
                    let progress = (hum - 50.0) / 20.0
                    basePower = 340.0 + (progress * 180.0)
                } else {
                    let lowFactor = max(0.0, hum / 50.0)
                    basePower = 260.0 + (lowFactor * 80.0)
                }
            } else {
                basePower = 420.0
            }

            let tempComp: Double = {
                guard let indoor = indoorTemp else { return 0.0 }
                if indoor >= 28.0 {
                    let excess = min(8.0, indoor - 28.0)
                    return excess * 10.0 // 最高 +80W
                } else if indoor <= 18.0 {
                    let deficit = min(8.0, 18.0 - indoor)
                    return -(deficit * 7.5) // 最低 -60W 防结霜降频
                }
                return 0.0
            }()

            let power = basePower + (windOffset * 0.5) + tempComp
            let minFloor = 200.0 * softStartMultiplier
            return min(max(power * dynamicMultiplier, minFloor), 730.0)

        case .heating:
            // 制热模式：变频温差动力学模型 + 恒温平衡区低频维持态阻尼 + 环境湿度结霜化霜/干燥热焓补偿 + 低温速热 PTC 辅助电热动力学 (v1.9.36, v1.9.39, v1.9.46, v1.9.117 软启动升频无截断自洽)
            let indoor = indoorTemp ?? 18.0
            let target = targetTemp ?? 20.0
            let delta = target - indoor

            // 环境湿度热力学动力学校准 (v1.9.46)：
            // 典型变频空调制热热力学：
            // 1. 高湿阴冷工况 (RH >= 65%)：室外换热器表面极易析霜结冰导致吸热阻抗剧增，变频系统提高排气温度压比并触发化霜热负荷补偿 (最高 +75W)；
            // 2. 干燥低湿工况 (RH <= 40%)：干燥空气定压比热容偏低且人体蒸发散热加快，系统增强热风对流维持热焓 (最高 +30W)
            let heatHumComp: Double = {
                guard let hum = indoorHumidity else { return 0.0 }
                if hum >= 65.0 {
                    let excess = min(30.0, hum - 65.0)
                    return excess * 2.5 // 最高 +75W 结霜化霜与高压补偿
                } else if hum <= 40.0 {
                    let deficit = min(20.0, 40.0 - hum)
                    return deficit * 1.5 // 最高 +30W 干燥空气热焓维持补偿
                }
                return 0.0
            }()

            let power: Double
            if delta <= 0.0 {
                // 已达到或高于设定温度：压缩机进入超节能恒温维持态
                power = 300.0 + (windOffset * 0.6) + (heatHumComp * 0.4)
            } else if delta < 1.0 {
                // 接近目标温差 (0 < ΔT < 1.0°C)：平滑过渡至稳态低频 (v1.9.85 变频连续热阻尼动态插值，彻底消除 1.0°C 阶跃断崖)
                let windFactor = 0.6 + (delta * 0.4)
                let humFactor = 0.4 + (delta * 0.6)
                power = 300.0 + (delta * 250.0) + (windOffset * windFactor) + (heatHumComp * humFactor)
            } else {
                // 严寒低温速热热力补偿：当室内温度偏低（indoor <= 17.0°C）且大温差升温（delta >= 4.0°C）时，
                // 拟真变频空调自动启动 PTC 辅助加热与大压比高频超载运转；
                // 采用双线性连续过渡阻尼模型 (v1.9.62 消除 15°C/5°C 阶跃断崖，平滑补偿 0W ~ 320W 电热与超载功率)
                let coldBoost: Double = {
                    if indoor <= 17.0 && delta >= 4.0 {
                        let indoorFactor = min(1.0, max(0.0, (17.0 - indoor) / 2.0)) // 17°C ~ 15°C 线性平滑插值
                        let deltaFactor = min(1.0, max(0.0, (delta - 4.0) / 1.0))    // 4°C ~ 5°C 线性平滑插值
                        let ramp = indoorFactor * deltaFactor
                        let deficit = min(10.0, max(0.0, 15.0 - indoor))
                        let excess = min(8.0, max(0.0, delta - 5.0))
                        return (120.0 * ramp) + (deficit * 10.0) + (excess * 12.0)
                    }
                    return 0.0
                }()
                power = 550.0 + ((delta - 1.0) * 110.0) + windOffset + coldBoost + heatHumComp
            }
            let minFloor = 220.0 * softStartMultiplier
            return min(max(power * dynamicMultiplier, minFloor), 1950.0)

        case .cooling:
            // 制冷模式：变频温差动力学模型 + 恒温平衡区低频维持态阻尼 + 环境湿度潜热冷凝补偿 + 酷暑高温大温差重载动力学校准 (v1.9.36, v1.9.40, v1.9.45, v1.9.117 软启动升频无截断自洽)
            let indoor = indoorTemp ?? 26.0
            let target = targetTemp ?? 25.0
            let delta = indoor - target

            // 环境湿度潜热冷凝补偿 (v1.9.45)：
            // 典型变频空调制冷热力学：空气流经蒸发器翅片时发生水汽冷凝相变释放汽化潜热(2260 kJ/kg)，
            // 在高湿环境(RH >= 65%)下潜热负料急剧攀升，压缩机需提高转速以维持冷凝析水能力 (最高补偿 +66W)；
            // 在极干燥环境(RH <= 40%)下水汽析出少，换热以显热为主，动态调减负荷 (-20W ~ 0W)
            let latentHumComp: Double = {
                guard let hum = indoorHumidity else { return 0.0 }
                if hum >= 65.0 {
                    let excess = min(30.0, hum - 65.0)
                    return excess * 2.2 // 最高 +66W
                } else if hum <= 40.0 {
                    let deficit = min(20.0, 40.0 - hum)
                    return -(deficit * 1.0) // 最低 -20W
                }
                return 0.0
            }()

            let power: Double
            if delta <= 0.0 {
                // 已达到或低于设定温度：压缩机进入超节能恒温维持态
                power = 220.0 + (windOffset * 0.6) + (latentHumComp * 0.4)
            } else if delta < 1.0 {
                // 接近目标温差 (0 < ΔT < 1.0°C)：平滑过渡至稳态低频 (v1.9.85 变频连续热阻尼动态插值，彻底消除 1.0°C 阶跃断崖)
                let windFactor = 0.6 + (delta * 0.4)
                let humFactor = 0.4 + (delta * 0.6)
                power = 220.0 + (delta * 160.0) + (windOffset * windFactor) + (latentHumComp * humFactor)
            } else {
                // 变频重载降温区 (ΔT >= 1.0°C)
                // 酷暑高温大温差超载动力学补偿：当室内温度偏高（indoor >= 28.0°C）且大温差降温（delta >= 4.0°C）时，
                // 拟真变频压缩机处于高频满载运转，且高温环境下外机冷凝器散热恶化导致冷凝压力与压比急剧攀升；
                // 采用双线性连续过渡阻尼模型 (v1.9.62 消除 30°C/5°C 阶跃断崖，平滑补偿 0W ~ 280W 热阻抗超载电热功率)
                let heatBoost: Double = {
                    if indoor >= 28.0 && delta >= 4.0 {
                        let indoorFactor = min(1.0, max(0.0, (indoor - 28.0) / 2.0)) // 28°C ~ 30°C 线性平滑插值
                        let deltaFactor = min(1.0, max(0.0, (delta - 4.0) / 1.0))   // 4°C ~ 5°C 线性平滑插值
                        let ramp = indoorFactor * deltaFactor
                        let excessIndoor = min(8.0, max(0.0, indoor - 30.0))
                        let excessDelta = min(8.0, max(0.0, delta - 5.0))
                        return (100.0 * ramp) + (excessIndoor * 12.0) + (excessDelta * 10.0)
                    }
                    return 0.0
                }()
                power = 380.0 + ((delta - 1.0) * 95.0) + windOffset + heatBoost + latentHumComp
            }
            let minFloor = 180.0 * softStartMultiplier
            return min(max(power * dynamicMultiplier, minFloor), 1800.0)

        case .auto:
            // 自动模式：根据室内与设定温差智能判别制冷或制热动力曲线，融合环境湿度微调与全气候极端温差超频动力学 (v1.9.36, v1.9.38, v1.9.41, v1.9.47, v1.9.48 全气候双向物理对称, v1.9.117 软启动升频无截断自洽)
            let indoor = indoorTemp ?? 25.0
            let target = targetTemp ?? 24.0
            if indoor >= target {
                let delta = indoor - target
                // 制冷分支环境湿度潜热冷凝补偿 (v1.9.48 与制冷独立工况达成 100% 物理对称：高湿潜热相变补偿最高 +66W，干燥空气负荷调减最高 -20W)
                let latentHumComp: Double = {
                    guard let hum = indoorHumidity else { return 0.0 }
                    if hum >= 65.0 {
                        let excess = min(30.0, hum - 65.0)
                        return excess * 2.2 // 最高 +66W
                    } else if hum <= 40.0 {
                        let deficit = min(20.0, 40.0 - hum)
                        return -(deficit * 1.0) // 最低 -20W
                    }
                    return 0.0
                }()
                let power: Double
                if delta <= 0.0 {
                    power = 220.0 + (windOffset * 0.6) + (latentHumComp * 0.4)
                } else if delta < 1.0 {
                    let windFactor = 0.6 + (delta * 0.4)
                    let humFactor = 0.4 + (delta * 0.6)
                    power = 220.0 + (delta * 160.0) + (windOffset * windFactor) + (latentHumComp * humFactor)
                } else {
                    // 酷暑极端高温与冷凝器恶化超频动力学补偿 (v1.9.62 双线性平滑过渡)
                    let heatBoost: Double = {
                        if indoor >= 28.0 && delta >= 4.0 {
                            let indoorFactor = min(1.0, max(0.0, (indoor - 28.0) / 2.0))
                            let deltaFactor = min(1.0, max(0.0, (delta - 4.0) / 1.0))
                            let ramp = indoorFactor * deltaFactor
                            let excessIndoor = min(8.0, max(0.0, indoor - 30.0))
                            let excessDelta = min(8.0, max(0.0, delta - 5.0))
                            return (100.0 * ramp) + (excessIndoor * 12.0) + (excessDelta * 10.0)
                        }
                        return 0.0
                    }()
                    power = 380.0 + ((delta - 1.0) * 95.0) + windOffset + latentHumComp + heatBoost
                }
                let minFloor = 180.0 * softStartMultiplier
                return min(max(power * dynamicMultiplier, minFloor), 1800.0)
            } else {
                let delta = target - indoor
                let power: Double
                // 全气候环境湿度热力学动力学校准 (v1.9.47 与制热独立工况达成 100% 物理对称：冬季高湿结霜化霜补偿最高 +75W，干燥热焓补偿最高 +30W)
                let heatHumOffset: Double = {
                    guard let hum = indoorHumidity else { return 0.0 }
                    if hum >= 65.0 {
                        let excess = min(30.0, hum - 65.0)
                        return excess * 2.5 // 最高 +75W 结霜化霜与高压补偿
                    } else if hum <= 40.0 {
                        let deficit = min(20.0, 40.0 - hum)
                        return deficit * 1.5 // 最高 +30W 干燥空气热焓维持补偿
                    }
                    return 0.0
                }()
                if delta <= 0.0 {
                    power = 300.0 + (windOffset * 0.6) + (heatHumOffset * 0.4)
                } else if delta < 1.0 {
                    let windFactor = 0.6 + (delta * 0.4)
                    let humFactor = 0.4 + (delta * 0.6)
                    power = 300.0 + (delta * 250.0) + (windOffset * windFactor) + (heatHumOffset * humFactor)
                } else {
                    // 严寒低温大温差 PTC 电辅热与大压比高频超载运转补偿 (v1.9.62 双线性平滑过渡)
                    let coldBoost: Double = {
                        if indoor <= 17.0 && delta >= 4.0 {
                            let indoorFactor = min(1.0, max(0.0, (17.0 - indoor) / 2.0))
                            let deltaFactor = min(1.0, max(0.0, (delta - 4.0) / 1.0))
                            let ramp = indoorFactor * deltaFactor
                            let deficit = min(10.0, max(0.0, 15.0 - indoor))
                            let excess = min(8.0, max(0.0, delta - 5.0))
                            return (120.0 * ramp) + (deficit * 10.0) + (excess * 12.0)
                        }
                        return 0.0
                    }()
                    power = 550.0 + ((delta - 1.0) * 110.0) + windOffset + heatHumOffset + coldBoost
                }
                let minFloor = 220.0 * softStartMultiplier
                return min(max(power * dynamicMultiplier, minFloor), 1950.0)
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
        public let continuousMinutes: Int
        public let cleanlinessFactor: Double
        public let filterCleanlinessPct: Int

        public init(
            deviceId: String,
            isPowerOn: Bool,
            modeCode: String?,
            targetTemp: Double?,
            indoorTemp: Double?,
            indoorHumidity: Double? = nil,
            windSpeed: String?,
            isSelfCleaning: Bool = false,
            continuousMinutes: Int = 0,
            cleanlinessFactor: Double = 1.0,
            filterCleanlinessPct: Int = 100
        ) {
            self.deviceId = deviceId
            self.isPowerOn = isPowerOn
            self.modeCode = modeCode
            self.targetTemp = targetTemp
            self.indoorTemp = indoorTemp
            self.indoorHumidity = indoorHumidity
            self.windSpeed = windSpeed
            self.isSelfCleaning = isSelfCleaning
            self.continuousMinutes = continuousMinutes
            self.cleanlinessFactor = cleanlinessFactor
            self.filterCleanlinessPct = filterCleanlinessPct
        }
    }

    /// 多设备全场景瞬时功率聚合与运行采样积分 (v1.9.21, v1.9.112 接入自清洁洁净度换热效率连续微补偿, v1.9.113 接入滤网积尘气阻动力学衰减连续微补偿)
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
                isSelfCleaning: sample.isSelfCleaning,
                continuousMinutes: sample.continuousMinutes,
                cleanlinessFactor: sample.cleanlinessFactor,
                filterCleanlinessPct: sample.filterCleanlinessPct
            )
            totalInstantaneousPower += power

            if sample.isPowerOn || sample.isSelfCleaning {
                hasAnyRunningDevice = true
                let devKWh = (power * deltaHours) / 1000.0
                totalIncrementalKWh += devKWh

                if sample.isSelfCleaning {
                    // 自清洁依据执行时相精确映射至动力学分类 (v1.9.120: 消除全程笼统归入制热导致的机时失真)
                    if sample.continuousMinutes < 10 {
                        runningCooling += 1 // 阶段 1&2 急速深冷与微解冻冲刷归入冷冻相变工况
                    } else if sample.continuousMinutes < 18 {
                        runningHeating += 1 // 阶段 3 56°C 恒温烘干灭菌归入高温热力学工况
                    } else {
                        runningFan += 1     // 阶段 4 常温微风排湿冷却归入平稳送风工况
                    }
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
