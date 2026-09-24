import AppKit
import SwiftUI
import HaierACCore

/// 悬浮语音胶囊窗口控制器
@MainActor
public final class VoiceCapsuleWindowController: NSObject, NSWindowDelegate {
    public static let shared = VoiceCapsuleWindowController()

    private var window: NSPanel?
    private var dismissTimer: Timer?

    private override init() {
        super.init()
        setupCommandBinding()
    }

    /// 绑定指令识别后的执行逻辑
    private func setupCommandBinding() {
        VoiceControlManager.shared.onCommandRecognized = { [weak self] text in
            Task { @MainActor in
                self?.handleVoiceInput(text)
            }
        }
    }

    /// 切换语音控制胶囊的显示/隐藏
    public func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    /// 显示语音控制胶囊并开始录音
    public func show() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        let model = AppModel.shared
        let targetName = currentDeviceDisplayName(model: model)

        if window == nil {
            createWindow(targetName: targetName)
        } else {
            updateContentView(targetName: targetName)
        }

        guard let window = window else { return }

        // 居中偏上位置（类似 Spotlight）
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowWidth: CGFloat = 480
            let windowHeight: CGFloat = 190
            let x = screenRect.midX - (windowWidth / 2)
            let y = screenRect.maxY - windowHeight - 120
            window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 开始语音识别
        Task {
            await VoiceControlManager.shared.startListening()
        }
    }

    /// 隐藏并关闭语音胶囊
    public func hide() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        VoiceControlManager.shared.stopListening()
        VoiceControlManager.shared.reset()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window?.animator().alphaValue = 0.0
        }, completionHandler: {
            Task { @MainActor in
                VoiceCapsuleWindowController.shared.window?.orderOut(nil)
                VoiceCapsuleWindowController.shared.window?.alphaValue = 1.0
            }
        })
    }

    // MARK: - 窗口创建与管理

    private func createWindow(targetName: String) {
        let panel = CustomKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 190),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // 由 SwiftUI 内部渲染柔和投影
        panel.delegate = self
        panel.isMovableByWindowBackground = true

        self.window = panel
        updateContentView(targetName: targetName)
    }

    private func updateContentView(targetName: String) {
        let view = VoiceCapsuleView(
            voiceManager: VoiceControlManager.shared,
            targetDeviceName: targetName,
            onClose: { [weak self] in
                self?.hide()
            },
            onCommit: {
                VoiceControlManager.shared.commitCurrentText()
            }
        )
        window?.contentView = NSHostingView(rootView: view)
    }

    private func currentDeviceDisplayName(model: AppModel) -> String {
        let targetId = model.menuBarDeviceId ?? model.allUnifiedDevices.first?.id
        if let targetId, let u = model.allUnifiedDevices.first(where: { $0.id == targetId }) {
            return u.name
        }
        return "未发现空调"
    }

    // MARK: - 指令解析与执行

    /// 从用户输入的语音文本中智能提取定向控制的具体空调列表（支持多房间组合，如“客厅和主卧”、“次卧跟书房”） (v1.9.33)
    private func resolveTargetDevices(for text: String, model: AppModel) -> [AppModel.UnifiedDevice] {
        let cleanText = text.lowercased()
        var matched: [AppModel.UnifiedDevice] = []

        // 1. 优先按完整设备名称匹配（如“客厅空调”、“主卧空调”）
        for dev in model.allUnifiedDevices {
            let name = dev.name.lowercased()
            if cleanText.contains(name) {
                if !matched.contains(where: { $0.id == dev.id }) {
                    matched.append(dev)
                }
            }
        }
        // 2. 尝试按房间名或核心词匹配（去除“空调”、“海尔”等后缀，保留“客厅”、“主卧”、“次卧”、“书房”等，至少2个字符）
        for dev in model.allUnifiedDevices {
            var coreName = dev.name.lowercased()
            coreName = coreName.replacingOccurrences(of: "空调", with: "")
            coreName = coreName.replacingOccurrences(of: "海尔", with: "")
            coreName = coreName.trimmingCharacters(in: .whitespacesAndNewlines)
            if coreName.count >= 2 && cleanText.contains(coreName) {
                if !matched.contains(where: { $0.id == dev.id }) {
                    matched.append(dev)
                }
            }
        }

        if !matched.isEmpty {
            return matched
        }

        // 3. 回退为菜单栏选中的设备或首个设备
        let fallbackId = model.menuBarDeviceId ?? model.allUnifiedDevices.first?.id
        if let fallbackDev = model.allUnifiedDevices.first(where: { $0.id == fallbackId }) {
            return [fallbackDev]
        }
        return []
    }

    private func handleVoiceInput(_ text: String) {
        let model = AppModel.shared
        guard let result = VoiceCommandParser.parse(text) else {
            VoiceControlManager.shared.markFailed("未能识别：“\(text)”，请换种说法试试")
            scheduleAutoDismiss(delay: 2.5)
            return
        }

        executeCommand(result.command, displayText: result.displayText, spokenText: text, model: model)
    }

    private func executeCommand(_ command: VoiceCommand, displayText: String, spokenText: String, model: AppModel) {
        // 1. 全屋指令与全局自清洁停止：不受单一设备离线约束 (v1.9.30 / v1.9.33)
        switch command {
        case .turnOffAll:
            guard model.gatewayConnected else {
                VoiceControlManager.shared.markFailed("网关重连中，无法执行全屋控制")
                scheduleAutoDismiss(delay: 2.5)
                return
            }
            let closedCount = model.turnOffAllDevices()
            if closedCount > 0 {
                VoiceControlManager.shared.markSuccess("已为您关闭全屋 \(closedCount) 台运行中的空调")
            } else {
                VoiceControlManager.shared.markSuccess("全屋空调当前均已处于关机或待机状态")
            }
            scheduleAutoDismiss(delay: 1.8)
            return

        case .turnOnAll:
            guard model.gatewayConnected else {
                VoiceControlManager.shared.markFailed("网关重连中，无法执行全屋控制")
                scheduleAutoDismiss(delay: 2.5)
                return
            }
            let openedCount = model.turnOnAllDevices()
            if openedCount > 0 {
                VoiceControlManager.shared.markSuccess("已为您开启全屋 \(openedCount) 台空调")
            } else {
                let controllableCount = model.allUnifiedDevices.filter { model.reachability(for: $0.id).isControllable }.count
                if controllableCount > 0 {
                    VoiceControlManager.shared.markSuccess("全屋空调当前均已处于开机运行状态")
                } else {
                    VoiceControlManager.shared.markFailed("未发现可控制的就绪空调设备")
                }
            }
            scheduleAutoDismiss(delay: 1.8)
            return

        case .presetAll(let modeName, let temp):
            guard model.gatewayConnected else {
                VoiceControlManager.shared.markFailed("网关重连中，无法执行全屋控制")
                scheduleAutoDismiss(delay: 2.5)
                return
            }
            let mode = ACModeCode.match(from: modeName) ?? .cooling
            let targetTemp: Double = {
                if let t = temp { return t }
                switch mode {
                case .heating: return 20.0
                case .cooling: return 26.0
                case .dehumidify: return 24.0
                case .auto: return 24.0
                case .fan: return 26.0
                }
            }()
            let count = model.applyPresetToAllDevices(mode: mode, temperature: targetTemp)
            if count > 0 {
                let tempDesc = targetTemp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(targetTemp))" : String(format: "%.1f", targetTemp)
                if mode == .fan {
                    VoiceControlManager.shared.markSuccess("已开启全屋 \(count) 台空调（送风模式）")
                } else if mode == .dehumidify {
                    VoiceControlManager.shared.markSuccess("已开启全屋 \(count) 台空调（除湿模式）")
                } else {
                    VoiceControlManager.shared.markSuccess("已开启全屋 \(count) 台空调（\(mode.desc) \(tempDesc)°C）")
                }
            } else {
                VoiceControlManager.shared.markFailed("未发现可控制的就绪空调设备")
            }
            scheduleAutoDismiss(delay: 1.8)
            return

        case .setTemperatureAll(let temp):
            guard model.gatewayConnected else {
                VoiceControlManager.shared.markFailed("网关重连中，无法执行全屋控制")
                scheduleAutoDismiss(delay: 2.5)
                return
            }
            let controllableDevices = model.allUnifiedDevices.filter { model.reachability(for: $0.id).isControllable }
            guard !controllableDevices.isEmpty else {
                VoiceControlManager.shared.markFailed("未发现可控制的就绪空调设备")
                scheduleAutoDismiss(delay: 2.0)
                return
            }
            model.sendAttributeToDevices("targetTemperature", value: .double(temp), deviceIds: controllableDevices.map(\.id))
            let formatted = temp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(temp))" : String(format: "%.1f", temp)
            VoiceControlManager.shared.markSuccess("已将全屋 \(controllableDevices.count) 台空调温度调至 \(formatted)°C")
            scheduleAutoDismiss(delay: 1.8)
            return

        case .stopSelfCleaning:
            if model.isSelfCleaningActive {
                model.stopSelfCleaning()
                VoiceControlManager.shared.markSuccess("已停止蒸发器自清洁")
            } else {
                VoiceControlManager.shared.markSuccess("当前未在执行自清洁")
            }
            scheduleAutoDismiss(delay: 1.5)
            return

        default:
            break
        }

        // 2. 定向设备解析：支持单设备与多房间组合识别 (v1.9.33)
        let targetDevices = resolveTargetDevices(for: spokenText, model: model)
        guard !targetDevices.isEmpty else {
            VoiceControlManager.shared.markFailed("未检测到已连接的空调设备")
            scheduleAutoDismiss(delay: 2.0)
            return
        }

        if targetDevices.count > 1 {
            executeMultiDeviceCommand(command, targetDevices: targetDevices, model: model)
            return
        }

        let targetDevice = targetDevices[0]
        let deviceId = targetDevice.id
        let targetName = targetDevice.name

        // 可达性门禁：仅在真正下发硬件控制指令时拦截，放行纯本地查询、定时管理与睡眠曲线退出 (v1.9.34 闭环 CR P1-1)
        let ensureControllable: () -> Bool = {
            let reach = model.reachability(for: deviceId)
            guard reach.isControllable else {
                let reason = reach == .gatewayReconnecting
                    ? "「\(targetName)」网关重连中，请稍后重试"
                    : "「\(targetName)」当前离线，无法执行语音指令"
                VoiceControlManager.shared.markFailed(reason)
                self.scheduleAutoDismiss(delay: 2.5)
                return false
            }
            return true
        }

        let isMultiDevice = model.allUnifiedDevices.count > 1
        let prefix = isMultiDevice ? "「\(targetName)」" : ""

        switch command {
        case .setPower(let on):
            guard ensureControllable() else { return }
            model.sendAttribute("onOffStatus", value: .bool(on), deviceId: deviceId)
            VoiceControlManager.shared.markSuccess(on ? "已开启\(prefix)空调" : "已关闭\(prefix)空调")

        case .setTemperature(let temp):
            guard ensureControllable() else { return }
            model.sendAttribute("targetTemperature", value: .double(temp), deviceId: deviceId)
            let formatted = temp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(temp))" : String(format: "%.1f", temp)
            VoiceControlManager.shared.markSuccess("已将\(prefix)温度调至 \(formatted)°C")

        case .adjustTemperature(let delta):
            guard ensureControllable() else { return }
            let currentTemp = model.attributes[deviceId]?["targetTemperature"]?.doubleValue ?? 26.0
            var newTemp = currentTemp + delta
            newTemp = min(max(newTemp, 16.0), 30.0) // 限制在 16~30
            model.sendAttribute("targetTemperature", value: .double(newTemp), deviceId: deviceId)
            let formatted = newTemp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(newTemp))" : String(format: "%.1f", newTemp)
            VoiceControlManager.shared.markSuccess("已微调\(prefix)温度至 \(formatted)°C")

        case .setMode(let modeName):
            guard ensureControllable() else { return }
            // 在数字模型中匹配模式
            if let modeAttr = model.attributes[deviceId]?["operationMode"],
               case .list(let options) = modeAttr.valueRange,
               let match = options.first(where: { $0.desc.contains(modeName) || modeName.contains($0.desc) }) {
                model.sendAttribute("operationMode", value: match.data, deviceId: deviceId)
                VoiceControlManager.shared.markSuccess("已将\(prefix)切换至「\(match.desc)」模式")
            } else {
                // 常见模式回退（统一采用 ACModeCode 标准码表：0=制冷, 1=制热, 2=送风, 3=除湿, 6=自动）
                if let matched = ACModeCode.match(from: modeName) {
                    model.sendAttribute("operationMode", value: .string(matched.rawValue), deviceId: deviceId)
                    VoiceControlManager.shared.markSuccess("已将\(prefix)切换至「\(matched.desc)」模式")
                } else {
                    VoiceControlManager.shared.markFailed("未能识别「\(modeName)」模式")
                }
            }

        case .setWindSpeed(let speedName):
            guard ensureControllable() else { return }
            if let windAttr = model.attributes[deviceId]?["windSpeed"],
               case .list(let options) = windAttr.valueRange,
               let match = options.first(where: { $0.desc.contains(speedName) || speedName.contains($0.desc) }) {
                model.sendAttribute("windSpeed", value: match.data, deviceId: deviceId)
                VoiceControlManager.shared.markSuccess("已调节\(prefix)风速为「\(match.desc)」")
            } else {
                VoiceControlManager.shared.markSuccess("已调节\(prefix)风速")
            }

        case .queryStatus:
            let isPower = model.attributes[deviceId]?["onOffStatus"]?.boolValue ?? false
            let powerDesc = isPower ? "正在运行" : "关机待机"
            let targetTemp = model.attributes[deviceId]?["targetTemperature"]?.doubleValue ?? 26.0
            if let indoor = model.currentIndoorTemperature(for: deviceId) {
                VoiceControlManager.shared.markSuccess("「\(targetName)」\(powerDesc)，室内温度 \(String(format: "%.1f", indoor))°C，设定 \(Int(targetTemp))°C")
            } else {
                VoiceControlManager.shared.markSuccess("「\(targetName)」\(powerDesc)，当前设定为 \(Int(targetTemp))°C")
            }

        case .applyScene(let sceneName):
            guard ensureControllable() else { return }
            if let scene = model.scenes.first(where: { $0.name.contains(sceneName) }) {
                model.applyScene(scene)
                VoiceControlManager.shared.markSuccess("已应用「\(scene.name)」情景")
            } else {
                VoiceControlManager.shared.markFailed("未找到「\(sceneName)」情景")
            }

        case .countdownPower(let minutes, let on):
            guard ensureControllable() else { return }
            let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
            let attrVal = AttrValue.bool(on)
            guard let valJSON = ScheduledAction.valueJSON(attrVal) else {
                VoiceControlManager.shared.markFailed("参数构造失败")
                scheduleAutoDismiss(delay: 2.0)
                return
            }
            let timeDesc: String
            if minutes >= 60 && minutes % 60 == 0 {
                timeDesc = "\(minutes / 60) 小时"
            } else {
                timeDesc = "\(minutes) 分钟"
            }
            let actionName = "\(timeDesc)后\(on ? "开机" : "关机")"
            let action = ScheduledAction(
                name: "\(prefix)\(actionName)",
                deviceId: deviceId,
                attrName: "onOffStatus",
                attrDesc: "开关",
                attrValueJSON: valJSON,
                fireDate: fireDate,
                repeatsDaily: false,
                repeatWeekdays: [],
                enabled: true
            )
            model.addScheduledAction(action)
            VoiceControlManager.shared.markSuccess("已为\(prefix)设置：\(actionName)")

        case .schedulePower(let hour, let minute, let on):
            guard ensureControllable() else { return }
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = hour
            components.minute = minute
            components.second = 0
            guard var targetDate = calendar.date(from: components) else {
                VoiceControlManager.shared.markFailed("时间解析失败")
                scheduleAutoDismiss(delay: 2.0)
                return
            }
            if targetDate <= Date() {
                // 如果今天此时刻已过，顺延至明天
                targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
            }
            let timeStr = String(format: "%02d:%02d", hour, minute)
            let actionName = "\(timeStr) \(on ? "开机" : "关机")"
            let attrVal = AttrValue.bool(on)
            guard let valJSON = ScheduledAction.valueJSON(attrVal) else {
                VoiceControlManager.shared.markFailed("参数构造失败")
                scheduleAutoDismiss(delay: 2.0)
                return
            }
            let action = ScheduledAction(
                name: "\(prefix)\(actionName)",
                deviceId: deviceId,
                attrName: "onOffStatus",
                attrDesc: "开关",
                attrValueJSON: valJSON,
                fireDate: targetDate,
                repeatsDaily: false,
                repeatWeekdays: [],
                enabled: true
            )
            model.addScheduledAction(action)
            VoiceControlManager.shared.markSuccess("已为\(prefix)设定：\(actionName)")

        case .cancelSchedules:
            // 严格按指定设备取消，杜绝定向无定时任务时穿透误删全屋其他设备定时 (v1.9.34 闭环 CR P2-1)
            let count = model.scheduledActions.filter { $0.deviceId == deviceId }.count
            if count > 0 {
                model.scheduledActions.removeAll(where: { $0.deviceId == deviceId })
                VoiceControlManager.shared.markSuccess("已取消\(prefix)定时任务（共 \(count) 个）")
            } else {
                VoiceControlManager.shared.markSuccess("「\(targetName)」当前没有正在运行的定时任务")
            }

        case .startSleepCurve(let curveName):
            guard ensureControllable() else { return }
            let curve: SleepCurveConfig
            if let curveName, let match = SleepCurveConfig.allPresets.first(where: { $0.name.contains(curveName) }) {
                curve = match
            } else {
                curve = .standard
            }
            model.startSleepCurve(curve: curve, deviceId: deviceId)
            VoiceControlManager.shared.markSuccess("已为\(prefix)启动「\(curve.name)」睡眠温阶曲线")

        case .stopSleepCurve:
            // 睡眠曲线退出与白噪音停止属于本地状态控制，即便网络临时颠簸也应允许停止 (v1.9.34)
            if model.activeSleepSession != nil {
                model.stopSleepCurve()
                VoiceControlManager.shared.markSuccess("已停止\(prefix)智能睡眠温阶")
            } else {
                VoiceControlManager.shared.markSuccess("当前未运行睡眠温阶曲线")
            }

        case .querySleepReport:
            // 本地会话报告查询，无需硬件在线校验 (v1.9.34)
            if let session = model.activeSleepSession {
                let stageName = session.currentStage?.name ?? "进行中"
                let targetTemp = session.effectiveTargetTemperature ?? session.currentStage?.targetTemperature ?? 26.0
                let tempStr = String(format: "%.1f°C", targetTemp).replacingOccurrences(of: ".0°C", with: "°C")
                if let nextFire = session.nextFireDate, let next = session.nextStage {
                    let mins = max(1, Int(nextFire.timeIntervalSince(Date()) / 60))
                    VoiceControlManager.shared.markSuccess("睡眠中：处于「\(stageName)」设定 \(tempStr)，\(mins) 分钟后进入「\(next.name)」")
                } else {
                    VoiceControlManager.shared.markSuccess("睡眠中：处于「\(stageName)」设定 \(tempStr)")
                }
            } else if let last = model.sleepHistory.first {
                VoiceControlManager.shared.markSuccess("昨晚「\(last.curveName)」共运行 \(last.durationText)，已\(last.endReason.rawValue)")
            } else {
                VoiceControlManager.shared.markSuccess("暂无睡眠调温记录")
            }

        case .startSelfCleaning:
            guard ensureControllable() else { return }
            if model.isSelfCleaningActive {
                let remaining = model.selfCleaningRemainingSeconds
                VoiceControlManager.shared.markSuccess("56°C 蒸发器自清洁进行中（剩余 \(remaining / 60) 分钟）")
            } else {
                model.startSelfCleaning(deviceId: deviceId)
                VoiceControlManager.shared.markSuccess("已为\(prefix)启动 56°C 蒸发器高温自清洁")
            }

        case .turnOffAll, .turnOnAll, .stopSelfCleaning, .presetAll, .setTemperatureAll:
            break // 已在指令前置流程中由全局调度完成分发
        }

        scheduleAutoDismiss(delay: 1.5)
    }

    /// 多设备定向协同控制执行 (v1.9.33)
    private func executeMultiDeviceCommand(_ command: VoiceCommand, targetDevices: [AppModel.UnifiedDevice], model: AppModel) {
        let controllable = targetDevices.filter { model.reachability(for: $0.id).isControllable }
        guard !controllable.isEmpty else {
            let names = targetDevices.map(\.name).joined(separator: "、")
            VoiceControlManager.shared.markFailed("「\(names)」当前均处于离线或不可控状态")
            scheduleAutoDismiss(delay: 2.5)
            return
        }

        let prefix = "「\(controllable.map(\.name).joined(separator: "、"))」"
        let ids = controllable.map(\.id)

        switch command {
        case .setPower(let on):
            if on {
                model.sendAttributeToDevices("onOffStatus", value: .bool(true), deviceIds: ids)
                VoiceControlManager.shared.markSuccess("已开启\(prefix)电源")
            } else {
                model.turnOffDevices(deviceIds: ids)
                VoiceControlManager.shared.markSuccess("已关闭\(prefix)电源")
            }

        case .setTemperature(let temp):
            model.sendAttributeToDevices("targetTemperature", value: .double(temp), deviceIds: ids)
            let formatted = temp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(temp))" : String(format: "%.1f", temp)
            VoiceControlManager.shared.markSuccess("已将\(prefix)温度调至 \(formatted)°C")

        case .adjustTemperature(let delta):
            for devId in ids {
                let currentTemp = model.attributes[devId]?["targetTemperature"]?.doubleValue ?? 26.0
                var newTemp = currentTemp + delta
                newTemp = min(max(newTemp, 16.0), 30.0)
                model.sendAttribute("targetTemperature", value: .double(newTemp), deviceId: devId)
            }
            VoiceControlManager.shared.markSuccess("已微调\(prefix)温度")

        case .setMode(let modeName):
            if let matched = ACModeCode.match(from: modeName) {
                model.sendAttributeToDevices("operationMode", value: .string(matched.rawValue), deviceIds: ids)
                VoiceControlManager.shared.markSuccess("已将\(prefix)切换至「\(matched.desc)」模式")
            } else {
                VoiceControlManager.shared.markFailed("未能识别「\(modeName)」模式")
            }

        case .setWindSpeed(let speedName):
            if let firstId = ids.first,
               let windAttr = model.attributes[firstId]?["windSpeed"],
               case .list(let options) = windAttr.valueRange,
               let match = options.first(where: { $0.desc.contains(speedName) || speedName.contains($0.desc) }) {
                model.sendAttributeToDevices("windSpeed", value: match.data, deviceIds: ids)
                VoiceControlManager.shared.markSuccess("已调节\(prefix)风速为「\(match.desc)」")
            } else {
                VoiceControlManager.shared.markSuccess("已调节\(prefix)风速")
            }

        default:
            VoiceControlManager.shared.markFailed("该操作暂不支持多设备批量执行")
        }

        scheduleAutoDismiss(delay: 1.8)
    }

    private func scheduleAutoDismiss(delay: TimeInterval) {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }
}

/// 支持无边框下成为 Key Window 并响应按键的 NSPanel
private final class CustomKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        // 按 Esc 键退出
        if event.keyCode == 53 {
            VoiceCapsuleWindowController.shared.hide()
            return
        }
        // 按 Return / Enter 提交
        if event.keyCode == 36 {
            VoiceControlManager.shared.commitCurrentText()
            return
        }
        super.keyDown(with: event)
    }
}
