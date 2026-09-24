import SwiftUI
import HaierACCore

/// 智能用电能耗估算与节能减排管家 Bento 卡片 (v1.9.20)
struct EcoEnergySection: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var energyEngine = EnergyAnalyticsEngine.shared
    @State private var showPricingSheet = false

    private var today: EnergyDayRecord {
        energyEngine.todayRecord
    }

    private var currentPowerW: Double {
        energyEngine.currentInstantaneousPower
    }

    private var ecoScore: Int {
        // 全屋多设备运行加权能效评分 (v1.9.29 统一全屋设备)
        let runningDevices = model.allUnifiedDevices.filter {
            model.attribute("onOffStatus", deviceId: $0.id)?.boolValue == true
        }
        let targetTemps = runningDevices.compactMap {
            model.attribute("targetTemperature", deviceId: $0.id)?.doubleValue
        }
        let avgTarget: Double? = {
            if !targetTemps.isEmpty {
                return targetTemps.reduce(0.0, +) / Double(targetTemps.count)
            }
            let fallbackId = model.menuBarDeviceId ?? model.allUnifiedDevices.first?.id ?? ""
            return model.attribute("targetTemperature", deviceId: fallbackId)?.doubleValue
        }()

        return energyEngine.calculateEcoScore(
            activeSleepSession: model.activeSleepSession != nil,
            targetTemp: avgTarget
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            // 顶栏
            HStack(spacing: 8) {
                Image(systemName: "bolt.batteryblock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dynamic(light: 0x34C759, dark: 0x30D158))

                Text("能耗与电费估算")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)
                    .tracking(0.4)

                Spacer()

                // 瞬时功率胶囊
                HStack(spacing: 4) {
                    Circle()
                        .fill(currentPowerW > 10.0 ? Theme.success : Theme.inkTertiary)
                        .frame(width: 6, height: 6)

                    Text(String(format: "%.0f W", currentPowerW))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)

                    Text(currentPowerW > 10.0 ? "运行中" : "待机")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.surface2)
                .clipShape(Capsule())

                // 电价设置按钮
                Button {
                    showPricingSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "yensign.circle")
                            .font(.system(size: 11))
                        Text("电价设置")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(Theme.secondaryButtonStyle())
            }

            // Bento 内容卡片
            VStack(spacing: Theme.spaceMD) {
                // 指标三列
                HStack(spacing: Theme.spaceSM) {
                    metricTile(
                        title: "今日累计耗电",
                        value: String(format: "%.2f", today.totalKWh),
                        unit: "kWh",
                        subtitle: "全屋墙钟约 \(today.totalMinutes) 分钟",
                        color: Color.dynamic(light: 0x0071E3, dark: 0x2997FF)
                    )

                    metricTile(
                        title: "今日预估电费",
                        value: String(format: "¥ %.2f", today.totalCost),
                        unit: "",
                        subtitle: energyEngine.pricingConfig.peakValleyEnabled ? "峰谷分时计价" : "基准 \(String(format: "%.2f", energyEngine.pricingConfig.flatRate))元/度",
                        color: Color.dynamic(light: 0x34C759, dark: 0x30D158)
                    )

                    metricTile(
                        title: "节能评分",
                        value: "\(ecoScore)",
                        unit: "分",
                        subtitle: ecoScore >= 85 ? "能效优异" : "建议微调",
                        color: Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF)
                    )
                }

                // 今日各工况运行时长分布 (v1.9.26 自洽分析)
                if today.totalMinutes > 0 {
                    todayModeBreakdownView(today: today)
                }

                // 7 日用电柱状图
                durationBarChart

                // 节能减排微建议
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.success)

                    Text("节能贴士：夏季设定 26°C 并配合微风与智能睡眠温阶，比 22°C 节能约 28%。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSubtle)

                    Spacer()
                }
                .padding(8)
                .background(Theme.surface2)
                .cornerRadius(Theme.radiusSM)
            }
            .padding(Theme.spaceMD)
            .background(Theme.cardBackground(Theme.surface1))
            .cornerRadius(Theme.radiusMD)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMD)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }
        .padding(.horizontal, Theme.spaceLG)
        .sheet(isPresented: $showPricingSheet) {
            pricingConfigSheet
        }
    }

    // MARK: - 单项指标卡

    private func metricTile(title: String, value: String, unit: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.inkSubtle)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkTertiary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface2)
        .cornerRadius(Theme.radiusSM)
    }

    // MARK: - 7 日用电趋势柱状图

    private var durationBarChart: some View {
        let list = energyEngine.recent7DaysRecords
        let maxKWh = max(4.0, list.map(\.totalKWh).max() ?? 4.0)

        return VStack(alignment: .leading, spacing: 6) {
            Text("近 7 日每日耗电对比 (kWh)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkSubtle)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(list) { rec in
                    let heightRatio = min(max(rec.totalKWh / maxKWh, 0.08), 1.0)
                    VStack(spacing: 3) {
                        Text(String(format: "%.1f", rec.totalKWh))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.inkSubtle)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.dynamic(light: 0x34C759, dark: 0x30D158).opacity(0.8))
                            .frame(height: max(12, 55 * CGFloat(heightRatio)))
                            .frame(maxWidth: .infinity)

                        Text(shortDate(rec.date))
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
            }
            .frame(height: 80)
            .padding(.top, 2)
        }
    }

    private func shortDate(_ str: String) -> String {
        let parts = str.split(separator: "-")
        guard parts.count == 3 else { return str }
        return "\(parts[1])/\(parts[2])"
    }

    // MARK: - 今日各工况运行时长分布 (v1.9.26, v1.9.36: 统一采用 EnergyDayRecord 比例模型)

    private func todayModeBreakdownView(today: EnergyDayRecord) -> some View {
        HStack(spacing: 8) {
            Text("工况分布:")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.inkSubtle)

            if today.coolingMinutes > 0 {
                let pct = Int(round(today.coolingRatio * 100))
                modeTimeTag(label: "制冷", minutes: today.coolingMinutes, percentage: pct, color: Color.blue)
            }
            if today.heatingMinutes > 0 {
                let pct = Int(round(today.heatingRatio * 100))
                modeTimeTag(label: "制热", minutes: today.heatingMinutes, percentage: pct, color: Color.orange)
            }
            if today.dehumMinutes > 0 {
                let pct = Int(round(today.dehumRatio * 100))
                modeTimeTag(label: "除湿", minutes: today.dehumMinutes, percentage: pct, color: Color.teal)
            }
            if today.fanMinutes > 0 {
                let pct = Int(round(today.fanRatio * 100))
                modeTimeTag(label: "送风", minutes: today.fanMinutes, percentage: pct, color: Color.gray)
            }
            if today.unknownMinutes > 0 {
                let pct = Int(round(today.unknownRatio * 100))
                modeTimeTag(label: "其他", minutes: today.unknownMinutes, percentage: pct, color: Color.purple)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
    }

    private func modeTimeTag(label: String, minutes: Int, percentage: Int = 0, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            let text = percentage > 0 ? "\(label) \(minutes)m (\(percentage)%)" : "\(label) \(minutes)m"
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
    }

    // MARK: - 电价设置 Sheet

    private var pricingConfigSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("电费与峰谷电价配置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                Spacer()

                Button("完成") {
                    showPricingSheet = false
                }
                .buttonStyle(Theme.secondaryButtonStyle())
            }
            .padding(Theme.spaceMD)

            Divider().overlay(Theme.hairlineSubtle)

            VStack(alignment: .leading, spacing: Theme.spaceMD) {
                // 单一电价
                HStack {
                    Text("常规基准电价")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink)

                    Spacer()

                    TextField("", value: $energyEngine.pricingConfig.flatRate, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)

                    Text("元 / 度")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSubtle)
                }

                // 峰谷电价开关
                Toggle(isOn: $energyEngine.pricingConfig.peakValleyEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用峰谷分时电价")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Text("白天峰时段 (08:00~22:00) 与夜间谷时段 (22:00~08:00)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
                .toggleStyle(.checkbox)

                if energyEngine.pricingConfig.peakValleyEnabled {
                    VStack(spacing: 8) {
                        HStack {
                            Text("峰时电价 (08:00 ~ 22:00)")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkSubtle)
                            Spacer()
                            TextField("", value: $energyEngine.pricingConfig.peakRate, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                            Text("元 / 度")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkSubtle)
                        }

                        HStack {
                            Text("谷时电价 (22:00 ~ 08:00)")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkSubtle)
                            Spacer()
                            TextField("", value: $energyEngine.pricingConfig.valleyRate, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                            Text("元 / 度")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkSubtle)
                        }
                    }
                    .padding(10)
                    .background(Theme.surface2)
                    .cornerRadius(Theme.radiusSM)
                }

                Spacer()
            }
            .padding(Theme.spaceLG)
        }
        .frame(width: 380, height: 320)
        .background(Theme.canvas)
    }
}
