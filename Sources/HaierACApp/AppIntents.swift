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

/// 解析目标设备：优先按名称精确匹配，否则回退菜单栏选中或第一台设备 (v1.9.29)
@MainActor
private func resolveDeviceId(named name: String?) -> String? {
    let model = AppModel.shared
    if let name, !name.isEmpty,
       let device = model.allUnifiedDevices.first(where: { $0.name.contains(name) }) {
        return device.id
    }
    return model.primaryDeviceId
}

/// 网关未连接/无设备或设备离线时抛错，让 Siri/快捷指令给出明确失败信息 (v1.9.29, v1.9.92)
@MainActor
private func requireGatewayAndDevice(_ name: String?) throws -> String {
    guard AppModel.shared.gatewayConnected else {
        throw ACIntentError.message("空调连接中断，请稍后重试")
    }
    guard let deviceId = resolveDeviceId(named: name) else {
        throw ACIntentError.message("没有可控制的空调设备")
    }
    let reach = AppModel.shared.reachability(for: deviceId)
    guard reach.isControllable else {
        let devName = AppModel.shared.deviceName(for: deviceId)
        if reach == .gatewayReconnecting {
            throw ACIntentError.message("\(devName)网关重连中，请稍后重试")
        } else {
            throw ACIntentError.message("\(devName)当前离线，无法执行控制")
        }
    }
    return deviceId
}

// MARK: - 电源开关

struct SetACPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "开关空调电源"
    static var description = IntentDescription("打开或关闭海尔空调的电源", categoryName: "空调控制")

    @Parameter(title: "打开")
    var powerOn: Bool

    @Parameter(title: "设备名称", description: "可选；留空使用主设备，填“全屋”或“全部”统一开关所有设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard model.gatewayConnected else {
            throw ACIntentError.message("空调连接中断，请稍后重试")
        }

        let isAll = (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
        if isAll {
            if powerOn {
                let openedCount = model.turnOnAllDevices()
                if openedCount > 0 {
                    return .result(dialog: "已开启全屋 \(openedCount) 台空调")
                } else {
                    let controllable = model.allUnifiedDevices.filter { model.reachability(for: $0.id).isControllable }
                    if !controllable.isEmpty {
                        return .result(dialog: "全屋空调当前均已处于开机运行状态")
                    } else {
                        return .result(dialog: "未发现可控制的就绪空调设备")
                    }
                }
            } else {
                let closedCount = model.turnOffAllDevices()
                if closedCount > 0 {
                    return .result(dialog: "已关闭全屋 \(closedCount) 台运行中的空调")
                } else {
                    return .result(dialog: "全屋空调当前均已处于关机或待机状态")
                }
            }
        }

        let deviceId = try requireGatewayAndDevice(deviceName)
        model.sendAttribute("onOffStatus", value: .bool(powerOn), deviceId: deviceId)
        let devName = model.deviceName(for: deviceId)
        return .result(dialog: "已\(powerOn ? "打开" : "关闭")「\(devName)」空调电源")
    }
}

// MARK: - 目标温度

struct SetACTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "设置空调温度"
    static var description = IntentDescription("设置海尔空调的目标温度", categoryName: "空调控制")

    @Parameter(title: "温度（°C）", default: 26.0)
    var temperature: Double

    @Parameter(title: "设备名称", description: "可选；留空使用主设备，填“全屋”或“全部”统一设置所有设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard model.gatewayConnected else {
            throw ACIntentError.message("空调连接中断，请稍后重试")
        }
        let isAll = (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
        let tempStr = temperature.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(temperature))" : String(format: "%.1f", temperature)
        if isAll {
            let count = model.setTemperatureAll(temperature: temperature)
            guard count > 0 else {
                throw ACIntentError.message("未能完成全屋调温，当前无可用在线空调")
            }
            return .result(dialog: "已将全屋 \(count) 台空调温度统一设为 \(tempStr) 度")
        }
        let deviceId = try requireGatewayAndDevice(deviceName)
        _ = model.setTemperature(deviceIds: [deviceId], temperature: temperature)
        let devName = model.deviceName(for: deviceId)
        return .result(dialog: "已将「\(devName)」温度设置为 \(tempStr) 度")
    }
}

// MARK: - 相对微调温度 (v1.9.53)

struct AdjustACTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "微调空调温度"
    static var description = IntentDescription("相对微调海尔空调的目标温度（如升温 1°C、降温 0.5°C）", categoryName: "空调控制")

    @Parameter(title: "调节幅度（°C，正数为升温，负数为降温）", default: 1.0)
    var delta: Double

    @Parameter(title: "全屋应用", default: false)
    var allDevices: Bool

    @Parameter(title: "设备名称", description: "可选；留空使用主设备，填“全屋”或“全部”统一调节所有设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard model.gatewayConnected else {
            throw ACIntentError.message("空调连接中断，请稍后重试")
        }

        let isAll = allDevices || (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
        let dir = delta > 0 ? "升温" : "降温"
        let deltaAbs = abs(delta)
        let deltaStr = deltaAbs.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(deltaAbs))" : String(format: "%.1f", deltaAbs)

        if isAll {
            let count = model.adjustTemperatureAll(delta: delta)
            if count > 0 {
                return .result(dialog: "已将全屋 \(count) 台运行中的空调统一\(dir) \(deltaStr) 度")
            } else {
                let limitDesc = delta > 0 ? "已达到最高温度 30°C 上限" : "已达到最低温度 16°C 下限"
                return .result(dialog: "全屋运行中的空调均\(limitDesc)")
            }
        }

        guard let deviceId = resolveDeviceId(named: deviceName) else {
            throw ACIntentError.message("没有可控制的空调设备")
        }
        let reach = model.reachability(for: deviceId)
        guard reach.isControllable else {
            let devName = model.deviceName(for: deviceId)
            throw ACIntentError.message("\(devName)当前离线或不可控")
        }

        let count = model.adjustTemperature(deviceIds: [deviceId], delta: delta)
        let devName = model.deviceName(for: deviceId)
        if count > 0 {
            let cur = model.attribute("targetTemperature", deviceId: deviceId)?.doubleValue ?? 26.0
            let curStr = cur.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(cur))" : String(format: "%.1f", cur)
            return .result(dialog: "已将「\(devName)」\(dir) \(deltaStr) 度，当前为 \(curStr) 度")
        } else {
            let limitDesc = delta > 0 ? "已达到最高温度 30°C 上限" : "已达到最低温度 16°C 下限"
            return .result(dialog: "「\(devName)」\(limitDesc)")
        }
    }
}

// MARK: - 运行模式

struct SetACModeIntent: AppIntent {
    static var title: LocalizedStringResource = "设置空调模式"
    static var description = IntentDescription("设置海尔空调的运行模式（制冷/制热/送风等）", categoryName: "空调控制")

    @Parameter(title: "模式", description: "如：制冷、制热、自动、送风、除湿")
    var mode: String

    @Parameter(title: "设备名称", description: "可选；留空使用主设备，填“全屋”或“全部”统一设置所有设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard model.gatewayConnected else {
            throw ACIntentError.message("空调连接中断，请稍后重试")
        }
        guard let matched = ACModeCode.match(from: mode) else {
            throw ACIntentError.message("未能识别模式「\(mode)」")
        }
        let isAll = (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
        if isAll {
            let count = model.setModeAll(mode: matched)
            guard count > 0 else {
                throw ACIntentError.message("未能完成全屋模式切换，当前无可用在线空调")
            }
            return .result(dialog: "已将全屋 \(count) 台空调统一切换为「\(matched.desc)」模式")
        }
        let deviceId = try requireGatewayAndDevice(deviceName)
        _ = model.setMode(deviceIds: [deviceId], mode: matched)
        let devName = model.deviceName(for: deviceId)
        return .result(dialog: "已将「\(devName)」切换为「\(matched.desc)」模式")
    }
}

// MARK: - 调节风速 (v1.9.46)

struct SetACWindSpeedIntent: AppIntent {
    static var title: LocalizedStringResource = "设置空调风速"
    static var description = IntentDescription("设置海尔空调的风速（微风/中风/强劲/自动）", categoryName: "空调控制")

    @Parameter(title: "风速", description: "如：微风、中风、强劲、自动")
    var windSpeed: String

    @Parameter(title: "设备名称", description: "可选；留空使用主设备，填“全屋”或“全部”统一调节所有设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard model.gatewayConnected else {
            throw ACIntentError.message("空调连接中断，请稍后重试")
        }

        if let name = deviceName, (name.contains("全") || name.contains("所有")) {
            let count = model.setWindSpeedAll(speedName: windSpeed, autoPowerOn: false)
            guard count > 0 else {
                throw ACIntentError.message("未能完成全屋风速调节，当前无可用在线空调")
            }
            return .result(dialog: "已将全屋 \(count) 台空调风速统一设为「\(windSpeed)」")
        }

        guard let deviceId = resolveDeviceId(named: deviceName) else {
            throw ACIntentError.message("没有可控制的空调设备")
        }
        let reach = model.reachability(for: deviceId)
        guard reach.isControllable else {
            let devName = model.deviceName(for: deviceId)
            throw ACIntentError.message("\(devName)当前离线或不可控")
        }
        let count = model.setWindSpeed(deviceIds: [deviceId], speedName: windSpeed, autoPowerOn: false)
        guard count > 0 else {
            throw ACIntentError.message("风速「\(windSpeed)」设置失败")
        }
        let devName = model.deviceName(for: deviceId)
        return .result(dialog: "已将「\(devName)」风速设为「\(windSpeed)」")
    }
}

// MARK: - 应用情景

struct ApplyACSceneIntent: AppIntent {
    static var title: LocalizedStringResource = "应用空调情景"
    static var description = IntentDescription("一键应用已保存的情景模式（睡眠/离家/自定义）", categoryName: "空调控制")

    @Parameter(title: "情景名称", description: "如：睡眠、离家")
    var sceneName: String

    @Parameter(title: "设备名称", description: "可选；留空使用默认设备，填“全屋”或“全部”应用至所有设备")
    var deviceName: String?

    @Parameter(title: "全屋应用", default: false)
    var allDevices: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard model.gatewayConnected else {
            throw ACIntentError.message("空调连接中断，请稍后重试")
        }
        guard let scene = model.scenes.first(where: { $0.name.contains(sceneName) }) else {
            throw ACIntentError.message("未找到情景「\(sceneName)」，请先在应用内创建")
        }
        let isAll = allDevices || (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
        let targetId = resolveDeviceId(named: deviceName)
        model.applyScene(scene, targetDeviceId: targetId, allDevices: isAll)
        if isAll {
            return .result(dialog: "已为全屋空调应用情景「\(scene.name)」")
        } else if let targetId {
            let name = model.deviceName(for: targetId)
            return .result(dialog: "已为「\(name)」应用情景「\(scene.name)」")
        } else {
            return .result(dialog: "已应用情景「\(scene.name)」")
        }
    }
}

// MARK: - 查询温度

struct GetACTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "查询空调温度"
    static var description = IntentDescription("查询空调当前室内温度", categoryName: "空调控制")

    @Parameter(title: "设备名称", description: "可选；留空使用主设备，填“全屋”或“全部”查询全屋室温")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        let isAll = (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
        if isAll {
            let all = model.allUnifiedDevices
            var temps: [Double] = []
            var summaries: [String] = []
            for dev in all {
                if let attr = AppModel.indoorTemperatureAttribute(in: model.attributes[dev.id] ?? [:]),
                   let temp = attr.doubleValue {
                    temps.append(temp)
                    let tempStr = temp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(temp))°C" : String(format: "%.1f°C", temp)
                    summaries.append("「\(dev.name)」\(tempStr)")
                }
            }
            guard !temps.isEmpty else {
                throw ACIntentError.message("暂未获取到全屋空调室内温度数据")
            }
            let avg = temps.reduce(0.0, +) / Double(temps.count)
            let avgStr = String(format: "%.1f°C", avg)
            let dialog = "全屋平均室温 \(avgStr)（" + summaries.joined(separator: "、") + "）"
            return .result(value: avgStr, dialog: IntentDialog(stringLiteral: dialog))
        }

        guard let deviceId = resolveDeviceId(named: deviceName) else {
            throw ACIntentError.message("没有可控制的空调设备")
        }
        guard let attr = AppModel.indoorTemperatureAttribute(in: model.attributes[deviceId] ?? [:]),
              let temp = attr.doubleValue else {
            throw ACIntentError.message("暂未获取到室内温度")
        }
        let name = model.deviceName(for: deviceId)
        let text = temp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(temp))°C" : String(format: "%.1f°C", temp)
        return .result(value: text, dialog: "\(name)当前室内温度 \(text)")
    }
}

// MARK: - 查询湿度 (v1.9.95)

struct GetACHumidityIntent: AppIntent {
    static var title: LocalizedStringResource = "查询空调湿度"
    static var description = IntentDescription("查询空调当前室内相对湿度", categoryName: "空调控制")

    @Parameter(title: "设备名称", description: "可选；留空使用主设备，填“全屋”或“全部”查询全屋平均湿度")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        let isAll = (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
        if isAll {
            let all = model.allUnifiedDevices
            var hums: [Double] = []
            var summaries: [String] = []
            for dev in all {
                if let attr = AppModel.indoorHumidityAttribute(in: model.attributes[dev.id] ?? [:]),
                   let hum = attr.doubleValue {
                    hums.append(hum)
                    let humStr = "\(Int(round(hum)))%"
                    summaries.append("「\(dev.name)」\(humStr)")
                }
            }
            guard !hums.isEmpty else {
                throw ACIntentError.message("暂未获取到全屋空调室内湿度数据（可能设备未配备湿度传感器）")
            }
            let avg = hums.reduce(0.0, +) / Double(hums.count)
            let avgStr = "\(Int(round(avg)))%"
            let dialog = "全屋平均相对湿度 \(avgStr)（" + summaries.joined(separator: "、") + "）"
            return .result(value: avgStr, dialog: IntentDialog(stringLiteral: dialog))
        }

        guard let deviceId = resolveDeviceId(named: deviceName) else {
            throw ACIntentError.message("没有可控制的空调设备")
        }
        guard let attr = AppModel.indoorHumidityAttribute(in: model.attributes[deviceId] ?? [:]),
              let hum = attr.doubleValue else {
            let name = model.deviceName(for: deviceId)
            throw ACIntentError.message("「\(name)」暂未获取到室内湿度（可能未配备湿度传感器）")
        }
        let name = model.deviceName(for: deviceId)
        let text = "\(Int(round(hum)))%"
        return .result(value: text, dialog: "\(name)当前室内相对湿度 \(text)")
    }
}

// MARK: - 查询综合状态看板 (v1.9.96)

struct GetACStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "查询空调综合状态"
    static var description = IntentDescription("查询空调当前运行状态、模式、温度与湿度", categoryName: "空调控制")

    @Parameter(title: "设备名称", description: "可选；留空使用主设备，填“全屋”或“全部”查询全屋设备状态")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        let isAll = (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
        if isAll {
            let all = model.allUnifiedDevices
            guard !all.isEmpty else {
                throw ACIntentError.message("未检测到已绑定的空调设备")
            }
            let active = all.filter { dev in
                model.reachability(for: dev.id).isControllable &&
                (model.attributes[dev.id]?["onOffStatus"]?.boolValue == true)
            }
            var summaries: [String] = []
            var temps: [Double] = []
            var hums: [Double] = []
            for dev in all {
                let devId = dev.id
                let reach = model.reachability(for: devId)
                if !reach.isControllable {
                    summaries.append("「\(dev.name)」离线")
                    continue
                }
                let isPower = model.attributes[devId]?["onOffStatus"]?.boolValue ?? false
                let indoorT = model.currentIndoorTemperature(for: devId)
                let indoorH = model.currentIndoorHumidity(for: devId)
                if let t = indoorT { temps.append(t) }
                if let h = indoorH { hums.append(h) }

                if isPower {
                    let modeDesc = ACModeCode.match(from: model.attributes[devId]?["operationMode"]?.stringValue)?.desc ?? "制冷"
                    let targetT = model.attributes[devId]?["targetTemperature"]?.doubleValue ?? 26.0
                    let targetStr = targetT.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(targetT))°C" : String(format: "%.1f°C", targetT)
                    let wind = AppModel.normalizeWindSpeed(model.attributes[devId]?["windSpeed"]?.stringValue ?? "微风")
                    summaries.append("「\(dev.name)」\(modeDesc) \(targetStr) [\(wind)]")
                } else {
                    summaries.append("「\(dev.name)」待机")
                }
            }
            let runningDesc = active.isEmpty ? "全屋空调当前均处于待机状态" : "全屋 \(all.count) 台空调中 \(active.count) 台正在运行"
            var envDesc = ""
            if !temps.isEmpty {
                let avgT = temps.reduce(0.0, +) / Double(temps.count)
                let avgTStr = String(format: "%.1f°C", avgT)
                envDesc += "，平均室温 \(avgTStr)"
            }
            if !hums.isEmpty {
                let avgH = hums.reduce(0.0, +) / Double(hums.count)
                envDesc += "，平均湿度 \(Int(round(avgH)))%"
            }
            let dialog = "\(runningDesc)\(envDesc)（" + summaries.joined(separator: "；") + "）"
            return .result(value: runningDesc, dialog: IntentDialog(stringLiteral: dialog))
        }

        guard let deviceId = resolveDeviceId(named: deviceName) else {
            throw ACIntentError.message("没有可控制的空调设备")
        }
        let reach = model.reachability(for: deviceId)
        let name = model.deviceName(for: deviceId)
        guard reach.isControllable else {
            throw ACIntentError.message("「\(name)」当前离线，无法获取状态")
        }
        let isPower = model.attributes[deviceId]?["onOffStatus"]?.boolValue ?? false
        let indoorT = model.currentIndoorTemperature(for: deviceId)
        let indoorH = model.currentIndoorHumidity(for: deviceId)
        var envParts: [String] = []
        if let t = indoorT {
            let tStr = t.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(t))°C" : String(format: "%.1f°C", t)
            envParts.append("室内温度 \(tStr)")
        }
        if let h = indoorH {
            envParts.append("相对湿度 \(Int(round(h)))%")
        }
        let envStr = envParts.isEmpty ? "" : "，" + envParts.joined(separator: "，")

        if isPower {
            let modeDesc = ACModeCode.match(from: model.attributes[deviceId]?["operationMode"]?.stringValue)?.desc ?? "制冷"
            let targetT = model.attributes[deviceId]?["targetTemperature"]?.doubleValue ?? 26.0
            let targetStr = targetT.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(targetT))°C" : String(format: "%.1f°C", targetT)
            let rawWind = model.attributes[deviceId]?["windSpeed"]?.stringValue ?? "微风"
            let wind = AppModel.normalizeWindSpeed(rawWind)
            let dialog = "「\(name)」正在运行，当前为\(modeDesc)模式，设定温度 \(targetStr)，风速\(wind)\(envStr)"
            return .result(value: "\(modeDesc) \(targetStr)", dialog: IntentDialog(stringLiteral: dialog))
        } else {
            let dialog = "「\(name)」当前处于关机待机状态\(envStr)"
            return .result(value: "待机", dialog: IntentDialog(stringLiteral: dialog))
        }
    }
}

// MARK: - 开启智能睡眠曲线

struct StartSleepCurveIntent: AppIntent {
    static var title: LocalizedStringResource = "开启睡眠模式"
    static var description = IntentDescription("启动智能睡眠温阶曲线", categoryName: "空调控制")

    @Parameter(title: "曲线名称", description: "内置或自定义曲线名称（如标准、轻柔、省电等），留空默认使用第一套曲线")
    var curveName: String?

    @Parameter(title: "设备名称", description: "可选；留空使用第一台设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let deviceId = try requireGatewayAndDevice(deviceName)
        let model = AppModel.shared

        let targetCurve: SleepCurveConfig
        if let query = curveName?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            if let matched = model.allSleepCurves.first(where: { $0.name.localizedCaseInsensitiveContains(query) }) {
                targetCurve = matched
            } else {
                throw ACIntentError.message("未找到名为「\(query)」的睡眠曲线")
            }
        } else {
            guard let firstCurve = model.allSleepCurves.first else {
                throw ACIntentError.message("暂无可用睡眠曲线")
            }
            targetCurve = firstCurve
        }

        model.startSleepCurve(curve: targetCurve, deviceId: deviceId)
        let name = model.deviceName(for: deviceId)
        return .result(dialog: "已为\(name)启动「\(targetCurve.name)」智能睡眠温阶")
    }
}

// MARK: - 停止智能睡眠曲线

struct StopSleepCurveIntent: AppIntent {
    static var title: LocalizedStringResource = "停止睡眠模式"
    static var description = IntentDescription("停止正在运行的智能睡眠温阶曲线", categoryName: "空调控制")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard let session = model.activeSleepSession else {
            return .result(dialog: "当前未运行智能睡眠温阶")
        }
        let curveName = session.curveConfig.name
        model.stopSleepCurve()
        return .result(dialog: "已停止「\(curveName)」智能睡眠温阶")
    }
}

// MARK: - 关闭全屋空调 (v1.9.30)

struct TurnOffAllACIntent: AppIntent {
    static var title: LocalizedStringResource = "关闭全屋空调"
    static var description = IntentDescription("一键关闭全屋所有正在运行的海尔空调", categoryName: "空调控制")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard AppModel.shared.gatewayConnected else {
            throw ACIntentError.message("空调连接中断，请稍后重试")
        }
        let closedCount = AppModel.shared.turnOffAllDevices()
        if closedCount > 0 {
            return .result(dialog: "已关闭全屋 \(closedCount) 台运行中的空调")
        } else {
            return .result(dialog: "全屋空调当前均已处于关机或待机状态")
        }
    }
}

// MARK: - 开启全屋空调 (v1.9.34 消除冷暖倒置，保持已有预设)

struct TurnOnAllACIntent: AppIntent {
    static var title: LocalizedStringResource = "开启全屋空调"
    static var description = IntentDescription("一键开启全屋所有海尔空调设备，保持当前预设模式与温度", categoryName: "空调控制")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard AppModel.shared.gatewayConnected else {
            throw ACIntentError.message("空调连接中断，请稍后重试")
        }
        let openedCount = AppModel.shared.turnOnAllDevices()
        if openedCount > 0 {
            return .result(dialog: "已开启全屋 \(openedCount) 台空调")
        } else {
            let controllable = AppModel.shared.allUnifiedDevices.filter { AppModel.shared.reachability(for: $0.id).isControllable }
            if !controllable.isEmpty {
                return .result(dialog: "全屋空调当前均已处于开机运行状态")
            } else {
                return .result(dialog: "未发现可控制的就绪空调设备")
            }
        }
    }
}

// MARK: - 启动蒸发器自清洁 (v1.9.30)

struct StartSelfCleaningIntent: AppIntent {
    static var title: LocalizedStringResource = "启动自清洁"
    static var description = IntentDescription("启动 56°C 蒸发器高温除菌自清洁程序", categoryName: "空调控制")

    @Parameter(title: "设备名称", description: "可选；留空使用第一台设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let deviceId = try requireGatewayAndDevice(deviceName)
        let model = AppModel.shared
        if model.isSelfCleaningActive {
            return .result(dialog: "56°C 蒸发器自清洁已在运行中")
        }
        model.startSelfCleaning(deviceId: deviceId)
        let name = model.deviceName(for: deviceId)
        return .result(dialog: "已为\(name)启动 56°C 蒸发器高温自清洁")
    }
}

// MARK: - 停止自清洁 (v1.9.44 对称补全)

struct StopSelfCleaningIntent: AppIntent {
    static var title: LocalizedStringResource = "停止自清洁"
    static var description = IntentDescription("停止 56°C 蒸发器高温除菌自清洁程序", categoryName: "空调控制")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard model.isSelfCleaningActive else {
            return .result(dialog: "当前没有正在运行的蒸发器自清洁程序")
        }
        model.stopSelfCleaning()
        return .result(dialog: "已停止 56°C 蒸发器自清洁")
    }
}

// MARK: - 查询滤网健康度 (v1.9.44, v1.9.93 全屋看板支持)

struct GetFilterHealthIntent: AppIntent {
    static var title: LocalizedStringResource = "查询滤网健康度"
    static var description = IntentDescription("查询空调滤网洁净度与保养健康状态", categoryName: "空调控制")

    @Parameter(title: "设备名称", description: "可选；留空使用当前主设备或第一台设备，填“全屋”或“所有”查询所有设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        let isAll = (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
        if isAll {
            let devices = model.allUnifiedDevices
            guard !devices.isEmpty else {
                throw ACIntentError.message("没有可控制的空调设备")
            }
            var needService: [String] = []
            var summaries: [String] = []
            var totalPct = 0
            for dev in devices {
                let pct = model.filterCleanlinessPercentage(for: dev.id)
                totalPct += pct
                let hours = Double(model.filterAccumulatedMinutes(for: dev.id)) / 60.0
                let hoursStr = String(format: "%.1f", hours)
                summaries.append("「\(dev.name)」\(pct)%(\(hoursStr)h)")
                if pct <= 20 {
                    needService.append(dev.name)
                }
            }
            let avgPct = totalPct / devices.count
            let advice = needService.isEmpty
                ? "全屋滤网状态均良好"
                : "注意：\(needService.joined(separator: "、"))建议及时清洗"
            let dialog = "全屋 \(devices.count) 台空调平均滤网洁净度 \(avgPct)%（\(summaries.joined(separator: "、"))），\(advice)"
            return .result(dialog: IntentDialog(stringLiteral: dialog))
        }

        guard let deviceId = resolveDeviceId(named: deviceName) else {
            throw ACIntentError.message("没有可控制的空调设备")
        }
        let devName = model.deviceName(for: deviceId)
        let pct = model.filterCleanlinessPercentage(for: deviceId)
        let hours = Double(model.filterAccumulatedMinutes(for: deviceId)) / 60.0
        let hoursStr = String(format: "%.1f", hours)
        let dialog = pct <= 20
            ? "「\(devName)」滤网洁净度仅剩 \(pct)%，已等效运行 \(hoursStr) 小时，建议及时拆洗保养"
            : "「\(devName)」滤网洁净度 \(pct)%，累计等效运行 \(hoursStr) 小时，状态良好"
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - 重置滤网保养计时 (v1.9.45)

struct ResetFilterMaintenanceIntent: AppIntent {
    static var title: LocalizedStringResource = "重置滤网保养计时"
    static var description = IntentDescription("清洗或更换滤网后重置空调滤网运行时间与洁净度", categoryName: "空调控制")

    @Parameter(title: "设备名称", description: "可选；留空使用主设备，填“全部”或“全屋”重置所有设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        if let name = deviceName, (name.contains("全") || name.contains("所有")) {
            model.resetAllFilterMaintenance()
            let count = model.allUnifiedDevices.count
            return .result(dialog: "已重置全屋 \(count) 台空调滤网保养计时，洁净度恢复 100%")
        }
        guard let deviceId = resolveDeviceId(named: deviceName) else {
            throw ACIntentError.message("没有可控制的空调设备")
        }
        let devName = model.deviceName(for: deviceId)
        model.resetFilterMaintenance(for: deviceId)
        return .result(dialog: "已重置「\(devName)」滤网保养计时，洁净度恢复 100%")
    }
}

// MARK: - 取消计划调度任务 (v1.9.55)

struct CancelACSchedulesIntent: AppIntent {
    static var title: LocalizedStringResource = "取消空调定时"
    static var description = IntentDescription("取消海尔空调正在生效的定时或倒计时任务", categoryName: "空调控制")

    @Parameter(title: "设备名称", description: "可选；留空则取消全屋所有定时任务，指定名称则取消该设备任务")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        if let name = deviceName, !name.isEmpty && !name.contains("全") && !name.contains("所有") {
            guard let deviceId = resolveDeviceId(named: name) else {
                throw ACIntentError.message("未找到指定名称的空调设备")
            }
            let devName = model.deviceName(for: deviceId)
            let count = model.cancelSchedules(for: [deviceId])
            if count > 0 {
                return .result(dialog: "已为您取消「\(devName)」的 \(count) 个定时任务")
            } else {
                return .result(dialog: "「\(devName)」当前没有正在运行的定时任务")
            }
        } else {
            let count = model.cancelAllSchedules()
            if count > 0 {
                return .result(dialog: "已为您取消全屋所有定时与倒计时任务（共 \(count) 个）")
            } else {
                return .result(dialog: "全屋当前没有正在运行的定时任务")
            }
        }
    }
}

// MARK: - 暂停/恢复计划调度任务 (v1.9.60)

struct PauseACSchedulesIntent: AppIntent {
    static var title: LocalizedStringResource = "暂停空调定时任务"
    static var description = IntentDescription("临时暂停海尔空调已设定的定时任务或倒计时", categoryName: "空调控制")

    @Parameter(title: "设备名称", description: "可选；留空则暂停全屋所有定时任务，指定名称则暂停该设备任务")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        if let name = deviceName, !name.isEmpty && !name.contains("全") && !name.contains("所有") {
            guard let deviceId = resolveDeviceId(named: name) else {
                throw ACIntentError.message("未找到指定名称的空调设备")
            }
            let devName = model.deviceName(for: deviceId)
            let count = model.setScheduledActionsEnabled(for: [deviceId], enabled: false)
            if count > 0 {
                return .result(dialog: "已为您暂停「\(devName)」的 \(count) 个定时任务")
            } else {
                return .result(dialog: "「\(devName)」当前没有可暂停的定时任务")
            }
        } else {
            let count = model.setAllScheduledActionsEnabled(false)
            if count > 0 {
                return .result(dialog: "已为您临时暂停全屋所有定时与倒计时任务（共 \(count) 个）")
            } else {
                return .result(dialog: "全屋当前没有可暂停的定时任务")
            }
        }
    }
}

struct ResumeACSchedulesIntent: AppIntent {
    static var title: LocalizedStringResource = "恢复空调定时任务"
    static var description = IntentDescription("恢复海尔空调已暂停的定时任务生效", categoryName: "空调控制")

    @Parameter(title: "设备名称", description: "可选；留空则恢复全屋所有定时任务，指定名称则恢复该设备任务")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        if let name = deviceName, !name.isEmpty && !name.contains("全") && !name.contains("所有") {
            guard let deviceId = resolveDeviceId(named: name) else {
                throw ACIntentError.message("未找到指定名称的空调设备")
            }
            let devName = model.deviceName(for: deviceId)
            let count = model.setScheduledActionsEnabled(for: [deviceId], enabled: true)
            if count > 0 {
                return .result(dialog: "已为您恢复「\(devName)」的 \(count) 个定时任务生效")
            } else {
                return .result(dialog: "「\(devName)」当前没有需要恢复的暂停任务")
            }
        } else {
            let count = model.setAllScheduledActionsEnabled(true)
            if count > 0 {
                return .result(dialog: "已为您恢复全屋所有定时与倒计时任务生效（共 \(count) 个）")
            } else {
                return .result(dialog: "全屋当前没有需要恢复的暂停任务")
            }
        }
    }
}

// MARK: - 定时与倒计时计划调度 (v1.9.56)

struct ScheduleACPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "设置空调定时与倒计时"
    static var description = IntentDescription("为海尔空调设定定时开关机或倒计时任务", categoryName: "空调控制")

    @Parameter(title: "开机", default: false)
    var powerOn: Bool

    @Parameter(title: "倒计时（分钟）", description: "例如 30、60；若指定则优先作为倒计时任务")
    var countdownMinutes: Int?

    @Parameter(title: "指定时间（时:分）", description: "例如 22:00、07:30")
    var timeString: String?

    @Parameter(title: "每天重复", default: false)
    var repeatsDaily: Bool

    @Parameter(title: "周期重复（工作日/周末/每天/每周一等）", description: "可选；填写“工作日”、“周末”、“每天”、“每周一”等")
    var repeatSchedule: String?

    @Parameter(title: "设备名称", description: "可选；留空控制全屋或默认设备")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard model.gatewayConnected else {
            throw ACIntentError.message("空调网关连接中断，请稍后重试")
        }

        let targetDeviceIds: [String]
        let scopeName: String
        let isAllScope = (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
        if isAllScope {
            let controllable = model.allUnifiedDevices.filter { model.reachability(for: $0.id).isControllable }
            guard !controllable.isEmpty else {
                throw ACIntentError.message("未发现可控制的就绪空调设备")
            }
            targetDeviceIds = controllable.map(\.id)
            scopeName = targetDeviceIds.count > 1 ? "全屋 \(targetDeviceIds.count) 台空调" : "空调"
        } else if let name = deviceName, !name.isEmpty {
            if let dev = model.allUnifiedDevices.first(where: { $0.name.contains(name) }) {
                targetDeviceIds = [dev.id]
                scopeName = "「\(dev.name)」"
            } else {
                throw ACIntentError.message("未找到名称包含「\(name)」的空调设备")
            }
        } else if let primaryId = model.primaryDeviceId {
            targetDeviceIds = [primaryId]
            scopeName = "「\(model.deviceName(for: primaryId))」"
        } else {
            let controllable = model.allUnifiedDevices.filter { model.reachability(for: $0.id).isControllable }
            guard !controllable.isEmpty else {
                throw ACIntentError.message("未发现可控制的就绪空调设备")
            }
            targetDeviceIds = controllable.map(\.id)
            scopeName = targetDeviceIds.count > 1 ? "全屋 \(targetDeviceIds.count) 台空调" : "空调"
        }

        let attrVal = AttrValue.bool(powerOn)
        guard let valJSON = ScheduledAction.valueJSON(attrVal) else {
            throw ACIntentError.message("参数构造失败")
        }

        let actionDesc = powerOn ? "开机" : "关机"

        // 1. 倒计时任务分支
        if let mins = countdownMinutes, mins > 0 {
            let fireDate = Date().addingTimeInterval(TimeInterval(mins * 60))
            let timeDesc = (mins >= 60 && mins % 60 == 0) ? "\(mins / 60) 小时" : "\(mins) 分钟"
            let actionName = "\(timeDesc)后\(actionDesc)"

            for devId in targetDeviceIds {
                let devName = model.deviceName(for: devId)
                let action = ScheduledAction(
                    name: "「\(devName)」\(actionName)",
                    deviceId: devId,
                    attrName: "onOffStatus",
                    attrDesc: "开关",
                    attrValueJSON: valJSON,
                    fireDate: fireDate,
                    repeatsDaily: false,
                    repeatWeekdays: [],
                    enabled: true
                )
                model.addScheduledAction(action)
            }
            return .result(dialog: "已为\(scopeName)设定 \(timeDesc) 后\(actionDesc)")
        }

        // 2. 指定时间或周期重复定时任务分支 (v1.9.57)
        let calendar = Calendar.current
        let (hour, minute): (Int, Int) = {
            if let tStr = timeString {
                let parts = tStr.split(separator: ":").compactMap { Int($0) }
                if parts.count >= 2 && parts[0] >= 0 && parts[0] <= 23 && parts[1] >= 0 && parts[1] < 60 {
                    return (parts[0], parts[1])
                }
            }
            // 默认晚 22:00
            return (22, 0)
        }()

        let (targetWeekdays, isDaily, repeatLabel): ([Int], Bool, String) = {
            let sched = (repeatSchedule ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !sched.isEmpty, let parsed = VoiceCommandParser.parseRepeatWeekdays(sched) {
                return (parsed.weekdays, parsed.weekdays.isEmpty, parsed.label)
            }
            if repeatsDaily || sched.contains("每天") || sched.contains("天天") || sched.contains("每日") || sched.contains("每晚") || sched.contains("每早") {
                return ([], true, "每天")
            }
            // 兼容单星期字面量输入（如 "周一"、"星期二"、"礼拜三"），前置排除否定词 (v1.9.97)
            guard !sched.contains("非") && !sched.contains("除") else {
                return ([], false, "")
            }
            if sched.contains("周一") || sched.contains("星期一") || sched.contains("礼拜一") {
                return ([2], false, "每周一")
            } else if sched.contains("周二") || sched.contains("星期二") || sched.contains("礼拜二") {
                return ([3], false, "每周二")
            } else if sched.contains("周三") || sched.contains("星期三") || sched.contains("礼拜三") {
                return ([4], false, "每周三")
            } else if sched.contains("周四") || sched.contains("星期四") || sched.contains("礼拜四") {
                return ([5], false, "每周四")
            } else if sched.contains("周五") || sched.contains("星期五") || sched.contains("礼拜五") {
                return ([6], false, "每周五")
            } else if sched.contains("周六") || sched.contains("星期六") || sched.contains("礼拜六") {
                return ([7], false, "每周六")
            } else if sched.contains("周日") || sched.contains("周天") || sched.contains("星期天") || sched.contains("星期日") || sched.contains("礼拜天") || sched.contains("礼拜日") {
                return ([1], false, "每周日")
            }
            return ([], false, "")
        }()

        let fireDate = AppModel.initialFireDate(forHour: hour, minute: minute, weekdays: targetWeekdays, calendar: calendar)
        let timeStr = String(format: "%02d:%02d", hour, minute)
        let repeatPrefix = repeatLabel.isEmpty ? "" : "\(repeatLabel) "
        let actionName = "\(repeatPrefix)\(timeStr) \(actionDesc)"

        for devId in targetDeviceIds {
            let devName = model.deviceName(for: devId)
            let action = ScheduledAction(
                name: "「\(devName)」\(actionName)",
                deviceId: devId,
                attrName: "onOffStatus",
                attrDesc: "开关",
                attrValueJSON: valJSON,
                fireDate: fireDate,
                repeatsDaily: isDaily,
                repeatWeekdays: targetWeekdays,
                enabled: true
            )
            model.addScheduledAction(action)
        }

        return .result(dialog: "已为\(scopeName)设定 \(repeatPrefix)\(timeStr) \(actionDesc)")
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
                    intent: TurnOffAllACIntent(),
                    phrases: [
                        "用 \(.applicationName) 关闭所有空调",
                        "用 \(.applicationName) 全屋关机",
                        "关闭全屋 \(.applicationName)",
                    ],
                    shortTitle: "关闭全屋空调",
                    systemImageName: "power.circle.fill"
                ),
                AppShortcut(
                    intent: TurnOnAllACIntent(),
                    phrases: [
                        "用 \(.applicationName) 开启所有空调",
                        "用 \(.applicationName) 全屋开机",
                        "开启全屋 \(.applicationName)",
                    ],
                    shortTitle: "开启全屋空调",
                    systemImageName: "air.conditioner.horizontal.fill"
                ),
                AppShortcut(
                    intent: StartSelfCleaningIntent(),
                    phrases: [
                        "用 \(.applicationName) 开启自清洁",
                        "用 \(.applicationName) 启动自清洁",
                        "清洗蒸发器 \(.applicationName)",
                    ],
                    shortTitle: "自清洁",
                    systemImageName: "sparkles"
                ),
                AppShortcut(
                    intent: SetACModeIntent(),
                    phrases: [
                        "用 \(.applicationName) 切换模式",
                        "用 \(.applicationName) 开启制冷",
                        "用 \(.applicationName) 开启制热",
                        "用 \(.applicationName) 全屋制冷",
                        "用 \(.applicationName) 全屋制热",
                        "\(.applicationName) 切换模式",
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
                AppShortcut(
                    intent: GetACHumidityIntent(),
                    phrases: [
                        "用 \(.applicationName) 查询湿度",
                        "\(.applicationName) 室内湿度",
                        "\(.applicationName) 现在湿度多少",
                    ],
                    shortTitle: "查询湿度",
                    systemImageName: "humidity.fill"
                ),
                AppShortcut(
                    intent: GetACStatusIntent(),
                    phrases: [
                        "用 \(.applicationName) 查询状态",
                        "用 \(.applicationName) 查询空调状态",
                        "\(.applicationName) 状态怎么样",
                        "\(.applicationName) 当前状态",
                    ],
                    shortTitle: "查询状态",
                    systemImageName: "info.circle.fill"
                ),
                AppShortcut(
                    intent: StartSleepCurveIntent(),
                    phrases: [
                        "用 \(.applicationName) 开启睡眠模式",
                        "用 \(.applicationName) 打开睡眠模式",
                        "用 \(.applicationName) 开启睡眠曲线",
                    ],
                    shortTitle: "开启睡眠模式",
                    systemImageName: "bed.double.fill"
                ),
                AppShortcut(
                    intent: StopSleepCurveIntent(),
                    phrases: [
                        "用 \(.applicationName) 停止睡眠模式",
                        "用 \(.applicationName) 关闭睡眠模式",
                        "用 \(.applicationName) 退出睡眠模式",
                    ],
                    shortTitle: "停止睡眠模式",
                    systemImageName: "moon.zzz"
                ),
                AppShortcut(
                    intent: StopSelfCleaningIntent(),
                    phrases: [
                        "用 \(.applicationName) 停止自清洁",
                        "用 \(.applicationName) 关闭自清洁",
                        "停止蒸发器自清洁 \(.applicationName)",
                    ],
                    shortTitle: "停止自清洁",
                    systemImageName: "xmark.circle.fill"
                ),
                AppShortcut(
                    intent: GetFilterHealthIntent(),
                    phrases: [
                        "用 \(.applicationName) 查询滤网",
                        "\(.applicationName) 滤网怎么样",
                        "\(.applicationName) 滤网状态",
                        "查询空调滤网 \(.applicationName)",
                    ],
                    shortTitle: "查询滤网",
                    systemImageName: "sparkles"
                ),
                AppShortcut(
                    intent: ResetFilterMaintenanceIntent(),
                    phrases: [
                        "用 \(.applicationName) 重置滤网",
                        "\(.applicationName) 滤网已清洗",
                        "\(.applicationName) 滤网洗好了",
                        "重置空调滤网 \(.applicationName)",
                    ],
                    shortTitle: "重置滤网",
                    systemImageName: "arrow.counterclockwise"
                ),
                AppShortcut(
                    intent: SetACWindSpeedIntent(),
                    phrases: [
                        "用 \(.applicationName) 调节风速",
                        "用 \(.applicationName) 设置风速",
                        "\(.applicationName) 调整风速",
                    ],
                    shortTitle: "调节风速",
                    systemImageName: "wind"
                ),
                AppShortcut(
                    intent: AdjustACTemperatureIntent(),
                    phrases: [
                        "用 \(.applicationName) 微调温度",
                        "用 \(.applicationName) 升高温度",
                        "用 \(.applicationName) 降低温度",
                        "用 \(.applicationName) 升温",
                        "用 \(.applicationName) 降温",
                        "用 \(.applicationName) 上调温度",
                        "用 \(.applicationName) 下调温度",
                        "\(.applicationName) 调高温度",
                        "\(.applicationName) 调低温度",
                        "\(.applicationName) 上调温度",
                        "\(.applicationName) 下调温度",
                    ],
                    shortTitle: "微调温度",
                    systemImageName: "thermometer.high"
                ),
                AppShortcut(
                    intent: CancelACSchedulesIntent(),
                    phrases: [
                        "用 \(.applicationName) 取消定时",
                        "用 \(.applicationName) 取消所有定时",
                        "\(.applicationName) 取消定时",
                        "取消全屋定时 \(.applicationName)",
                    ],
                    shortTitle: "取消定时",
                    systemImageName: "xmark.circle"
                ),
                AppShortcut(
                    intent: PauseACSchedulesIntent(),
                    phrases: [
                        "用 \(.applicationName) 暂停定时",
                        "用 \(.applicationName) 暂停所有定时",
                        "\(.applicationName) 暂停定时",
                        "暂停全屋定时 \(.applicationName)",
                    ],
                    shortTitle: "暂停定时",
                    systemImageName: "pause.circle"
                ),
                AppShortcut(
                    intent: ResumeACSchedulesIntent(),
                    phrases: [
                        "用 \(.applicationName) 恢复定时",
                        "用 \(.applicationName) 恢复所有定时",
                        "\(.applicationName) 恢复定时",
                        "恢复全屋定时 \(.applicationName)",
                    ],
                    shortTitle: "恢复定时",
                    systemImageName: "play.circle"
                ),
                AppShortcut(
                    intent: ScheduleACPowerIntent(),
                    phrases: [
                        "用 \(.applicationName) 定时关机",
                        "用 \(.applicationName) 倒计时关机",
                        "用 \(.applicationName) 每天定时关机",
                        "用 \(.applicationName) 每天定时开机",
                        "用 \(.applicationName) 工作日定时关机",
                        "用 \(.applicationName) 工作日定时开机",
                        "用 \(.applicationName) 周末定时关机",
                        "用 \(.applicationName) 周末定时开机",
                        "用 \(.applicationName) 周五至周日定时开机",
                        "用 \(.applicationName) 周五至周日定时关机",
                        "用 \(.applicationName) 周一至周三定时开机",
                        "\(.applicationName) 定时关机",
                        "\(.applicationName) 倒计时关机",
                        "\(.applicationName) 每天定时关机",
                        "\(.applicationName) 每天定时开机",
                        "\(.applicationName) 工作日定时关机",
                        "\(.applicationName) 工作日定时开机",
                        "\(.applicationName) 周末定时关机",
                        "\(.applicationName) 周末定时开机",
                        "\(.applicationName) 周五至周日定时开机",
                        "\(.applicationName) 周五至周日定时关机",
                    ],
                    shortTitle: "设置定时",
                    systemImageName: "clock.badge.checkmark"
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
                    intent: AdjustACTemperatureIntent(),
                    phrases: [
                        "用 \(.applicationName) 微调温度",
                        "用 \(.applicationName) 升高温度",
                        "用 \(.applicationName) 降低温度",
                        "用 \(.applicationName) 升温",
                        "用 \(.applicationName) 降温",
                        "用 \(.applicationName) 上调温度",
                        "用 \(.applicationName) 下调温度",
                    ]
                ),
                AppShortcut(
                    intent: TurnOffAllACIntent(),
                    phrases: [
                        "用 \(.applicationName) 关闭所有空调",
                        "用 \(.applicationName) 全屋关机",
                    ]
                ),
                AppShortcut(
                    intent: TurnOnAllACIntent(),
                    phrases: [
                        "用 \(.applicationName) 开启所有空调",
                        "用 \(.applicationName) 全屋开机",
                    ]
                ),
                AppShortcut(
                    intent: StartSelfCleaningIntent(),
                    phrases: [
                        "用 \(.applicationName) 开启自清洁",
                    ]
                ),
                AppShortcut(
                    intent: SetACModeIntent(),
                    phrases: [
                        "用 \(.applicationName) 切换模式",
                        "用 \(.applicationName) 开启制冷",
                        "用 \(.applicationName) 开启制热",
                        "用 \(.applicationName) 全屋制冷",
                        "用 \(.applicationName) 全屋制热",
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
                AppShortcut(
                    intent: GetACHumidityIntent(),
                    phrases: [
                        "用 \(.applicationName) 查询湿度",
                        "\(.applicationName) 室内湿度",
                    ]
                ),
                AppShortcut(
                    intent: GetACStatusIntent(),
                    phrases: [
                        "用 \(.applicationName) 查询状态",
                        "用 \(.applicationName) 查询空调状态",
                        "\(.applicationName) 状态怎么样",
                        "\(.applicationName) 当前状态",
                    ]
                ),
                AppShortcut(
                    intent: StartSleepCurveIntent(),
                    phrases: [
                        "用 \(.applicationName) 开启睡眠模式",
                        "用 \(.applicationName) 打开睡眠模式",
                        "用 \(.applicationName) 开启睡眠曲线",
                    ]
                ),
                AppShortcut(
                    intent: StopSleepCurveIntent(),
                    phrases: [
                        "用 \(.applicationName) 停止睡眠模式",
                        "用 \(.applicationName) 关闭睡眠模式",
                        "用 \(.applicationName) 退出睡眠模式",
                    ]
                ),
                AppShortcut(
                    intent: StopSelfCleaningIntent(),
                    phrases: [
                        "用 \(.applicationName) 停止自清洁",
                        "用 \(.applicationName) 关闭自清洁",
                    ]
                ),
                AppShortcut(
                    intent: GetFilterHealthIntent(),
                    phrases: [
                        "用 \(.applicationName) 查询滤网",
                        "\(.applicationName) 滤网状态",
                    ]
                ),
                AppShortcut(
                    intent: ResetFilterMaintenanceIntent(),
                    phrases: [
                        "用 \(.applicationName) 重置滤网",
                        "\(.applicationName) 滤网已清洗",
                        "\(.applicationName) 滤网洗好了",
                    ]
                ),
                AppShortcut(
                    intent: SetACWindSpeedIntent(),
                    phrases: [
                        "用 \(.applicationName) 调节风速",
                        "用 \(.applicationName) 设置风速",
                    ]
                ),
                AppShortcut(
                    intent: CancelACSchedulesIntent(),
                    phrases: [
                        "用 \(.applicationName) 取消定时",
                        "用 \(.applicationName) 取消所有定时",
                    ]
                ),
                AppShortcut(
                    intent: PauseACSchedulesIntent(),
                    phrases: [
                        "用 \(.applicationName) 暂停定时",
                        "用 \(.applicationName) 暂停所有定时",
                    ]
                ),
                AppShortcut(
                    intent: ResumeACSchedulesIntent(),
                    phrases: [
                        "用 \(.applicationName) 恢复定时",
                        "用 \(.applicationName) 恢复所有定时",
                    ]
                ),
                AppShortcut(
                    intent: ScheduleACPowerIntent(),
                    phrases: [
                        "用 \(.applicationName) 定时关机",
                        "用 \(.applicationName) 倒计时关机",
                        "用 \(.applicationName) 每天定时关机",
                        "用 \(.applicationName) 每天定时开机",
                        "用 \(.applicationName) 工作日定时关机",
                        "用 \(.applicationName) 工作日定时开机",
                        "用 \(.applicationName) 周末定时关机",
                        "用 \(.applicationName) 周末定时开机",
                        "用 \(.applicationName) 一三五定时开机",
                        "用 \(.applicationName) 一三五定时关机",
                        "用 \(.applicationName) 周一至周日定时开机",
                        "用 \(.applicationName) 周一至周日定时关机",
                    ]
                ),
            ]
        }
    }
}
