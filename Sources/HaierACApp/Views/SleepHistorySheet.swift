import SwiftUI
import HaierACCore

/// 智能睡眠温阶历史记录与温控轨迹回放弹窗 (v1.9.16)
/// 遵循 macOS Bento 设计风格，支持查看历史睡眠时长、阶段调温历程、室内温度对比及清空管理
struct SleepHistorySheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirm = false
    @State private var recordToDelete: SleepRecord? = nil
    var onSelectCurve: ((SleepCurveConfig) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            headerView

            Divider().overlay(Theme.hairlineSubtle)

            // 内容区
            if model.sleepHistory.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: Theme.spaceMD) {
                        // 数据洞察仪表盘
                        analyticsPod

                        LazyVStack(spacing: Theme.spaceMD) {
                            ForEach(model.sleepHistory) { record in
                                recordCard(record)
                            }
                        }
                    }
                    .padding(Theme.spaceLG)
                }
            }
        }
        .frame(width: 660, height: 620)
        .background(Theme.canvas)
        .alert("清空睡眠历史记录", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) { }
            Button("清空全部", role: .destructive) {
                model.clearAllSleepHistory()
            }
        } message: {
            Text("确定要清空所有智能睡眠历史记录吗？此操作无法恢复。")
        }
    }

    // MARK: - 顶栏

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))

            Text("睡眠温阶执行历史")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)

            if !model.sleepHistory.isEmpty {
                Text("\(model.sleepHistory.count) 条记录")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.surface2)
                    .clipShape(Capsule())
            }

            Spacer()

            if !model.sleepHistory.isEmpty {
                Menu {
                    Button {
                        model.exportSleepHistoryToCSVFile()
                    } label: {
                        Label("保存 CSV 文件...", systemImage: "arrow.down.doc")
                    }
                    Button {
                        model.copySleepHistoryCSVToClipboard()
                    } label: {
                        Label("复制 CSV 到剪贴板", systemImage: "doc.on.clipboard")
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text("导出 CSV")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .buttonStyle(Theme.secondaryButtonStyle())
                .help("导出睡眠调温历史为标准 CSV 表格文件或复制到剪贴板")

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Text("清空历史")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(Theme.secondaryButtonStyle())
            }

            Button("完成") {
                dismiss()
            }
            .buttonStyle(Theme.secondaryButtonStyle())
        }
        .padding(.horizontal, Theme.spaceLG)
        .padding(.vertical, Theme.spaceMD)
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.dynamic(light: 0xEEF0FF, dark: 0x16182E))
                    .frame(width: 72, height: 72)

                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
            }

            Text("暂无智能睡眠历史记录")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text("开启智能睡眠温阶后，空调将在此自动记录各阶段调温轨迹、运行时长与室内温度变化。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 记录卡片

    private func recordCard(_ record: SleepRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部信息行：曲线名、设备名、状态胶囊、删除按钮
            HStack(spacing: 8) {
                Text(record.curveName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                Text(record.deviceName)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSubtle)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.surface2)
                    .cornerRadius(Theme.radiusSM)

                Spacer()

                // 结束原因胶囊
                endReasonBadge(record.endReason)

                // 分享卡片按钮
                Button {
                    model.copySleepSummaryCardToClipboard(record: record)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 10))
                        Text("分享")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Theme.inkSubtle)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.surface2)
                    .cornerRadius(Theme.radiusSM)
                }
                .buttonStyle(.plain)
                .help("复制该次睡眠调温报告卡片到剪贴板")

                // 删除按钮
                Button {
                    model.deleteSleepRecord(id: record.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("删除此条记录")
            }

            // 时间与时长信息
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)

                    Text("\(formattedDate(record.startedAt))  \(formattedTime(record.startedAt)) ~ \(formattedTime(record.endedAt))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkMuted)
                }

                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)

                    Text("运行时长 \(record.durationText)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }

                Spacer()

                // 快捷复用按钮
                if let matchedCurve = model.allSleepCurves.first(where: { $0.name == record.curveName }) {
                    Button {
                        onSelectCurve?(matchedCurve)
                        dismiss()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text("再次使用")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                    }
                    .buttonStyle(.plain)
                }
            }

            // 温阶轨迹时间轴
            if !record.trajectory.isEmpty {
                trajectoryTimeline(record.trajectory)
            }
        }
        .padding(Theme.spaceMD)
        .background(Theme.cardBackground(Theme.surface1))
        .cornerRadius(Theme.radiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    // MARK: - 结束原因徽标

    private func endReasonBadge(_ reason: SleepEndReason) -> some View {
        let (color, bg): (Color, Color) = {
            switch reason {
            case .completed:
                return (Theme.success, Theme.success.opacity(0.12))
            case .userStopped:
                return (Theme.warning, Theme.warning.opacity(0.12))
            case .overridden:
                return (Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF), Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF).opacity(0.12))
            }
        }()

        return Text(reason.rawValue)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }

    // MARK: - 温控轨迹时间轴

    private func trajectoryTimeline(_ points: [SleepTrajectoryPoint]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("执行轨迹节点 (\(points.count))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkSubtle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(points) { pt in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(formattedTime(pt.timestamp))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.inkTertiary)

                                Spacer()

                                Text(pt.stageName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.inkSubtle)
                                    .lineLimit(1)
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                if pt.powerOn {
                                    let tempStr = String(format: "%.1f°", pt.targetTemperature).replacingOccurrences(of: ".0°", with: "°")
                                    Text(tempStr)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.ink)

                                    Text(pt.windSpeed)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.inkSubtle)
                                } else {
                                    Text("关机")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.inkSubtle)
                                }

                                Spacer()

                                if let indoor = pt.indoorTemperature {
                                    HStack(spacing: 2) {
                                        Image(systemName: "house")
                                            .font(.system(size: 9))
                                        Text(String(format: "%.1f°", indoor))
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                    }
                                    .foregroundStyle(Color.dynamic(light: 0x0071E3, dark: 0x2997FF))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.dynamic(light: 0x0071E3, dark: 0x2997FF).opacity(0.1))
                                    .cornerRadius(4)
                                }

                                if let hum = pt.indoorHumidity {
                                    HStack(spacing: 2) {
                                        Image(systemName: "humidity.fill")
                                            .font(.system(size: 9))
                                        Text(String(format: "%.0f%%", hum))
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                    }
                                    .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF).opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .padding(7)
                        .frame(width: 155)
                        .background(Theme.surface2)
                        .cornerRadius(Theme.radiusSM)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 日期格式化

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - 睡眠洞察分析卡片 (v1.9.18)

    private var analyticsPod: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("近 7 次睡眠调温洞察", systemImage: "chart.bar.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))

                Spacer()

                if let favorite = preferredCurveName {
                    Text("最常用方案：\(favorite)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSubtle)
                }
            }

            // 指标三列
            HStack(spacing: 8) {
                metricCell(
                    title: "平均睡眠时长",
                    value: String(format: "%.1f 小时", averageSleepDurationHours),
                    icon: "hourglass",
                    color: Theme.accent
                )

                metricCell(
                    title: "计划完成率",
                    value: "\(completionRate)%",
                    icon: "checkmark.circle.fill",
                    color: Theme.success
                )

                if let avgRoomTemp = averageIndoorTemperature {
                    metricCell(
                        title: "平均室内回风",
                        value: String(format: "%.1f°C", avgRoomTemp),
                        icon: "thermometer.medium",
                        color: Color.dynamic(light: 0x0071E3, dark: 0x2997FF)
                    )
                }
            }

            // 7天时长柱状图
            durationBarChart
        }
        .padding(Theme.spaceMD)
        .background(Theme.cardBackground(Theme.surface1))
        .cornerRadius(Theme.radiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private func metricCell(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkSubtle)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface2)
        .cornerRadius(Theme.radiusSM)
    }

    private var durationBarChart: some View {
        let recent = Array(model.sleepHistory.prefix(7).reversed())
        let maxDuration = max(8.0, recent.map { Double($0.durationMinutes) / 60.0 }.max() ?? 8.0)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(recent) { rec in
                    let hours = Double(rec.durationMinutes) / 60.0
                    let heightRatio = min(max(hours / maxDuration, 0.1), 1.0)

                    VStack(spacing: 4) {
                        Text(String(format: "%.1fh", hours))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.inkSubtle)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(for: rec.endReason))
                            .frame(height: max(14, 60 * CGFloat(heightRatio)))
                            .frame(maxWidth: .infinity)

                        Text(shortDate(rec.startedAt))
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
            }
            .frame(height: 90)
            .padding(.top, 4)
        }
    }

    private func barColor(for reason: SleepEndReason) -> Color {
        switch reason {
        case .completed: return Theme.success.opacity(0.85)
        case .userStopped: return Theme.warning.opacity(0.85)
        case .overridden: return Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF).opacity(0.85)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }

    // MARK: - 统计计算属性

    private var averageSleepDurationHours: Double {
        guard !model.sleepHistory.isEmpty else { return 0 }
        let total = model.sleepHistory.reduce(0) { $0 + $1.durationMinutes }
        return Double(total) / Double(model.sleepHistory.count) / 60.0
    }

    private var completionRate: Int {
        guard !model.sleepHistory.isEmpty else { return 0 }
        let completed = model.sleepHistory.filter { $0.endReason == .completed }.count
        return Int((Double(completed) / Double(model.sleepHistory.count)) * 100)
    }

    private var preferredCurveName: String? {
        let names = model.sleepHistory.map(\.curveName)
        let counts = names.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private var averageIndoorTemperature: Double? {
        var temps: [Double] = []
        for rec in model.sleepHistory {
            for pt in rec.trajectory {
                if let t = pt.indoorTemperature {
                    temps.append(t)
                }
            }
        }
        guard !temps.isEmpty else { return nil }
        return temps.reduce(0, +) / Double(temps.count)
    }
}
