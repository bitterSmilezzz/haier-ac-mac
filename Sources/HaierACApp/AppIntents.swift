import AppIntents
import SwiftUI
import HaierACCore

/// 快捷指令集成（Shortcuts / Siri，v1.6）
///
/// 通过 AppIntents 框架把空调控制暴露给系统「快捷指令」App：
/// - 开关空调电源
/// - 设置目标温度
/// - 设置运行模式（制冷/制热/送风…，值随设备数字模型）
/// - 应用自定义情景
///
/// 注册方式：本 SDK 的 AppIntents 接口不暴露 Scene.appIntents 修饰符
/// （CLT SDK 限制），故依赖 AppShortcutsProvider 的系统自动发现机制：
/// App 中声明符合 AppShortcutsProvider 的类型后，快捷指令 App 会自动
/// 索引其中的 AppShortcut，无需手动调用场景修饰符。
///
/// 注意：intent 在独立进程执行，通过 AppModel.shared 单例访问状态；
/// 所有 AppModel 方法均为 @MainActor，perform 同样标注 @MainActor。

// MARK: - 通用工具

/// Intent 失败错误：perform 抛出后，Siri/快捷指令显示 localizedDescription
private enum ACIntentError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

/// 解析目标设备：优先按名称精确匹配，否则回退第一台设备
@MainActor
private func resolveDeviceId(named name: String?) -> String? {
    let model = AppModel.shared
    if let name, !name.isEmpty,
       let device = model.devices.first(where: { $0.deviceName.contains(name) }) {
        return device.id
    }
    if let name, !name.isEmpty,
       let manual = model.manualDevices.first(where: { $0.name.contains(name) }) {
        return manual.deviceId
    }
    return model.devices.first?.id ?? model.manualDevices.first?.deviceId
}

/// 网关未连接/无设备时抛错，让 Siri/快捷指令给出明确失败信息
@MainActor
private func requireGatewayAndDevice(_ name: String?) throws -> String {
    guard AppModel.shared.gatewayConnected else {
        throw ACIntentError.message("空调连接中断，请稍后重试")
    }
    guard let deviceId = resolveDeviceId(named: name) else {
        throw ACIntentError.message("没有可控制的空调设备")
    }
    return deviceId
}

// MARK: - 电源开关

struct SetACPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "开关空调电源"
    static var description = IntentDescription("打开或关闭海尔空调的电源", categoryName: "空调控制")

    @Parameter(title: "打开")
    var powerOn: Bool

    @Parameter(title: "设备名称", description: "可选；留空使用第一台设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let deviceId = try requireGatewayAndDevice(deviceName)
        AppModel.shared.sendAttribute("onOffStatus", value: .bool(powerOn), deviceId: deviceId)
        return .result(dialog: "已\(powerOn ? "打开" : "关闭")空调电源")
    }
}

// MARK: - 目标温度

struct SetACTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "设置空调温度"
    static var description = IntentDescription("设置海尔空调的目标温度", categoryName: "空调控制")

    @Parameter(title: "温度（°C）", default: 26.0)
    var temperature: Double

    @Parameter(title: "设备名称", description: "可选；留空使用第一台设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let deviceId = try requireGatewayAndDevice(deviceName)
        AppModel.shared.sendAttribute("targetTemperature", value: .double(temperature), deviceId: deviceId)
        return .result(dialog: "已将温度设置为 \(Int(temperature)) 度")
    }
}

// MARK: - 运行模式

struct SetACModeIntent: AppIntent {
    static var title: LocalizedStringResource = "设置空调模式"
    static var description = IntentDescription("设置海尔空调的运行模式（制冷/制热/送风等）", categoryName: "空调控制")

    @Parameter(title: "模式", description: "如：制冷、制热、自动、送风")
    var mode: String

    @Parameter(title: "设备名称", description: "可选；留空使用第一台设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let deviceId = try requireGatewayAndDevice(deviceName)
        // 在数字模型中查找与用户输入匹配的模式选项
        let attrs = AppModel.shared.attributes[deviceId] ?? [:]
        guard let modeAttr = attrs["operationMode"],
              case .list(let options) = modeAttr.valueRange,
              let match = options.first(where: { $0.desc.contains(mode) || mode.contains($0.desc) }) else {
            throw ACIntentError.message("该设备不支持模式「\(mode)」")
        }
        AppModel.shared.sendAttribute("operationMode", value: match.data, deviceId: deviceId)
        return .result(dialog: "已切换到\(match.desc)模式")
    }
}

// MARK: - 应用情景

struct ApplyACSceneIntent: AppIntent {
    static var title: LocalizedStringResource = "应用空调情景"
    static var description = IntentDescription("一键应用已保存的情景模式（睡眠/离家/自定义）", categoryName: "空调控制")

    @Parameter(title: "情景名称", description: "如：睡眠、离家")
    var sceneName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard AppModel.shared.gatewayConnected else {
            throw ACIntentError.message("空调连接中断，请稍后重试")
        }
        guard let scene = AppModel.shared.scenes.first(where: { $0.name.contains(sceneName) }) else {
            throw ACIntentError.message("未找到情景「\(sceneName)」，请先在应用内创建")
        }
        AppModel.shared.applyScene(scene)
        return .result(dialog: "已应用情景「\(scene.name)」")
    }
}

// MARK: - 查询温度

struct GetACTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "查询空调温度"
    static var description = IntentDescription("查询空调当前室内温度", categoryName: "空调控制")

    @Parameter(title: "设备名称", description: "可选；留空使用第一台设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard let deviceId = resolveDeviceId(named: deviceName) else {
            throw ACIntentError.message("没有可控制的空调设备")
        }
        guard let attr = AppModel.indoorTemperatureAttribute(in: model.attributes[deviceId] ?? [:]),
              let temp = attr.doubleValue else {
            throw ACIntentError.message("暂未获取到室内温度")
        }
        let name = model.devices.first(where: { $0.id == deviceId })?.deviceName
            ?? model.manualDevices.first(where: { $0.deviceId == deviceId })?.name
            ?? "空调"
        let text = String(format: "%.0f°", temp)
        return .result(value: text, dialog: "\(name)当前室内温度 \(text)")
    }
}

// MARK: - 快捷指令库入口

struct ACAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        if #available(macOS 14.0, *) {
            return [
                AppShortcut(
                    intent: SetACPowerIntent(),
                    phrases: [
                        "用 \(.applicationName) 打开空调",
                        "用 \(.applicationName) 关闭空调",
                        "\(.applicationName) 开关空调",
                    ],
                    shortTitle: "开关空调",
                    systemImageName: "power"
                ),
                AppShortcut(
                    intent: SetACTemperatureIntent(),
                    phrases: [
                        "用 \(.applicationName) 设置温度",
                        "把空调调到 \(.applicationName)",
                    ],
                    shortTitle: "设置温度",
                    systemImageName: "thermometer.medium"
                ),
                AppShortcut(
                    intent: SetACModeIntent(),
                    phrases: [
                        "用 \(.applicationName) 切换模式",
                    ],
                    shortTitle: "切换模式",
                    systemImageName: "slider.horizontal.3"
                ),
                AppShortcut(
                    intent: ApplyACSceneIntent(),
                    phrases: [
                        "用 \(.applicationName) 应用情景",
                    ],
                    shortTitle: "应用情景",
                    systemImageName: "sparkles"
                ),
                AppShortcut(
                    intent: GetACTemperatureIntent(),
                    phrases: [
                        "用 \(.applicationName) 查询温度",
                        "\(.applicationName) 现在多少度",
                    ],
                    shortTitle: "查询温度",
                    systemImageName: "thermometer.sun.fill"
                ),
            ]
        } else {
            return [
                AppShortcut(
                    intent: SetACPowerIntent(),
                    phrases: [
                        "用 \(.applicationName) 打开空调",
                        "用 \(.applicationName) 关闭空调",
                        "\(.applicationName) 开关空调",
                    ]
                ),
                AppShortcut(
                    intent: SetACTemperatureIntent(),
                    phrases: [
                        "用 \(.applicationName) 设置温度",
                    ]
                ),
                AppShortcut(
                    intent: SetACModeIntent(),
                    phrases: [
                        "用 \(.applicationName) 切换模式",
                    ]
                ),
                AppShortcut(
                    intent: ApplyACSceneIntent(),
                    phrases: [
                        "用 \(.applicationName) 应用情景",
                    ]
                ),
                AppShortcut(
                    intent: GetACTemperatureIntent(),
                    phrases: [
                        "用 \(.applicationName) 查询温度",
                    ]
                ),
            ]
        }
    }
}
