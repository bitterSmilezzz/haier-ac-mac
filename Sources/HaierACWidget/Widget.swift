import WidgetKit
import SwiftUI

// MARK: - 快照数据（主 App 写入，Widget 读取）

/// 主 App 定期写入 AppGroup 容器的状态快照（JSON）
struct ACWidgetSnapshot: Codable {
    var temperature: Double?
    var targetTemp: Double?
    var powerOn: Bool?
    var humidity: Double?
    var deviceName: String?
    var updatedAt: Date?
    // 智能睡眠温阶状态
    var isSleepActive: Bool?
    var sleepCurveName: String?
    var sleepStageName: String?
    var sleepTargetTemp: Double?
    var sleepNextStageName: String?
    var sleepNextFireDate: Date?
    var sleepCompensationOffset: Double?
    var sleepEffectiveTemp: Double?

    static let empty = ACWidgetSnapshot(
        temperature: nil,
        targetTemp: nil,
        powerOn: nil,
        humidity: nil,
        deviceName: nil,
        updatedAt: nil,
        isSleepActive: nil,
        sleepCurveName: nil,
        sleepStageName: nil,
        sleepTargetTemp: nil,
        sleepNextStageName: nil,
        sleepNextFireDate: nil,
        sleepCompensationOffset: nil,
        sleepEffectiveTemp: nil
    )
}

/// 主 App 写入、Widget 读取的状态快照
/// ⚠️ 不用 AppGroup 容器：非沙盒主 App 访问 `~/Library/Group Containers/<group>`
/// 会永久阻塞（实测挂起）。改为 App 的 Application Support 目录共享：
/// 主 App 直接写，Widget（沙盒）通过只读临时例外 entitlement 读取同一路径。
enum ACSharedState {
    /// 与主 App HaierACApp/AppModel.swift writeWidgetSnapshot() 的写入路径保持一致
    static let fileName = "widget-state.json"

    /// 读取最新快照；失败返回 nil（Widget 显示占位）
    static func loadSnapshot() -> ACWidgetSnapshot? {
        let url = snapshotURL()
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        // 主 App 用 ISO8601DateFormatter 写 updatedAt，这里必须用同策略解析
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ACWidgetSnapshot.self, from: data)
    }

    static func snapshotURL() -> URL {
        // 沙盒小组件：home 指向容器（containerURL 不可用），
        // 用真实用户名拼 Application Support 路径，
        // 读权限由 Widget.entitlements 的 absolute-path 只读例外授予
        // （与主 App writeWidgetSnapshot() 的写入路径保持一致）。
        let user = NSUserName()
        let base = URL(fileURLWithPath: "/Users/\(user)/Library/Application Support/HaierAC", isDirectory: true)
        return base.appendingPathComponent(fileName)
    }
}

// MARK: - Timeline Entry

struct ACWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: ACWidgetSnapshot?
    /// 最近一次快照更新时刻（展示「x 分钟前」）
    var isPlaceholder: Bool = false
}

// MARK: - Timeline Provider

struct ACWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ACWidgetEntry {
        ACWidgetEntry(date: Date(), snapshot: .empty, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ACWidgetEntry) -> Void) {
        let entry = ACWidgetEntry(
            date: Date(),
            snapshot: context.isPreview ? .empty : ACSharedState.loadSnapshot(),
            isPlaceholder: context.isPreview
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ACWidgetEntry>) -> Void) {
        let snapshot = ACSharedState.loadSnapshot()
        let now = Date()
        let entry = ACWidgetEntry(date: now, snapshot: snapshot)
        // 快照每 30 分钟重读一次；主 App 状态变化时通过 WidgetCenter.reloadAllTimelines 即时刷新
        let next = now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget 视图

struct ACWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ACWidgetEntry

    private var snapshot: ACWidgetSnapshot? { entry.snapshot }
    private var isSleep: Bool { snapshot?.isSleepActive == true }
    private var tempText: String {
        guard let t = snapshot?.temperature else { return "--" }
        return String(format: "%.0f°", t)
    }

    private var backgroundGradient: LinearGradient {
        if isSleep {
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.06, blue: 0.16), Color(red: 0.12, green: 0.10, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.06, blue: 0.08), Color(red: 0.12, green: 0.13, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        let content = Group {
            switch family {
            case .systemSmall:
                if isSleep {
                    sleepSmallView
                } else {
                    smallView
                }
            case .systemMedium:
                if isSleep {
                    sleepMediumView
                } else {
                    mediumView
                }
            default:
                smallView
            }
        }
        if #available(macOS 14.0, *) {
            content
                .containerBackground(for: .widget) {
                    backgroundGradient
                }
        } else {
            content
                .padding(12)
                .background(backgroundGradient)
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "air.conditioner.horizontal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.53, green: 0.58, blue: 0.95))
                Spacer()
                if let powerOn = snapshot?.powerOn {
                    Circle()
                        .fill(powerOn ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer(minLength: 4)

            Text(tempText)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            if let target = snapshot?.targetTemp {
                Text("目标 \(String(format: "%.0f°", target))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
            } else {
                Text("室内温度")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            // 湿度（设备支持时）
            if let humidity = snapshot?.humidity {
                Text(String(format: "湿度 %.0f%%", humidity))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            if let name = snapshot?.deviceName {
                Text(name)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "haierac://main"))
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            // 左侧大温度
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "air.conditioner.horizontal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.53, green: 0.58, blue: 0.95))
                    Text(snapshot?.deviceName ?? "海尔空调")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                }
                Text(tempText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(snapshot?.powerOn == true ? "运行中" : "已关机")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(snapshot?.powerOn == true ? Color.green : Color.white.opacity(0.5))
            }

            Spacer()

            // 右侧目标温度 + 湿度
            if let target = snapshot?.targetTemp {
                VStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Text(String(format: "%.0f°", target))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("目标")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }
            // 湿度（设备有湿度传感器时显示）
            if let humidity = snapshot?.humidity {
                VStack(spacing: 4) {
                    Image(systemName: "humidity.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Text(String(format: "%.0f%%", humidity))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("湿度")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }

            // 睡眠快捷启动 Link
            Link(destination: URL(string: "haierac://sleep/start")!) {
                VStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.68, green: 0.65, blue: 1.0))
                    Text("开启")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("睡眠")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.55, green: 0.50, blue: 0.95).opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color(red: 0.55, green: 0.50, blue: 0.95).opacity(0.4), lineWidth: 1)
                        )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "haierac://main"))
    }

    // MARK: - 智能睡眠小尺寸视图

    private var sleepSmallView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.68, green: 0.65, blue: 1.0))
                Text(snapshot?.sleepCurveName ?? "智能睡眠")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.88, green: 0.86, blue: 1.0))
                    .lineLimit(1)
                Spacer()
                Circle()
                    .fill(Color(red: 0.55, green: 0.50, blue: 0.95))
                    .frame(width: 6, height: 6)
            }

            Spacer(minLength: 2)

            let targetDisplay = snapshot?.sleepEffectiveTemp ?? snapshot?.sleepTargetTemp
            if let target = targetDisplay {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    let tempStr = String(format: "%.1f°", target).replacingOccurrences(of: ".0°", with: "°")
                    Text(tempStr)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    if let offset = snapshot?.sleepCompensationOffset, offset != 0.0 {
                        let sign = offset > 0 ? "+" : ""
                        Text("✨\(sign)\(String(format: "%.1f", offset))°")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(red: 0.75, green: 0.72, blue: 1.0))
                    }
                }
            } else {
                Text(tempText)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            Text(snapshot?.sleepStageName ?? "睡眠呵护中")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)

            // 下一阶段预告
            if let nextName = snapshot?.sleepNextStageName, let fireDate = snapshot?.sleepNextFireDate {
                let formatter = DateFormatter()
                let _ = formatter.dateFormat = "HH:mm"
                let timeStr = formatter.string(from: fireDate)
                HStack(spacing: 3) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 9))
                    Text("\(timeStr) 进入「\(nextName)」")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
            } else {
                Text("室内 \(tempText)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "haierac://sleep/toggle"))
    }

    // MARK: - 智能睡眠中尺寸视图

    private var sleepMediumView: some View {
        HStack(spacing: 14) {
            // 左侧：睡眠方案与当前温阶
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.68, green: 0.65, blue: 1.0))
                    Text("智能睡眠 · \(snapshot?.sleepCurveName ?? "")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.88, green: 0.86, blue: 1.0))
                        .lineLimit(1)
                }

                let targetDisplay = snapshot?.sleepEffectiveTemp ?? snapshot?.sleepTargetTemp
                if let target = targetDisplay {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        let tempStr = String(format: "%.1f°", target).replacingOccurrences(of: ".0°", with: "°")
                        Text(tempStr)
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        if let offset = snapshot?.sleepCompensationOffset, offset != 0.0 {
                            let sign = offset > 0 ? "+" : ""
                            Text("✨ 自适应 \(sign)\(String(format: "%.1f", offset))°")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(red: 0.75, green: 0.72, blue: 1.0))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                } else {
                    Text(tempText)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                HStack(spacing: 4) {
                    Text("当前阶段：\(snapshot?.sleepStageName ?? "运行中")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Text("· 室内 \(tempText)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            Spacer()

            // 右侧 Bento 卡片：下一阶段时间预告与一键停止按钮
            VStack(alignment: .trailing, spacing: 6) {
                if let nextName = snapshot?.sleepNextStageName, let fireDate = snapshot?.sleepNextFireDate {
                    let formatter = DateFormatter()
                    let _ = formatter.dateFormat = "HH:mm"
                    let timeStr = formatter.string(from: fireDate)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(red: 0.68, green: 0.65, blue: 1.0))
                            Text("下一阶段")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }

                        Text(timeStr)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        Text(nextName)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }

                // 一键停止睡眠模式 Link
                Link(destination: URL(string: "haierac://sleep/stop")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 8))
                        Text("停止睡眠")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.red.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "haierac://main"))
    }
}

// MARK: - Widget 声明

struct ACWidget: Widget {
    let kind = "HaierACWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ACWidgetProvider()) { entry in
            ACWidgetView(entry: entry)
        }
        .configurationDisplayName("海尔空调")
        .description("实时查看室内温度与运行状态")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ACWidgetBundle: WidgetBundle {
    var body: some Widget {
        ACWidget()
    }
}
