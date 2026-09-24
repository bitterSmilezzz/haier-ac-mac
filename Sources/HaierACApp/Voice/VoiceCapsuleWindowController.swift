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

    private func handleVoiceInput(_ text: String) {
        let model = AppModel.shared
        guard let result = VoiceCommandParser.parse(text) else {
            VoiceControlManager.shared.markFailed("未能识别：“\(text)”，请换种说法试试")
            scheduleAutoDismiss(delay: 2.5)
            return
        }

        executeCommand(result.command, displayText: result.displayText, model: model)
    }

    private func executeCommand(_ command: VoiceCommand, displayText: String, model: AppModel) {
        guard let deviceId = model.menuBarDeviceId ?? model.allUnifiedDevices.first?.id else {
            VoiceControlManager.shared.markFailed("未检测到已连接的空调设备")
            scheduleAutoDismiss(delay: 2.0)
            return
        }

        let reach = model.reachability(for: deviceId)
        guard reach.isControllable else {
            let reason = reach == .gatewayReconnecting ? "网关重连中，无法执行语音指令" : "设备当前离线，无法执行语音指令"
            VoiceControlManager.shared.markFailed(reason)
            scheduleAutoDismiss(delay: 2.5)
            return
        }

        switch command {
        case .setPower(let on):
            model.sendAttribute("onOffStatus", value: .bool(on), deviceId: deviceId)
            VoiceControlManager.shared.markSuccess(on ? "已开启空调" : "已关闭空调")

        case .setTemperature(let temp):
            model.sendAttribute("targetTemperature", value: .double(temp), deviceId: deviceId)
            let formatted = temp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(temp))" : String(format: "%.1f", temp)
            VoiceControlManager.shared.markSuccess("已将温度调至 \(formatted)°C")

        case .adjustTemperature(let delta):
            let currentTemp = model.attributes[deviceId]?["targetTemperature"]?.doubleValue ?? 26.0
            var newTemp = currentTemp + delta
            newTemp = min(max(newTemp, 16.0), 30.0) // 限制在 16~30
            model.sendAttribute("targetTemperature", value: .double(newTemp), deviceId: deviceId)
            let formatted = newTemp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(newTemp))" : String(format: "%.1f", newTemp)
            VoiceControlManager.shared.markSuccess("已微调温度至 \(formatted)°C")

        case .setMode(let modeName):
            // 在数字模型中匹配模式
            if let modeAttr = model.attributes[deviceId]?["operationMode"],
               case .list(let options) = modeAttr.valueRange,
               let match = options.first(where: { $0.desc.contains(modeName) || modeName.contains($0.desc) }) {
                model.sendAttribute("operationMode", value: match.data, deviceId: deviceId)
                VoiceControlManager.shared.markSuccess("已切换至「\(match.desc)」模式")
            } else {
                // 常见模式回退（统一采用 ACModeCode 标准码表：0=制冷, 1=制热, 2=送风, 3=除湿, 6=自动）
                if let matched = ACModeCode.match(from: modeName) {
                    model.sendAttribute("operationMode", value: .string(matched.rawValue), deviceId: deviceId)
                    VoiceControlManager.shared.markSuccess("已切换至「\(matched.desc)」模式")
                } else {
                    VoiceControlManager.shared.markFailed("未能识别「\(modeName)」模式")
                }
            }

        case .setWindSpeed(let speedName):
            if let windAttr = model.attributes[deviceId]?["windSpeed"],
               case .list(let options) = windAttr.valueRange,
               let match = options.first(where: { $0.desc.contains(speedName) || speedName.contains($0.desc) }) {
                model.sendAttribute("windSpeed", value: match.data, deviceId: deviceId)
                VoiceControlManager.shared.markSuccess("已调节风速为「\(match.desc)」")
            } else {
                VoiceControlManager.shared.markSuccess("已调节风速")
            }

        case .queryStatus:
            if let attr = AppModel.indoorTemperatureAttribute(in: model.attributes[deviceId] ?? [:]),
               let temp = attr.doubleValue {
                VoiceControlManager.shared.markSuccess("当前室内温度为 \(Int(temp))°C")
            } else {
                VoiceControlManager.shared.markSuccess("设备连接正常，暂未读取到室温")
            }

        case .applyScene(let sceneName):
            if let scene = model.scenes.first(where: { $0.name.contains(sceneName) }) {
                model.applyScene(scene)
                VoiceControlManager.shared.markSuccess("已应用「\(scene.name)」情景")
            } else {
                VoiceControlManager.shared.markFailed("未找到「\(sceneName)」情景")
            }

        case .countdownPower(let minutes, let on):
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
                name: actionName,
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
            VoiceControlManager.shared.markSuccess("已设置：\(actionName)")

        case .schedulePower(let hour, let minute, let on):
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
                name: actionName,
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
            VoiceControlManager.shared.markSuccess("已设定：\(actionName)")

        case .cancelSchedules:
            let count = model.scheduledActions.count
            if count > 0 {
                model.scheduledActions.removeAll()
                VoiceControlManager.shared.markSuccess("已取消所有定时任务（共 \(count) 个）")
            } else {
                VoiceControlManager.shared.markSuccess("当前没有正在运行的定时任务")
            }

        case .startSleepCurve(let curveName):
            let curve: SleepCurveConfig
            if let curveName, let match = SleepCurveConfig.allPresets.first(where: { $0.name.contains(curveName) }) {
                curve = match
            } else {
                curve = .standard
            }
            model.startSleepCurve(curve: curve, deviceId: deviceId)
            VoiceControlManager.shared.markSuccess("已启动「\(curve.name)」睡眠温阶曲线")

        case .stopSleepCurve:
            if model.activeSleepSession != nil {
                model.stopSleepCurve()
                VoiceControlManager.shared.markSuccess("已停止智能睡眠温阶")
            } else {
                VoiceControlManager.shared.markSuccess("当前未运行睡眠温阶曲线")
            }

        case .querySleepReport:
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
        }

        scheduleAutoDismiss(delay: 1.5)
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
