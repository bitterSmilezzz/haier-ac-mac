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

    static let empty = ACWidgetSnapshot(temperature: nil, targetTemp: nil, powerOn: nil, humidity: nil, deviceName: nil, updatedAt: nil)
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
    private var tempText: String {
        guard let t = snapshot?.temperature else { return "--" }
        return String(format: "%.0f°", t)
    }

    var body: some View {
        let content = Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            default:
                smallView
            }
        }
        if #available(macOS 14.0, *) {
            content
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.06, blue: 0.08), Color(red: 0.12, green: 0.13, blue: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        } else {
            content
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.06, blue: 0.08), Color(red: 0.12, green: 0.13, blue: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
