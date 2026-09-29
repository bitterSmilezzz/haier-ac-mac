import AppKit
import SwiftUI
import Combine
import HaierACCore

/// 菜单栏状态项控制器：NSStatusItem + NSPopover（替代 MenuBarExtra）
///
/// 为什么不用 MenuBarExtra(.window)：
/// macOS 26 上该样式存在「窗口关闭后不销毁」的缺陷，会残留幽灵窗口遮挡其他应用
/// （表现为：点不动其他窗口、废纸篓确认弹窗被挡）。
/// NSPopover 是 macOS 菜单栏应用的标准方案：关闭即销毁、点击外部自动收起，无此问题。
@MainActor
final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let model: AppModel
    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    /// 创建状态栏图标（启动时调用一次）
    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "air.conditioner.horizontal", accessibilityDescription: "海尔空调")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeft
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        refreshTemperature()

        // 温度/开关/自清洁/睡眠/白噪音/设备选择/温度显示/网关连接等状态变化时刷新菜单栏标题与悬浮提示 Tooltip
        Publishers.MergeMany(
            model.$attributes.map { _ in () }.eraseToAnyPublisher(),
            model.$devices.map { _ in () }.eraseToAnyPublisher(),
            model.$manualDevices.map { _ in () }.eraseToAnyPublisher(),
            model.$menuBarDeviceId.map { _ in () }.eraseToAnyPublisher(),
            model.$menuBarShowTemperature.map { _ in () }.eraseToAnyPublisher(),
            model.$isSelfCleaningActive.map { _ in () }.eraseToAnyPublisher(),
            model.$selfCleaningRemainingSeconds.map { _ in () }.eraseToAnyPublisher(),
            model.$activeSleepSession.map { _ in () }.eraseToAnyPublisher(),
            model.$gatewayConnected.map { _ in () }.eraseToAnyPublisher(),
            model.$filterAccumulatedMinutes.map { _ in () }.eraseToAnyPublisher(),
            model.$scheduledActions.map { _ in () }.eraseToAnyPublisher(),
            EnergyAnalyticsEngine.shared.$currentInstantaneousPower.map { _ in () }.eraseToAnyPublisher(),
            AmbientSoundEngine.shared.$isPlaying.map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.refreshTemperature()
        }
        .store(in: &cancellables)
    }

    /// 菜单栏图标旁显示当前温度（如 26°）与动态多维状态悬浮 Tooltip
    private func refreshTemperature() {
        guard let button = statusItem?.button else { return }

        // 状态栏图标与标题动态感知 (v1.9.25: 开机运行态实心展示)
        if model.isSelfCleaningActive {
            let m = model.selfCleaningRemainingSeconds / 60
            let s = model.selfCleaningRemainingSeconds % 60
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "蒸发器自清洁")
            button.image?.isTemplate = true
            if model.menuBarShowTemperature {
                button.title = " 56°C (\(String(format: "%02d:%02d", m, s)))"
            } else {
                button.title = " (\(String(format: "%02d:%02d", m, s)))"
            }
        } else if model.activeSleepSession != nil {
            button.image = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "睡眠曲线运行中")
            button.image?.isTemplate = true
            if let text = model.menuBarTemperatureText {
                button.title = " \(text)"
            } else {
                button.title = ""
            }
        } else {
            let targetId = model.primaryDeviceId
            let isPowerOn: Bool = {
                guard let targetId else { return false }
                return model.reachability(for: targetId) == .available && (model.attribute("onOffStatus", deviceId: targetId)?.boolValue ?? false)
            }()
            let anyDeviceRunning = model.allUnifiedDevices.contains { dev in
                model.reachability(for: dev.id) == .available &&
                (model.attribute("onOffStatus", deviceId: dev.id)?.boolValue ?? false)
            }
            let isDisplayActive = isPowerOn || anyDeviceRunning
            let symbolName = isDisplayActive ? "air.conditioner.horizontal.fill" : "air.conditioner.horizontal"
            let desc: String = {
                if isPowerOn {
                    return "海尔空调 (运行中)"
                } else if anyDeviceRunning {
                    return "海尔空调 (其他房间运行中)"
                } else {
                    return "海尔空调 (待机)"
                }
            }()
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: desc)
            button.image?.isTemplate = true
            if let text = model.menuBarTemperatureText {
                button.title = " \(text)"
            } else {
                button.title = ""
            }
        }
        button.imagePosition = .imageLeft
        statusItem?.length = NSStatusItem.variableLength

        // 动态构建悬浮 Tooltip 状态概览 (v1.9.29 全量统一全屋设备与三态感知, v1.9.36 全屋概览)
        var tooltipParts: [String] = [
            model.gatewayConnected ? "海尔空调控制 (网关在线)" : "⚠️ 海尔云端网关重连中..."
        ]
        let allDevices = model.allUnifiedDevices
        let activeRunningDevices = allDevices.filter { dev in
            model.reachability(for: dev.id) == .available &&
            (model.attributes[dev.id]?["onOffStatus"]?.boolValue == true)
        }
        if allDevices.count > 1 {
            if !activeRunningDevices.isEmpty {
                tooltipParts.append("🏠 全屋 \(allDevices.count) 台空调中 \(activeRunningDevices.count) 台正在运行")
            } else {
                tooltipParts.append("🏠 全屋 \(allDevices.count) 台空调当前均处于待机状态")
            }
        }

        // 动态感知生效中且最近即将执行的定时与倒计时任务 (v1.9.65 毫秒级感知高精消歧, v1.9.67 多机同频倒计时消歧与长周期智能格式化)
        let now = Date()
        let upcomingSchedules = model.scheduledActions
            .filter { $0.enabled && $0.fireDate > now }
            .sorted(by: { $0.fireDate < $1.fireDate })
        if let firstAction = upcomingSchedules.first {
            let threshold = firstAction.fireDate.addingTimeInterval(5.0)
            let sameTimeActions = upcomingSchedules.filter {
                $0.fireDate <= threshold &&
                $0.attrName == firstAction.attrName &&
                $0.attrValue == firstAction.attrValue
            }
            let remSecs = Int(firstAction.fireDate.timeIntervalSince(now))
            let remDesc = Self.formatRemainingTimeSpan(remSecs: remSecs)
            let timeStr = DateFormatter.localizedString(from: firstAction.fireDate, dateStyle: .none, timeStyle: .short)
            let actionVerb = Self.extractPlanActionVerb(from: firstAction, devName: "")

            let targetDeviceDesc: String
            let devIds = Set(sameTimeActions.map(\.deviceId))
            if devIds.count >= allDevices.count && allDevices.count > 1 {
                targetDeviceDesc = "全屋 \(allDevices.count) 台空调"
            } else if devIds.count > 1 {
                let matchingDevices = allDevices.filter { devIds.contains($0.id) }
                targetDeviceDesc = matchingDevices.map { "「\($0.name)」" }.joined(separator: "、")
            } else {
                let devName = allDevices.first(where: { $0.id == firstAction.deviceId })?.name ?? "空调"
                targetDeviceDesc = "「\(devName)」"
            }
            let repeatSuffix: String = {
                if let label = firstAction.repeatLabel, !label.isEmpty {
                    return " [\(label)]"
                } else if firstAction.repeatsDaily {
                    return " [每天]"
                } else {
                    return ""
                }
            }()
            tooltipParts.append("⏱ 最近计划: \(targetDeviceDesc)将在 \(remDesc)后\(actionVerb) (\(timeStr)\(repeatSuffix))")
        }

        let primaryTargetId = model.primaryDeviceId
        if !allDevices.isEmpty {
            for dev in allDevices {
                let devId = dev.id
                let devName = dev.name
                let attrs = model.attributes[devId] ?? [:]
                let isPowerOn = attrs["onOffStatus"]?.boolValue ?? false
                let rawMode = attrs["operationMode"]?.value?.stringValue
                let modeCode = ACModeCode.match(from: rawMode)
                let targetTemp = attrs["targetTemperature"]?.doubleValue ?? 26.0
                let indoorTemp = model.currentIndoorTemperature(for: devId)
                let isCurrentTarget = (devId == primaryTargetId)

                let reach = model.reachability(for: devId)
                let starPrefix = isCurrentTarget ? "★" : " "
                switch reach {
                case .gatewayReconnecting:
                    tooltipParts.append("\(starPrefix) \(devName): ⏳ 网关重连中...")
                case .deviceOffline:
                    tooltipParts.append("\(starPrefix) \(devName): ⚡️ 设备离线 (未连网)")
                case .available:
                    if isPowerOn {
                        let modeGlyph: String
                        if let modeCode = modeCode {
                            switch modeCode {
                            case .cooling: modeGlyph = "❄️ 制冷"
                            case .heating: modeGlyph = "🔥 制热"
                            case .fan: modeGlyph = "🍃 送风"
                            case .dehumidify: modeGlyph = "💧 除湿"
                            case .auto: modeGlyph = "🔄 自动"
                            }
                        } else if let raw = rawMode, !raw.isEmpty {
                            modeGlyph = "⚙️ \(raw)"
                        } else {
                            modeGlyph = "⚙️ 运行中"
                        }
                        let targetTempStr = (targetTemp.truncatingRemainder(dividingBy: 1.0) == 0)
                            ? "\(Int(targetTemp))°C"
                            : String(format: "%.1f°C", targetTemp)
                        let rawWind = attrs["windSpeed"]?.value?.stringValue
                        let windStr = formatDisplayWindSpeed(rawWind)
                        var line = "\(starPrefix) \(devName): \(modeGlyph) \(targetTempStr) [\(windStr)]"
                        let devHum = model.currentIndoorHumidity(for: devId)
                        if let indoor = indoorTemp {
                            let indoorStr = (indoor.truncatingRemainder(dividingBy: 1.0) == 0)
                                ? "\(Int(indoor))°C"
                                : String(format: "%.1f°C", indoor)
                            if let h = devHum {
                                line += " (室内 \(indoorStr) · \(Int(round(h)))% RH)"
                            } else {
                                line += " (室内 \(indoorStr))"
                            }
                        } else if let h = devHum {
                            line += " (室内 \(Int(round(h)))% RH)"
                        }
                        tooltipParts.append(line)
                    } else {
                        var line = "\(starPrefix) \(devName): ⚪️ 待机"
                        let devHum = model.currentIndoorHumidity(for: devId)
                        if let indoor = indoorTemp {
                            let indoorStr = (indoor.truncatingRemainder(dividingBy: 1.0) == 0)
                                ? "\(Int(indoor))°C"
                                : String(format: "%.1f°C", indoor)
                            if let h = devHum {
                                line += " (室内 \(indoorStr) · \(Int(round(h)))% RH)"
                            } else {
                                line += " (室内 \(indoorStr))"
                            }
                        } else if let h = devHum {
                            line += " (室内 \(Int(round(h)))% RH)"
                        }
                        tooltipParts.append(line)
                    }
                }
            }
        }

        // 瞬时总功率 (v1.9.33: 智能适配 W / kW 格式)
        let instantPower = EnergyAnalyticsEngine.shared.currentInstantaneousPower
        if instantPower > 10.0 {
            if instantPower >= 1000.0 {
                tooltipParts.append(String(format: "⚡️ 全屋空调瞬时功率: %.2f kW", instantPower / 1000.0))
            } else {
                tooltipParts.append("⚡️ 全屋空调瞬时功率: \(Int(round(instantPower))) W")
            }
        }

        if model.isSelfCleaningActive {
            let m = model.selfCleaningRemainingSeconds / 60
            let s = model.selfCleaningRemainingSeconds % 60
            tooltipParts.append("✨ 56°C 高温除菌自清洁进行中 (剩余 \(String(format: "%02d:%02d", m, s)))")
        }

        if let session = model.activeSleepSession {
            tooltipParts.append("🌙 智能睡眠曲线运行中 (\(session.curveConfig.name))")
        }

        if AmbientSoundEngine.shared.isPlaying {
            tooltipParts.append("🎵 助眠白噪音播放中 (\(model.sleepAmbientSoundType.displayName))")
        }

        if !model.scheduledActions.isEmpty {
            let enabledCount = model.scheduledActions.filter(\.enabled).count
            let pausedCount = model.scheduledActions.count - enabledCount
            if pausedCount == 0 {
                tooltipParts.append("⏱ 计划调度: \(enabledCount) 个定时/倒计时任务生效中")
            } else if enabledCount == 0 {
                tooltipParts.append("⏱ 计划调度: \(pausedCount) 个定时任务已全部暂停")
            } else {
                tooltipParts.append("⏱ 计划调度: \(enabledCount) 个生效中 · \(pausedCount) 个已暂停")
            }
        }

        let lowCleanDevices = allDevices.compactMap { dev -> (name: String, pct: Int)? in
            let pct = model.filterCleanlinessPercentage(for: dev.id)
            return pct <= 30 ? (dev.name, pct) : nil
        }
        if !lowCleanDevices.isEmpty {
            if lowCleanDevices.count == 1, let item = lowCleanDevices.first {
                tooltipParts.append("⚠️ 「\(item.name)」滤网洁净度较低 (\(item.pct)%)，建议拆洗保养")
            } else {
                let summary = lowCleanDevices.map { "「\($0.name)」\($0.pct)%" }.joined(separator: "、")
                tooltipParts.append("⚠️ 全屋 \(lowCleanDevices.count) 台空调滤网洁净度较低（\(summary)），建议拆洗保养")
            }
        } else if !allDevices.isEmpty {
            tooltipParts.append("✨ 全屋空调滤网状态良好")
        }

        tooltipParts.append("💡 左键呼出快捷控制面板，右键展开系统菜单")
        button.toolTip = tooltipParts.joined(separator: "\n")
    }

    private func formatDisplayWindSpeed(_ raw: String?) -> String {
        guard let raw = raw?.lowercased() else { return "自动风" }
        if raw.contains("强") || raw.contains("turbo") || raw.contains("超强") || raw.contains("最大") ||
           raw.contains("3档") || raw.contains("三档") || raw == "3" || raw.contains("极速") { return "强劲风" }
        if raw.contains("高") || raw.contains("high") || raw.contains("大风") || raw.contains("大") || raw.contains("高速") { return "高风" }
        if raw.contains("中") || raw.contains("medium") || raw.contains("mid") ||
           raw.contains("2档") || raw.contains("二档") || raw.contains("两档") || raw == "2" || raw.contains("中速") { return "中风" }
        if raw.contains("低") || raw.contains("low") ||
           raw.contains("1档") || raw.contains("一档") || raw == "1" || raw.contains("小风") || raw.contains("低速") { return "低风" }
        if raw.contains("微") || raw.contains("静") || raw.contains("quiet") || raw.contains("mute") || raw.contains("micro") || raw.contains("柔") { return "微风" }
        return "自动风"
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    /// 左键：开/关迷你面板
    private func togglePanel() {
        guard let button = statusItem?.button else { return }
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPanel(relativeTo: button)
        }
    }

    private var lastAppliedColorScheme: ColorScheme?

    private func showPanel(relativeTo button: NSButton) {
        let currentScheme = model.themeMode.colorScheme
        let popover: NSPopover
        if let existing = self.popover {
            popover = existing
            // 只有当主题方案发生变化时才更新 rootView，避免不必要地销毁重建视图树丢失状态
            if lastAppliedColorScheme != currentScheme,
               let host = popover.contentViewController as? NSHostingController<AnyView> {
                lastAppliedColorScheme = currentScheme
                host.rootView = AnyView(
                    MenuBarControlsView()
                        .environmentObject(model)
                        .preferredColorScheme(currentScheme)
                )
            }
        } else {
            popover = NSPopover()
            popover.behavior = .transient  // 点击外部自动关闭；关闭时销毁，无幽灵窗口
            popover.animates = true
            lastAppliedColorScheme = currentScheme
            let host = NSHostingController(
                rootView: AnyView(
                    MenuBarControlsView()
                        .environmentObject(model)
                        .preferredColorScheme(currentScheme)
                )
            )
            popover.contentViewController = host
            self.popover = popover
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window {
            window.isOpaque = false
            window.backgroundColor = .clear
        }
    }

    /// 右键：上下文菜单（打开主窗口 / 助眠白噪音 / 滤网自清洁 / 开机自启 / 主题 / 退出）
    private func showContextMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let voiceItem = NSMenuItem(title: "语音控制... (⌃⌥A)", action: #selector(openVoiceControl), keyEquivalent: "")
        voiceItem.target = self
        menu.addItem(voiceItem)

        let allDevices = model.allUnifiedDevices
        let onDevices = allDevices.filter { dev in
            model.reachability(for: dev.id).isControllable &&
            model.attribute("onOffStatus", deviceId: dev.id)?.boolValue == true
        }
        let offDevices = allDevices.filter { dev in
            model.reachability(for: dev.id).isControllable &&
            model.attribute("onOffStatus", deviceId: dev.id)?.boolValue != true
        }

        if allDevices.count > 1 {
            // 多设备场景：提供全屋快捷协同操作 (v1.9.30, v1.9.32 增强制热与可达性门禁, v1.9.34 增加全屋纯开机保持预设, v1.9.38 显示在线台数)
            let controllableDevices = allDevices.filter { model.reachability(for: $0.id).isControllable }
            let hasControllable = model.gatewayConnected && !controllableDevices.isEmpty
            let countDesc = !controllableDevices.isEmpty ? " (\(controllableDevices.count)台在线)" : ""

            let coolAllItem = NSMenuItem(title: "❄️ 全屋清爽制冷 26°C\(countDesc)", action: #selector(applyQuickCoolingAll), keyEquivalent: "")
            coolAllItem.target = self
            coolAllItem.isEnabled = hasControllable
            menu.addItem(coolAllItem)

            let heatAllItem = NSMenuItem(title: "🔥 全屋舒适制热 20°C\(countDesc)", action: #selector(applyQuickHeatingAll), keyEquivalent: "")
            heatAllItem.target = self
            heatAllItem.isEnabled = hasControllable
            menu.addItem(heatAllItem)

            let dehumAllItem = NSMenuItem(title: "💧 全屋舒爽除湿\(countDesc)", action: #selector(applyQuickDehumidifyAll), keyEquivalent: "")
            dehumAllItem.target = self
            dehumAllItem.isEnabled = hasControllable
            menu.addItem(dehumAllItem)

            let fanAllItem = NSMenuItem(title: "🍃 全屋清新送风\(countDesc)", action: #selector(applyQuickFanAll), keyEquivalent: "")
            fanAllItem.target = self
            fanAllItem.isEnabled = hasControllable
            menu.addItem(fanAllItem)

            let autoAllItem = NSMenuItem(title: "🔄 全屋智能自动 24°C\(countDesc)", action: #selector(applyQuickAutoAll), keyEquivalent: "")
            autoAllItem.target = self
            autoAllItem.isEnabled = hasControllable
            menu.addItem(autoAllItem)

            // 全屋统一相对调温 (v1.9.35, v1.9.36 闭环 CR P2-3 增设 16/30°C 极值边界判定, v1.9.42 补齐运行台数精准反馈, v1.9.52 增加 0.5°C 高精微调矩阵, v1.9.54 全景感知当前基准温阶)
            let allTemps = onDevices.compactMap { model.attribute("targetTemperature", deviceId: $0.id)?.doubleValue }
            let allTempsDesc: String = {
                guard !allTemps.isEmpty else { return "" }
                let minT = allTemps.min()!
                let maxT = allTemps.max()!
                let minStr = minT.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(minT))" : String(format: "%.1f", minT)
                if minT == maxT {
                    return " · 均设 \(minStr)°C"
                } else {
                    let maxStr = maxT.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(maxT))" : String(format: "%.1f", maxT)
                    return " · 当前 \(minStr)~\(maxStr)°C"
                }
            }()
            let runningCountDesc = !onDevices.isEmpty ? " (\(onDevices.count)台运行中\(allTempsDesc))" : " (当前均未开机)"
            let canStepUpAll = model.gatewayConnected && onDevices.contains { dev in
                let curTemp = model.attribute("targetTemperature", deviceId: dev.id)?.doubleValue ?? 26.0
                return curTemp < 30.0
            }
            let stepUpAllItem = NSMenuItem(title: "🔼 全屋统一升温 1°C\(runningCountDesc)", action: #selector(stepUpAllTemperature), keyEquivalent: "")
            stepUpAllItem.target = self
            stepUpAllItem.isEnabled = canStepUpAll
            menu.addItem(stepUpAllItem)

            let canStepUpHalfAll = model.gatewayConnected && onDevices.contains { dev in
                let curTemp = model.attribute("targetTemperature", deviceId: dev.id)?.doubleValue ?? 26.0
                return curTemp <= 29.5
            }
            let stepUpHalfAllItem = NSMenuItem(title: "🔼 全屋微调升温 0.5°C\(runningCountDesc)", action: #selector(stepUpHalfAllTemperature), keyEquivalent: "")
            stepUpHalfAllItem.target = self
            stepUpHalfAllItem.isEnabled = canStepUpHalfAll
            menu.addItem(stepUpHalfAllItem)

            let canStepDownHalfAll = model.gatewayConnected && onDevices.contains { dev in
                let curTemp = model.attribute("targetTemperature", deviceId: dev.id)?.doubleValue ?? 26.0
                return curTemp >= 16.5
            }
            let stepDownHalfAllItem = NSMenuItem(title: "🔽 全屋微调降温 0.5°C\(runningCountDesc)", action: #selector(stepDownHalfAllTemperature), keyEquivalent: "")
            stepDownHalfAllItem.target = self
            stepDownHalfAllItem.isEnabled = canStepDownHalfAll
            menu.addItem(stepDownHalfAllItem)

            let canStepDownAll = model.gatewayConnected && onDevices.contains { dev in
                let curTemp = model.attribute("targetTemperature", deviceId: dev.id)?.doubleValue ?? 26.0
                return curTemp > 16.0
            }
            let stepDownAllItem = NSMenuItem(title: "🔽 全屋统一降温 1°C\(runningCountDesc)", action: #selector(stepDownAllTemperature), keyEquivalent: "")
            stepDownAllItem.target = self
            stepDownAllItem.isEnabled = canStepDownAll
            menu.addItem(stepDownAllItem)

            // 全屋统一风速协同 (v1.9.46, v1.9.47 增加运行台数动态感知与全屋协同一致性勾选反馈)
            let windMenu = NSMenu()
            windMenu.autoenablesItems = false
            let windLevels: [(val: String, title: String)] = [
                ("微风", "🍃 微风 (静音舒适)"),
                ("中风", "🍃 中风 (适中循环)"),
                ("强劲", "🍃 强劲 (极速对流)"),
                ("自动", "🔄 自动风速")
            ]
            let allOnSameSpeed: String? = {
                guard !onDevices.isEmpty else { return nil }
                let speeds = Set(onDevices.map { dev -> String in
                    let raw = model.attribute("windSpeed", deviceId: dev.id)?.stringValue ?? "微风"
                    if raw.contains("微") || raw.contains("低") || raw.contains("静") || raw.contains("1") { return "微风" }
                    if raw.contains("中") || raw.contains("2") { return "中风" }
                    if raw.contains("强") || raw.contains("高") || raw.contains("大") || raw.contains("3") { return "强劲" }
                    return "自动"
                })
                return speeds.count == 1 ? speeds.first : nil
            }()

            for itemDef in windLevels {
                let isSelected = (allOnSameSpeed == itemDef.val)
                let check = isSelected ? "✓ " : ""
                let item = NSMenuItem(title: "\(check)\(itemDef.title)", action: #selector(setAllWindSpeedFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = itemDef.val
                item.isEnabled = hasControllable
                windMenu.addItem(item)
            }
            let windParentItem = NSMenuItem(title: "🍃 全屋风速协同\(runningCountDesc)...", action: nil, keyEquivalent: "")
            menu.setSubmenu(windMenu, for: windParentItem)
            menu.addItem(windParentItem)

            if !offDevices.isEmpty {
                let turnOnAllItem = NSMenuItem(title: "⏻ 开启全屋空调 (\(offDevices.count) 台待机)", action: #selector(turnOnAllDevices), keyEquivalent: "")
                turnOnAllItem.target = self
                turnOnAllItem.isEnabled = model.gatewayConnected && !offDevices.isEmpty
                menu.addItem(turnOnAllItem)
            }

            if !onDevices.isEmpty {
                let turnOffAllItem = NSMenuItem(title: "⏻ 关闭全屋空调 (\(onDevices.count) 台运行中)", action: #selector(turnOffAllDevices), keyEquivalent: "")
                turnOffAllItem.target = self
                turnOffAllItem.isEnabled = model.gatewayConnected && !onDevices.isEmpty
                menu.addItem(turnOffAllItem)
            }

            // 多设备级联控制子菜单 (v1.9.28, v1.9.35 增设微调温阶)
            let devicesMenu = NSMenu()
            devicesMenu.autoenablesItems = false
            for dev in allDevices {
                let devId = dev.id
                let isPowerOn = model.attribute("onOffStatus", deviceId: devId)?.boolValue ?? false
                let reach = model.reachability(for: devId)
                let isControllable = reach.isControllable
                let curTemp = model.attribute("targetTemperature", deviceId: devId)?.doubleValue ?? 26.0
                let curTempStr = curTemp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(curTemp))" : String(format: "%.1f", curTemp)
                let rawMode = model.attribute("operationMode", deviceId: devId)?.stringValue
                let modeCode = ACModeCode.match(from: rawMode)

                let devSubmenu = NSMenu()
                devSubmenu.autoenablesItems = false

                // 实时运行工况与温湿度感知信息标头 (v1.9.51 达成多设备矩阵与单设备上下文菜单严格对称)
                let devIndoorTemp = model.currentIndoorTemperature(for: devId)
                let devIndoorHum = model.currentIndoorHumidity(for: devId)
                let devRawWind = model.attribute("windSpeed", deviceId: devId)?.stringValue
                let devWindStr = formatDisplayWindSpeed(devRawWind)
                let devConditionTitle: String = {
                    let envStr: String = {
                        if let t = devIndoorTemp {
                            let tStr = t.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(t))°C" : String(format: "%.1f°C", t)
                            if let h = devIndoorHum {
                                return " (室内 \(tStr) · \(Int(round(h)))% RH)"
                            } else {
                                return " (室内 \(tStr))"
                            }
                        } else if let h = devIndoorHum {
                            return " (室内 \(Int(round(h)))% RH)"
                        }
                        return ""
                    }()
                    if !isControllable {
                        return "⚡️ \(dev.name): 离线\(envStr)"
                    }
                    if isPowerOn {
                        let modeStr: String = {
                            if let modeCode = modeCode {
                                switch modeCode {
                                case .cooling: return "❄️ 制冷"
                                case .heating: return "🔥 制热"
                                case .fan: return "🍃 送风"
                                case .dehumidify: return "💧 除湿"
                                case .auto: return "🔄 自动"
                                }
                            }
                            return "⚙️ 运行中"
                        }()
                        return "🟢 \(dev.name): \(modeStr) \(curTempStr)°C [\(devWindStr)]\(envStr)"
                    } else {
                        return "⚪️ \(dev.name): 待机\(envStr)"
                    }
                }()
                let headerItem = NSMenuItem(title: devConditionTitle, action: nil, keyEquivalent: "")
                headerItem.isEnabled = false
                devSubmenu.addItem(headerItem)
                devSubmenu.addItem(.separator())

                // 设为菜单栏主显设备 (v1.9.39)
                let isPrimary = (devId == primaryDeviceId)
                let pinTitle = isPrimary ? "✓ 菜单栏常驻主显中" : "★ 设为菜单栏主显设备"
                let pinItem = NSMenuItem(
                    title: pinTitle,
                    action: #selector(setPrimaryDeviceFromMenu(_:)),
                    keyEquivalent: ""
                )
                pinItem.target = self
                pinItem.representedObject = devId
                pinItem.isEnabled = !isPrimary
                devSubmenu.addItem(pinItem)
                devSubmenu.addItem(.separator())

                // 开关机切换
                let togglePowerItem = NSMenuItem(
                    title: isPowerOn ? "关机" : "开机",
                    action: #selector(toggleDevicePower(_:)),
                    keyEquivalent: ""
                )
                togglePowerItem.target = self
                togglePowerItem.representedObject = devId
                togglePowerItem.isEnabled = isControllable
                devSubmenu.addItem(togglePowerItem)

                // 一键制冷 26°C
                let coolItem = NSMenuItem(
                    title: "❄️ 一键制冷 26°C",
                    action: #selector(setQuickCooling(_:)),
                    keyEquivalent: ""
                )
                coolItem.target = self
                coolItem.representedObject = devId
                coolItem.isEnabled = isControllable
                devSubmenu.addItem(coolItem)

                // 一键制热 20°C
                let heatItem = NSMenuItem(
                    title: "🔥 一键制热 20°C",
                    action: #selector(setQuickHeating(_:)),
                    keyEquivalent: ""
                )
                heatItem.target = self
                heatItem.representedObject = devId
                heatItem.isEnabled = isControllable
                devSubmenu.addItem(heatItem)

                // 一键除湿 (v1.9.36)
                let dehumItem = NSMenuItem(
                    title: "💧 一键除湿",
                    action: #selector(setQuickDehumidify(_:)),
                    keyEquivalent: ""
                )
                dehumItem.target = self
                dehumItem.representedObject = devId
                dehumItem.isEnabled = isControllable
                devSubmenu.addItem(dehumItem)

                // 一键送风 (v1.9.36)
                let fanItem = NSMenuItem(
                    title: "🍃 一键送风",
                    action: #selector(setQuickFan(_:)),
                    keyEquivalent: ""
                )
                fanItem.target = self
                fanItem.representedObject = devId
                fanItem.isEnabled = isControllable
                devSubmenu.addItem(fanItem)

                // 一键智能自动 24°C (v1.9.40)
                let autoItem = NSMenuItem(
                    title: "🔄 一键智能自动 24°C",
                    action: #selector(setQuickAuto(_:)),
                    keyEquivalent: ""
                )
                autoItem.target = self
                autoItem.representedObject = devId
                autoItem.isEnabled = isControllable
                devSubmenu.addItem(autoItem)

                // 升降温与微调温阶 (v1.9.35, v1.9.52 增加 0.5°C 高精微调矩阵)
                let upItem = NSMenuItem(
                    title: "🔼 升温 1°C (当前 \(curTempStr)°C)",
                    action: #selector(stepUpDeviceTemperature(_:)),
                    keyEquivalent: ""
                )
                upItem.target = self
                upItem.representedObject = devId
                upItem.isEnabled = isControllable && isPowerOn && curTemp < 30.0
                devSubmenu.addItem(upItem)

                let upHalfItem = NSMenuItem(
                    title: "🔼 升温 0.5°C (高精微调 · 当前 \(curTempStr)°C)",
                    action: #selector(stepUpHalfDeviceTemperature(_:)),
                    keyEquivalent: ""
                )
                upHalfItem.target = self
                upHalfItem.representedObject = devId
                upHalfItem.isEnabled = isControllable && isPowerOn && curTemp <= 29.5
                devSubmenu.addItem(upHalfItem)

                let downHalfItem = NSMenuItem(
                    title: "🔽 降温 0.5°C (高精微调 · 当前 \(curTempStr)°C)",
                    action: #selector(stepDownHalfDeviceTemperature(_:)),
                    keyEquivalent: ""
                )
                downHalfItem.target = self
                downHalfItem.representedObject = devId
                downHalfItem.isEnabled = isControllable && isPowerOn && curTemp >= 16.5
                devSubmenu.addItem(downHalfItem)

                let downItem = NSMenuItem(
                    title: "🔽 降温 1°C (当前 \(curTempStr)°C)",
                    action: #selector(stepDownDeviceTemperature(_:)),
                    keyEquivalent: ""
                )
                downItem.target = self
                downItem.representedObject = devId
                downItem.isEnabled = isControllable && isPowerOn && curTemp > 16.0
                devSubmenu.addItem(downItem)

                // 调节风速 (v1.9.46)
                let curWind = model.attribute("windSpeed", deviceId: devId)?.stringValue ?? "微风"
                let devWindMenu = NSMenu()
                devWindMenu.autoenablesItems = false
                for itemDef in windLevels {
                    let isSelected = curWind.contains(itemDef.val) || (itemDef.val == "强劲" && (curWind.contains("强") || curWind.contains("高")))
                    let check = isSelected ? "✓ " : ""
                    let item = NSMenuItem(title: "\(check)\(itemDef.title)", action: #selector(setDeviceWindSpeedFromMenu(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = ["deviceId": devId, "speed": itemDef.val]
                    item.isEnabled = isControllable
                    devWindMenu.addItem(item)
                }
                let devWindParentItem = NSMenuItem(title: "🍃 调节风速 (当前: \(curWind))", action: nil, keyEquivalent: "")
                devSubmenu.setSubmenu(devWindMenu, for: devWindParentItem)
                devSubmenu.addItem(devWindParentItem)

                // 滤网洁净度与快速重置 (v1.9.45)
                let filterPct = model.filterCleanlinessPercentage(for: devId)
                let filterStatus = filterPct <= 20 ? "⚠️ 需拆洗" : "良好"
                let resetFilterItem = NSMenuItem(
                    title: "🧼 重置滤网计时 (当前 \(filterPct)%，\(filterStatus))",
                    action: #selector(resetDeviceFilterFromMenu(_:)),
                    keyEquivalent: ""
                )
                resetFilterItem.target = self
                resetFilterItem.representedObject = devId
                devSubmenu.addItem(resetFilterItem)

                // 单设备快捷倒计时调度 (v1.9.57)
                let devCountdownMenu = NSMenu()
                devCountdownMenu.autoenablesItems = false
                let devCountdownPresets: [(title: String, mins: Int, powerOn: Bool)] = [
                    ("⏱ 30 分钟后关机", 30, false),
                    ("⏱ 1 小时后关机", 60, false),
                    ("⏱ 2 小时后关机", 120, false),
                    ("⏱ 晨间过渡关机 (45分钟)", 45, false),
                    ("❄️ 30 分钟后开机预冷/预热", 30, true),
                    ("❄️ 1 小时后开机预冷/预热", 60, true)
                ]
                for p in devCountdownPresets {
                    let pItem = NSMenuItem(title: p.title, action: #selector(quickCountdownFromMenu(_:)), keyEquivalent: "")
                    pItem.target = self
                    pItem.representedObject = ["deviceId": devId, "minutes": p.mins, "powerOn": p.powerOn] as [String: Any]
                    pItem.isEnabled = isControllable
                    devCountdownMenu.addItem(pItem)
                }
                let devCountdownParent = NSMenuItem(title: "⏱ 快捷倒计时...", action: nil, keyEquivalent: "")
                devSubmenu.setSubmenu(devCountdownMenu, for: devCountdownParent)
                devSubmenu.addItem(devCountdownParent)

                // 单设备计划调度全生命周期管理与感知矩阵 (v1.9.61)
                let devSchedules = model.scheduledActions.filter { $0.deviceId == devId }
                let devScheduleMenu = NSMenu()
                devScheduleMenu.autoenablesItems = false
                let devEnabledCount = devSchedules.filter(\.enabled).count
                let devPausedCount = devSchedules.count - devEnabledCount

                if !devSchedules.isEmpty {
                    for action in devSchedules {
                        let timeStr = DateFormatter.localizedString(from: action.fireDate, dateStyle: .none, timeStyle: .short)
                        let actionVerb = Self.extractPlanActionVerb(from: action, devName: dev.name)
                        let repeatTag = action.repeatLabel.map { " [\($0)]" } ?? ""
                        let statusTag = action.enabled ? "" : " [已暂停]"
                        let remainingDesc = action.enabled ? "，\(Self.formatRemainingTime(fireDate: action.fireDate))" : ""
                        let sItem = NSMenuItem(title: "⏱ \(actionVerb) (\(timeStr)\(remainingDesc))\(repeatTag)\(statusTag)", action: nil, keyEquivalent: "")

                        let singleMenu = NSMenu()
                        singleMenu.autoenablesItems = false
                        let fullTimeStr = DateFormatter.localizedString(from: action.fireDate, dateStyle: .medium, timeStyle: .medium)
                        let remInfo = action.enabled ? " (\(Self.formatRemainingTime(fireDate: action.fireDate)))" : ""
                        let timeInfo = NSMenuItem(title: "下次执行: \(fullTimeStr)\(remInfo)", action: nil, keyEquivalent: "")
                        timeInfo.isEnabled = false
                        singleMenu.addItem(timeInfo)

                        if let rep = action.repeatLabel {
                            let repInfo = NSMenuItem(title: "周期重复: \(rep)", action: nil, keyEquivalent: "")
                            repInfo.isEnabled = false
                            singleMenu.addItem(repInfo)
                        }
                        singleMenu.addItem(.separator())

                        let toggleTitle = action.enabled ? "⏸ 暂停此任务" : "▶️ 恢复此任务"
                        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleSingleScheduleEnabledFromMenu(_:)), keyEquivalent: "")
                        toggleItem.target = self
                        toggleItem.representedObject = action.id.uuidString
                        singleMenu.addItem(toggleItem)

                        let cancelItem = NSMenuItem(title: "❌ 取消该任务", action: #selector(cancelSingleScheduleFromMenu(_:)), keyEquivalent: "")
                        cancelItem.target = self
                        cancelItem.representedObject = action.id.uuidString
                        singleMenu.addItem(cancelItem)

                        devScheduleMenu.setSubmenu(singleMenu, for: sItem)
                        devScheduleMenu.addItem(sItem)
                    }
                    devScheduleMenu.addItem(.separator())

                    if devEnabledCount > 0 {
                        let pItem = NSMenuItem(title: "⏸ 暂停该设备所有定时", action: #selector(pauseDeviceSchedulesFromMenu(_:)), keyEquivalent: "")
                        pItem.target = self
                        pItem.representedObject = devId
                        devScheduleMenu.addItem(pItem)
                    }
                    if devPausedCount > 0 {
                        let rItem = NSMenuItem(title: "▶️ 恢复该设备所有定时", action: #selector(resumeDeviceSchedulesFromMenu(_:)), keyEquivalent: "")
                        rItem.target = self
                        rItem.representedObject = devId
                        devScheduleMenu.addItem(rItem)
                    }
                    let cItem = NSMenuItem(title: "🗑 取消该设备所有定时与倒计时", action: #selector(cancelDeviceSchedulesFromMenu(_:)), keyEquivalent: "")
                    cItem.target = self
                    cItem.representedObject = devId
                    devScheduleMenu.addItem(cItem)
                } else {
                    let emptyItem = NSMenuItem(title: "当前无生效中的计划任务", action: nil, keyEquivalent: "")
                    emptyItem.isEnabled = false
                    devScheduleMenu.addItem(emptyItem)
                }

                let devScheduleParentTitle: String
                if devSchedules.isEmpty {
                    devScheduleParentTitle = "⏱ 计划调度 (无任务)..."
                } else if devPausedCount == 0 {
                    devScheduleParentTitle = "⏱ 计划调度 (\(devEnabledCount) 项生效)..."
                } else if devEnabledCount == 0 {
                    devScheduleParentTitle = "⏱ 计划调度 (\(devPausedCount) 项已暂停)..."
                } else {
                    devScheduleParentTitle = "⏱ 计划调度 (\(devEnabledCount) 生效 / \(devPausedCount) 暂停)..."
                }
                let devScheduleParent = NSMenuItem(title: devScheduleParentTitle, action: nil, keyEquivalent: "")
                devSubmenu.setSubmenu(devScheduleMenu, for: devScheduleParent)
                devSubmenu.addItem(devScheduleParent)

                let statusBadge: String
                switch reach {
                case .gatewayReconnecting: statusBadge = "⏳ 重连中"
                case .deviceOffline: statusBadge = "⚡️ 离线"
                case .available:
                    if isPowerOn {
                        let modeStr: String = {
                            if let code = modeCode {
                                switch code {
                                case .cooling: return "制冷"
                                case .heating: return "制热"
                                case .fan: return "送风"
                                case .dehumidify: return "除湿"
                                case .auto: return "自动"
                                }
                            }
                            return "运行中"
                        }()
                        if modeCode == .fan {
                            statusBadge = "🟢 \(modeStr)"
                        } else {
                            statusBadge = "🟢 \(modeStr) \(curTempStr)°C"
                        }
                    } else {
                        statusBadge = "⚪️ 待机"
                    }
                }

                let pinBadge = isPrimary ? "★ " : ""
                let devItem = NSMenuItem(title: "\(pinBadge)\(dev.name) (\(statusBadge))", action: nil, keyEquivalent: "")
                devicesMenu.setSubmenu(devSubmenu, for: devItem)
                devicesMenu.addItem(devItem)
            }

            let matrixRunningDesc = !onDevices.isEmpty ? "\(onDevices.count)台运行中" : "全屋待机"
            let devicesParentItem = NSMenuItem(title: "空调设备控制矩阵 (\(controllableDevices.count)台在线，\(matrixRunningDesc))...", action: nil, keyEquivalent: "")
            menu.setSubmenu(devicesMenu, for: devicesParentItem)
            menu.addItem(devicesParentItem)
        } else if let dev = allDevices.first {
            // 单设备场景：当前运行工况感知信息标头与控制预设 (v1.9.33, v1.9.35, v1.9.36 补齐除湿送风, v1.9.50 增设当前运行工况与室内温感知状态标头)
            let isPowerOn = model.attribute("onOffStatus", deviceId: dev.id)?.boolValue ?? false
            let isControllable = model.reachability(for: dev.id).isControllable
            let curTemp = model.attribute("targetTemperature", deviceId: dev.id)?.doubleValue ?? 26.0
            let curTempStr = curTemp.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(curTemp))" : String(format: "%.1f", curTemp)
            let indoorTemp = model.currentIndoorTemperature(for: dev.id)
            let rawMode = model.attribute("operationMode", deviceId: dev.id)?.stringValue
            let modeCode = ACModeCode.match(from: rawMode)
            let rawWind = model.attribute("windSpeed", deviceId: dev.id)?.stringValue
            let windStr = formatDisplayWindSpeed(rawWind)

            let indoorHum = model.currentIndoorHumidity(for: dev.id)
            let conditionTitle: String = {
                let envStr: String = {
                    if let indoor = indoorTemp {
                        let s = indoor.truncatingRemainder(dividingBy: 1.0) == 0 ? "\(Int(indoor))°C" : String(format: "%.1f°C", indoor)
                        if let h = indoorHum {
                            return " (室内 \(s) · \(Int(round(h)))% RH)"
                        } else {
                            return " (室内 \(s))"
                        }
                    } else if let h = indoorHum {
                        return " (室内 \(Int(round(h)))% RH)"
                    }
                    return ""
                }()
                if !isControllable {
                    return "⚡️ \(dev.name): 离线\(envStr)"
                }
                if isPowerOn {
                    let modeStr: String = {
                        if let modeCode = modeCode {
                            switch modeCode {
                            case .cooling: return "❄️ 制冷"
                            case .heating: return "🔥 制热"
                            case .fan: return "🍃 送风"
                            case .dehumidify: return "💧 除湿"
                            case .auto: return "🔄 自动"
                            }
                        }
                        return "⚙️ 运行中"
                    }()
                    return "🟢 \(dev.name): \(modeStr) \(curTempStr)°C [\(windStr)]\(envStr)"
                } else {
                    return "⚪️ \(dev.name): 待机\(envStr)"
                }
            }()
            let headerItem = NSMenuItem(title: conditionTitle, action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            menu.addItem(.separator())

            let powerTitle = isPowerOn ? "关机「\(dev.name)」" : "开机「\(dev.name)」"
            let powerItem = NSMenuItem(title: powerTitle, action: #selector(togglePrimaryPower), keyEquivalent: "")
            powerItem.target = self
            powerItem.isEnabled = isControllable
            menu.addItem(powerItem)

            let coolItem = NSMenuItem(title: "❄️ 一键制冷 26°C", action: #selector(applyQuickCoolingPrimary), keyEquivalent: "")
            coolItem.target = self
            coolItem.isEnabled = isControllable
            menu.addItem(coolItem)

            let heatItem = NSMenuItem(title: "🔥 一键制热 20°C", action: #selector(applyQuickHeatingPrimary), keyEquivalent: "")
            heatItem.target = self
            heatItem.isEnabled = isControllable
            menu.addItem(heatItem)

            let dehumItem = NSMenuItem(title: "💧 一键除湿", action: #selector(applyQuickDehumidifyPrimary), keyEquivalent: "")
            dehumItem.target = self
            dehumItem.isEnabled = isControllable
            menu.addItem(dehumItem)

            let fanItem = NSMenuItem(title: "🍃 一键送风", action: #selector(applyQuickFanPrimary), keyEquivalent: "")
            fanItem.target = self
            fanItem.isEnabled = isControllable
            menu.addItem(fanItem)

            let autoItem = NSMenuItem(title: "🔄 一键智能自动 24°C", action: #selector(applyQuickAutoPrimary), keyEquivalent: "")
            autoItem.target = self
            autoItem.isEnabled = isControllable
            menu.addItem(autoItem)

            let stepUpItem = NSMenuItem(title: "🔼 升温 1°C (当前 \(curTempStr)°C)", action: #selector(stepUpPrimaryTemperature), keyEquivalent: "")
            stepUpItem.target = self
            stepUpItem.isEnabled = isControllable && isPowerOn && curTemp < 30.0
            menu.addItem(stepUpItem)

            let stepUpHalfItem = NSMenuItem(title: "🔼 升温 0.5°C (高精微调 · 当前 \(curTempStr)°C)", action: #selector(stepUpHalfPrimaryTemperature), keyEquivalent: "")
            stepUpHalfItem.target = self
            stepUpHalfItem.isEnabled = isControllable && isPowerOn && curTemp <= 29.5
            menu.addItem(stepUpHalfItem)

            let stepDownHalfItem = NSMenuItem(title: "🔽 降温 0.5°C (高精微调 · 当前 \(curTempStr)°C)", action: #selector(stepDownHalfPrimaryTemperature), keyEquivalent: "")
            stepDownHalfItem.target = self
            stepDownHalfItem.isEnabled = isControllable && isPowerOn && curTemp >= 16.5
            menu.addItem(stepDownHalfItem)

            let stepDownItem = NSMenuItem(title: "🔽 降温 1°C (当前 \(curTempStr)°C)", action: #selector(stepDownPrimaryTemperature), keyEquivalent: "")
            stepDownItem.target = self
            stepDownItem.isEnabled = isControllable && isPowerOn && curTemp > 16.0
            menu.addItem(stepDownItem)

            // 调节风速 (v1.9.46)
            let curWind = model.attribute("windSpeed", deviceId: dev.id)?.stringValue ?? "微风"
            let singleWindLevels: [(val: String, title: String)] = [
                ("微风", "🍃 微风 (静音舒适)"),
                ("中风", "🍃 中风 (适中循环)"),
                ("强劲", "🍃 强劲 (极速对流)"),
                ("自动", "🔄 自动风速")
            ]
            let singleWindMenu = NSMenu()
            singleWindMenu.autoenablesItems = false
            for itemDef in singleWindLevels {
                let isSelected = curWind.contains(itemDef.val) || (itemDef.val == "强劲" && (curWind.contains("强") || curWind.contains("高")))
                let check = isSelected ? "✓ " : ""
                let item = NSMenuItem(title: "\(check)\(itemDef.title)", action: #selector(setPrimaryWindSpeedFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = itemDef.val
                item.isEnabled = isControllable
                singleWindMenu.addItem(item)
            }
            let singleWindItem = NSMenuItem(title: "🍃 调节风速 (当前: \(curWind))", action: nil, keyEquivalent: "")
            menu.setSubmenu(singleWindMenu, for: singleWindItem)
            menu.addItem(singleWindItem)

            // 滤网洁净度与快速重置 (v1.9.63 单设备与多设备矩阵全景对称)
            let filterPct = model.filterCleanlinessPercentage(for: dev.id)
            let filterStatus = filterPct <= 20 ? "⚠️ 需拆洗" : "良好"
            let singleResetFilterItem = NSMenuItem(
                title: "🧼 重置滤网计时 (当前 \(filterPct)%，\(filterStatus))",
                action: #selector(resetDeviceFilterFromMenu(_:)),
                keyEquivalent: ""
            )
            singleResetFilterItem.target = self
            singleResetFilterItem.representedObject = dev.id
            menu.addItem(singleResetFilterItem)

            // 单设备快捷倒计时调度 (v1.9.62 单设备与多设备矩阵全景对称)
            let singleCountdownMenu = NSMenu()
            singleCountdownMenu.autoenablesItems = false
            let singleCountdownPresets: [(title: String, mins: Int, powerOn: Bool)] = [
                ("⏱ 30 分钟后关机", 30, false),
                ("⏱ 1 小时后关机", 60, false),
                ("⏱ 2 小时后关机", 120, false),
                ("⏱ 晨间过渡关机 (45分钟)", 45, false),
                ("❄️ 30 分钟后开机预冷/预热", 30, true),
                ("❄️ 1 小时后开机预冷/预热", 60, true)
            ]
            for p in singleCountdownPresets {
                let pItem = NSMenuItem(title: p.title, action: #selector(quickCountdownFromMenu(_:)), keyEquivalent: "")
                pItem.target = self
                pItem.representedObject = ["deviceId": dev.id, "minutes": p.mins, "powerOn": p.powerOn] as [String: Any]
                pItem.isEnabled = isControllable
                singleCountdownMenu.addItem(pItem)
            }
            let singleCountdownParent = NSMenuItem(title: "⏱ 快捷倒计时...", action: nil, keyEquivalent: "")
            menu.setSubmenu(singleCountdownMenu, for: singleCountdownParent)
            menu.addItem(singleCountdownParent)

            // 单设备计划调度全生命周期管理与感知矩阵 (v1.9.62)
            let devSchedules = model.scheduledActions.filter { $0.deviceId == dev.id }
            let devScheduleMenu = NSMenu()
            devScheduleMenu.autoenablesItems = false
            let devEnabledCount = devSchedules.filter(\.enabled).count
            let devPausedCount = devSchedules.count - devEnabledCount

            if !devSchedules.isEmpty {
                for action in devSchedules {
                    let timeStr = DateFormatter.localizedString(from: action.fireDate, dateStyle: .none, timeStyle: .short)
                    let cleanActionName = Self.extractPlanActionVerb(from: action, devName: dev.name)
                    let repeatTag = action.repeatLabel.map { " [\($0)]" } ?? ""
                    let statusTag = action.enabled ? "" : " [已暂停]"
                    let remainingDesc = action.enabled ? "，\(Self.formatRemainingTime(fireDate: action.fireDate))" : ""
                    let sItem = NSMenuItem(title: "⏱ \(cleanActionName) (\(timeStr)\(remainingDesc))\(repeatTag)\(statusTag)", action: nil, keyEquivalent: "")

                    let singleMenu = NSMenu()
                    singleMenu.autoenablesItems = false
                    let fullTimeStr = DateFormatter.localizedString(from: action.fireDate, dateStyle: .medium, timeStyle: .medium)
                    let remInfo = action.enabled ? " (\(Self.formatRemainingTime(fireDate: action.fireDate)))" : ""
                    let timeInfo = NSMenuItem(title: "下次执行: \(fullTimeStr)\(remInfo)", action: nil, keyEquivalent: "")
                    timeInfo.isEnabled = false
                    singleMenu.addItem(timeInfo)

                    if let rep = action.repeatLabel {
                        let repInfo = NSMenuItem(title: "周期重复: \(rep)", action: nil, keyEquivalent: "")
                        repInfo.isEnabled = false
                        singleMenu.addItem(repInfo)
                    }
                    singleMenu.addItem(.separator())

                    let toggleTitle = action.enabled ? "⏸ 暂停此任务" : "▶️ 恢复此任务"
                    let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleSingleScheduleEnabledFromMenu(_:)), keyEquivalent: "")
                    toggleItem.target = self
                    toggleItem.representedObject = action.id.uuidString
                    singleMenu.addItem(toggleItem)

                    let cancelItem = NSMenuItem(title: "❌ 取消该任务", action: #selector(cancelSingleScheduleFromMenu(_:)), keyEquivalent: "")
                    cancelItem.target = self
                    cancelItem.representedObject = action.id.uuidString
                    singleMenu.addItem(cancelItem)

                    // 动态检测同频批次兄弟任务并提供一键协同管理 (v1.9.69, v1.9.70 升级无序集合与自然周期同频判定)
                    let siblingActions = model.scheduledActions.filter { StatusItemController.isSiblingSchedule($0, action) }
                    if siblingActions.count > 1 {
                        singleMenu.addItem(.separator())
                        let anySiblingEnabled = siblingActions.contains(where: \.enabled)
                        let syncToggleTitle = anySiblingEnabled ? "⏸ 同步暂停此批任务 (\(siblingActions.count) 台)" : "▶️ 同步恢复此批任务 (\(siblingActions.count) 台)"
                        let syncToggleItem = NSMenuItem(title: syncToggleTitle, action: #selector(toggleSiblingSchedulesFromMenu(_:)), keyEquivalent: "")
                        syncToggleItem.target = self
                        syncToggleItem.representedObject = siblingActions.map(\.id.uuidString)
                        singleMenu.addItem(syncToggleItem)

                        let syncCancelItem = NSMenuItem(title: "❌ 同步取消此批任务 (\(siblingActions.count) 台)", action: #selector(cancelSiblingSchedulesFromMenu(_:)), keyEquivalent: "")
                        syncCancelItem.target = self
                        syncCancelItem.representedObject = siblingActions.map(\.id.uuidString)
                        singleMenu.addItem(syncCancelItem)
                    }

                    devScheduleMenu.setSubmenu(singleMenu, for: sItem)
                    devScheduleMenu.addItem(sItem)
                }
                devScheduleMenu.addItem(.separator())

                if devEnabledCount > 0 {
                    let pItem = NSMenuItem(title: "⏸ 暂停该设备所有定时", action: #selector(pauseDeviceSchedulesFromMenu(_:)), keyEquivalent: "")
                    pItem.target = self
                    pItem.representedObject = dev.id
                    devScheduleMenu.addItem(pItem)
                }
                if devPausedCount > 0 {
                    let rItem = NSMenuItem(title: "▶️ 恢复该设备所有定时", action: #selector(resumeDeviceSchedulesFromMenu(_:)), keyEquivalent: "")
                    rItem.target = self
                    rItem.representedObject = dev.id
                    devScheduleMenu.addItem(rItem)
                }
                let cItem = NSMenuItem(title: "🗑 取消该设备所有定时与倒计时", action: #selector(cancelDeviceSchedulesFromMenu(_:)), keyEquivalent: "")
                cItem.target = self
                cItem.representedObject = dev.id
                devScheduleMenu.addItem(cItem)
            } else {
                let emptyItem = NSMenuItem(title: "当前无生效中的计划任务", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                devScheduleMenu.addItem(emptyItem)
            }

            let devScheduleParentTitle: String
            if devSchedules.isEmpty {
                devScheduleParentTitle = "⏱ 计划调度 (无任务)..."
            } else if devPausedCount == 0 {
                devScheduleParentTitle = "⏱ 计划调度 (\(devEnabledCount) 项生效)..."
            } else if devEnabledCount == 0 {
                devScheduleParentTitle = "⏱ 计划调度 (\(devPausedCount) 项已暂停)..."
            } else {
                devScheduleParentTitle = "⏱ 计划调度 (\(devEnabledCount) 生效 / \(devPausedCount) 暂停)..."
            }
            let devScheduleParentItem = NSMenuItem(title: devScheduleParentTitle, action: nil, keyEquivalent: "")
            menu.setSubmenu(devScheduleMenu, for: devScheduleParentItem)
            menu.addItem(devScheduleParentItem)
        }

        let openItem = NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        // 助眠白噪音快捷开关 (v1.9.21)
        let ambientTitle = AmbientSoundEngine.shared.isPlaying ?
            "助眠白噪音：\(model.sleepAmbientSoundType.displayName) (点击暂停)" :
            "助眠白噪音：已暂停 (点击播放)"
        let ambientItem = NSMenuItem(title: ambientTitle, action: #selector(toggleAmbientSound), keyEquivalent: "")
        ambientItem.target = self
        menu.addItem(ambientItem)

        // 滤网健康与自清洁快速入口 (v1.9.21, v1.9.37 多设备全屋最低洁净度预警, v1.9.45 快捷重置子菜单)
        let filterTitle: String = {
            if model.isSelfCleaningActive {
                return "56°C 自清洁进行中 (\(model.selfCleaningRemainingSeconds / 60)m\(model.selfCleaningRemainingSeconds % 60)s)..."
            }
            if allDevices.count > 1 {
                let minClean = allDevices.map { model.filterCleanlinessPercentage(for: $0.id) }.min() ?? model.filterCleanlinessPercentage
                let warn = minClean <= 30 ? "⚠️ " : ""
                return "\(warn)滤网保养与自清洁 (全屋最低 \(minClean)%)..."
            } else {
                let clean = model.filterCleanlinessPercentage
                let warn = clean <= 30 ? "⚠️ " : ""
                return "\(warn)滤网保养与自清洁 (洁净度 \(clean)%)..."
            }
        }()

        let filterMenu = NSMenu()
        filterMenu.autoenablesItems = false

        let openCareItem = NSMenuItem(title: "打开滤网保养与自清洁面板...", action: #selector(openFilterCare), keyEquivalent: "")
        openCareItem.target = self
        filterMenu.addItem(openCareItem)

        if allDevices.count > 1 {
            let resetAllFilterItem = NSMenuItem(title: "🧼 一键重置全屋滤网计时 (恢复100%)", action: #selector(resetAllFiltersFromMenu), keyEquivalent: "")
            resetAllFilterItem.target = self
            filterMenu.addItem(resetAllFilterItem)
        } else if let dev = allDevices.first {
            let resetItem = NSMenuItem(title: "🧼 重置「\(dev.name)」滤网计时 (恢复100%)", action: #selector(resetPrimaryFilterFromMenu), keyEquivalent: "")
            resetItem.target = self
            filterMenu.addItem(resetItem)
        }

        let filterParentItem = NSMenuItem(title: filterTitle, action: #selector(openFilterCare), keyEquivalent: "")
        filterParentItem.target = self
        menu.setSubmenu(filterMenu, for: filterParentItem)
        menu.addItem(filterParentItem)

        // 计划调度与定时任务感知 (多设备全屋调度矩阵，v1.9.63 单设备免去重置避免双重计划菜单)
        if allDevices.count > 1 {
        let activeSchedules = model.scheduledActions
        let scheduleMenu = NSMenu()
        scheduleMenu.autoenablesItems = false

        // 快捷倒计时独立子菜单 (v1.9.56, v1.9.57 增加全屋统一倒计时与开机预冷/预热倒计时, v1.9.64 明确主显设备归属消除歧义)
        let quickCountdownMenu = NSMenu()
        quickCountdownMenu.autoenablesItems = false

        let primaryDev = model.allUnifiedDevices.first(where: { $0.id == primaryDeviceId }) ?? model.allUnifiedDevices.first
        let primaryName = primaryDev?.name ?? "主显设备"
        let primaryId = primaryDev?.id

        let countdownPresets: [(title: String, mins: Int, powerOn: Bool)] = [
            ("⏱ 「\(primaryName)」30 分钟后关机", 30, false),
            ("⏱ 「\(primaryName)」1 小时后关机", 60, false),
            ("⏱ 「\(primaryName)」2 小时后关机", 120, false),
            ("⏱ 「\(primaryName)」晨间过渡关机 (45分钟)", 45, false),
            ("❄️ 「\(primaryName)」30 分钟后开机预冷/预热", 30, true),
            ("❄️ 「\(primaryName)」1 小时后开机预冷/预热", 60, true)
        ]
        for preset in countdownPresets {
            let pItem = NSMenuItem(title: preset.title, action: #selector(quickCountdownFromMenu(_:)), keyEquivalent: "")
            pItem.target = self
            var repObj: [String: Any] = ["minutes": preset.mins, "powerOn": preset.powerOn]
            if let primaryId {
                repObj["deviceId"] = primaryId
            }
            pItem.representedObject = repObj
            quickCountdownMenu.addItem(pItem)
        }

        quickCountdownMenu.addItem(.separator())
        let allOffPresets: [(title: String, mins: Int)] = [
            ("🏠 全屋 30 分钟后关机", 30),
            ("🏠 全屋 1 小时后关机", 60),
            ("🏠 全屋 2 小时后关机", 120)
        ]
        for p in allOffPresets {
            let pItem = NSMenuItem(title: p.title, action: #selector(quickCountdownFromMenu(_:)), keyEquivalent: "")
            pItem.target = self
            pItem.representedObject = ["minutes": p.mins, "powerOn": false, "all": true] as [String: Any]
            quickCountdownMenu.addItem(pItem)
        }
        let allOnPresets: [(title: String, mins: Int)] = [
            ("❄️ 全屋 30 分钟后开机预冷/预热", 30),
            ("❄️ 全屋 1 小时后开机预冷/预热", 60),
            ("❄️ 全屋 2 小时后开机预冷/预热", 120)
        ]
        for p in allOnPresets {
            let pItem = NSMenuItem(title: p.title, action: #selector(quickCountdownFromMenu(_:)), keyEquivalent: "")
            pItem.target = self
            pItem.representedObject = ["minutes": p.mins, "powerOn": true, "all": true] as [String: Any]
            quickCountdownMenu.addItem(pItem)
        }
        let quickCountdownParent = NSMenuItem(title: "⚡️ 快捷倒计时调度...", action: nil, keyEquivalent: "")
        scheduleMenu.setSubmenu(quickCountdownMenu, for: quickCountdownParent)
        scheduleMenu.addItem(quickCountdownParent)
        scheduleMenu.addItem(.separator())

        if !activeSchedules.isEmpty {
            for action in activeSchedules {
                let devName = model.allUnifiedDevices.first(where: { $0.id == action.deviceId })?.name ?? "空调"
                let timeStr = DateFormatter.localizedString(from: action.fireDate, dateStyle: .none, timeStyle: .short)
                let cleanActionName = Self.extractPlanActionVerb(from: action, devName: devName)
                let repeatTag = action.repeatLabel.map { " [\($0)]" } ?? ""
                let statusTag = action.enabled ? "" : " [已暂停]"
                let remainingDesc = action.enabled ? "，\(Self.formatRemainingTime(fireDate: action.fireDate))" : ""
                let item = NSMenuItem(title: "⏱ \(devName): \(cleanActionName) (\(timeStr)\(remainingDesc))\(repeatTag)\(statusTag)", action: nil, keyEquivalent: "")

                let singleTaskMenu = NSMenu()
                singleTaskMenu.autoenablesItems = false

                let devInfoItem = NSMenuItem(title: "空调设备: \(devName)", action: nil, keyEquivalent: "")
                devInfoItem.isEnabled = false
                singleTaskMenu.addItem(devInfoItem)

                let fullTimeStr = DateFormatter.localizedString(from: action.fireDate, dateStyle: .medium, timeStyle: .medium)
                let remInfo = action.enabled ? " (\(Self.formatRemainingTime(fireDate: action.fireDate)))" : ""
                let timeInfoItem = NSMenuItem(title: "下次执行: \(fullTimeStr)\(remInfo)", action: nil, keyEquivalent: "")
                timeInfoItem.isEnabled = false
                singleTaskMenu.addItem(timeInfoItem)

                if let rep = action.repeatLabel {
                    let repeatInfoItem = NSMenuItem(title: "周期重复: \(rep)", action: nil, keyEquivalent: "")
                    repeatInfoItem.isEnabled = false
                    singleTaskMenu.addItem(repeatInfoItem)
                }

                singleTaskMenu.addItem(.separator())

                let toggleEnabledTitle = action.enabled ? "⏸ 暂停此定时任务" : "▶️ 恢复此定时任务"
                let toggleEnabledItem = NSMenuItem(
                    title: toggleEnabledTitle,
                    action: #selector(toggleSingleScheduleEnabledFromMenu(_:)),
                    keyEquivalent: ""
                )
                toggleEnabledItem.target = self
                toggleEnabledItem.representedObject = action.id.uuidString
                singleTaskMenu.addItem(toggleEnabledItem)

                let cancelSingleItem = NSMenuItem(
                    title: "❌ 取消该定时任务",
                    action: #selector(cancelSingleScheduleFromMenu(_:)),
                    keyEquivalent: ""
                )
                cancelSingleItem.target = self
                cancelSingleItem.representedObject = action.id.uuidString
                singleTaskMenu.addItem(cancelSingleItem)

                // 动态检测同频批次兄弟任务并提供一键协同管理 (v1.9.69, v1.9.70 升级无序集合与自然周期同频判定)
                let siblingActions = activeSchedules.filter { StatusItemController.isSiblingSchedule($0, action) }
                if siblingActions.count > 1 {
                    singleTaskMenu.addItem(.separator())
                    let anySiblingEnabled = siblingActions.contains(where: \.enabled)
                    let syncToggleTitle = anySiblingEnabled ? "⏸ 同步暂停此批任务 (\(siblingActions.count) 台)" : "▶️ 同步恢复此批任务 (\(siblingActions.count) 台)"
                    let syncToggleItem = NSMenuItem(
                        title: syncToggleTitle,
                        action: #selector(toggleSiblingSchedulesFromMenu(_:)),
                        keyEquivalent: ""
                    )
                    syncToggleItem.target = self
                    syncToggleItem.representedObject = siblingActions.map(\.id.uuidString)
                    singleTaskMenu.addItem(syncToggleItem)

                    let syncCancelItem = NSMenuItem(
                        title: "❌ 同步取消此批任务 (\(siblingActions.count) 台)",
                        action: #selector(cancelSiblingSchedulesFromMenu(_:)),
                        keyEquivalent: ""
                    )
                    syncCancelItem.target = self
                    syncCancelItem.representedObject = siblingActions.map(\.id.uuidString)
                    singleTaskMenu.addItem(syncCancelItem)
                }

                scheduleMenu.setSubmenu(singleTaskMenu, for: item)
                scheduleMenu.addItem(item)
            }
            scheduleMenu.addItem(.separator())
            let enabledCount = activeSchedules.filter(\.enabled).count
            let pausedCount = activeSchedules.count - enabledCount

            if enabledCount > 0 {
                let pauseAllItem = NSMenuItem(
                    title: "⏸ 暂停全屋所有定时任务",
                    action: #selector(pauseAllSchedulesFromMenu),
                    keyEquivalent: ""
                )
                pauseAllItem.target = self
                scheduleMenu.addItem(pauseAllItem)
            }
            if pausedCount > 0 {
                let resumeAllItem = NSMenuItem(
                    title: "▶️ 恢复全屋所有定时任务",
                    action: #selector(resumeAllSchedulesFromMenu),
                    keyEquivalent: ""
                )
                resumeAllItem.target = self
                scheduleMenu.addItem(resumeAllItem)
            }

            let cancelAllItem = NSMenuItem(
                title: "🗑 取消全屋所有定时与倒计时",
                action: #selector(cancelAllSchedulesFromMenu),
                keyEquivalent: ""
            )
            cancelAllItem.target = self
            scheduleMenu.addItem(cancelAllItem)

            let scheduleParentTitle: String
            if pausedCount == 0 {
                scheduleParentTitle = "⏱ 计划调度 (\(enabledCount) 个任务生效中)..."
            } else if enabledCount == 0 {
                scheduleParentTitle = "⏱ 计划调度 (\(pausedCount) 个任务已暂停)..."
            } else {
                scheduleParentTitle = "⏱ 计划调度 (\(enabledCount) 生效 / \(pausedCount) 暂停)..."
            }
            let scheduleParentItem = NSMenuItem(title: scheduleParentTitle, action: nil, keyEquivalent: "")
            menu.setSubmenu(scheduleMenu, for: scheduleParentItem)
            menu.addItem(scheduleParentItem)
        } else {
            let noScheduleInfo = NSMenuItem(title: "当前无生效中的计划任务", action: nil, keyEquivalent: "")
            noScheduleInfo.isEnabled = false
            scheduleMenu.addItem(noScheduleInfo)

            let scheduleParentItem = NSMenuItem(title: "⏱ 计划调度 (无生效任务)...", action: nil, keyEquivalent: "")
            menu.setSubmenu(scheduleMenu, for: scheduleParentItem)
            menu.addItem(scheduleParentItem)
        }
        }

        menu.addItem(.separator())

        let launchItem = NSMenuItem(title: model.launchAtLogin ? "开机自启：开" : "开机自启：关", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        menu.addItem(launchItem)

        let tempItem = NSMenuItem(title: model.menuBarShowTemperature ? "菜单栏显示温度：开" : "菜单栏显示温度：关", action: #selector(toggleMenuBarTemperature), keyEquivalent: "")
        tempItem.target = self
        menu.addItem(tempItem)

        let themeMenu = NSMenu()
        themeMenu.autoenablesItems = false
        for mode in ThemeMode.allCases {
            let item = NSMenuItem(title: mode.label, action: #selector(setTheme(_:)), keyEquivalent: "")
            item.target = self
            item.state = mode == model.themeMode ? .on : .off
            item.representedObject = mode.rawValue
            themeMenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "主题", action: nil, keyEquivalent: "")
        menu.setSubmenu(themeMenu, for: themeItem)
        menu.addItem(themeItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出海尔空调控制", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil  // 用后即拆，避免菜单残留
    }

    @objc private func openVoiceControl() {
        VoiceCapsuleWindowController.shared.show()
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "海尔空调控制" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // 窗口已销毁时通过 openWindow 场景重建（由 App 侧处理）
            NotificationCenter.default.post(name: .haierOpenMainWindow, object: nil)
        }
    }

    @objc private func toggleAmbientSound() {
        if AmbientSoundEngine.shared.isPlaying {
            AmbientSoundEngine.shared.stop()
        } else {
            AmbientSoundEngine.shared.play(type: model.sleepAmbientSoundType)
        }
        refreshTemperature()
    }

    /// 当前首选控制设备 ID（全仓收敛统一路由） (v1.9.42)
    private var primaryDeviceId: String? {
        model.primaryDeviceId
    }

    @objc private func togglePrimaryPower() {
        guard let targetId = primaryDeviceId else { return }
        let currentPower = model.attribute("onOffStatus", deviceId: targetId)?.boolValue ?? false
        model.sendAttribute("onOffStatus", value: .bool(!currentPower), deviceId: targetId)
    }

    @objc private func turnOffAllDevices() {
        model.turnOffAllDevices()
    }

    @objc private func turnOnAllDevices() {
        model.turnOnAllDevices()
    }

    @objc private func applyQuickCoolingAll() {
        model.applyPresetToAllDevices(mode: .cooling, temperature: 26.0)
    }

    @objc private func applyQuickHeatingAll() {
        model.applyPresetToAllDevices(mode: .heating, temperature: 20.0)
    }

    @objc private func applyQuickDehumidifyAll() {
        model.applyPresetToAllDevices(mode: .dehumidify, temperature: 24.0)
    }

    @objc private func applyQuickFanAll() {
        model.applyPresetToAllDevices(mode: .fan, temperature: 26.0)
    }

    @objc private func applyQuickAutoAll() {
        model.applyPresetToAllDevices(mode: .auto, temperature: 24.0)
    }

    @objc private func stepUpAllTemperature() {
        model.adjustTemperatureAll(delta: 1.0)
    }

    @objc private func stepUpHalfAllTemperature() {
        model.adjustTemperatureAll(delta: 0.5)
    }

    @objc private func stepDownHalfAllTemperature() {
        model.adjustTemperatureAll(delta: -0.5)
    }

    @objc private func stepDownAllTemperature() {
        model.adjustTemperatureAll(delta: -1.0)
    }

    @objc private func stepUpPrimaryTemperature() {
        guard let devId = primaryDeviceId else { return }
        model.adjustDeviceTemperature(deviceId: devId, delta: 1.0)
    }

    @objc private func stepUpHalfPrimaryTemperature() {
        guard let devId = primaryDeviceId else { return }
        model.adjustDeviceTemperature(deviceId: devId, delta: 0.5)
    }

    @objc private func stepDownHalfPrimaryTemperature() {
        guard let devId = primaryDeviceId else { return }
        model.adjustDeviceTemperature(deviceId: devId, delta: -0.5)
    }

    @objc private func stepDownPrimaryTemperature() {
        guard let devId = primaryDeviceId else { return }
        model.adjustDeviceTemperature(deviceId: devId, delta: -1.0)
    }

    @objc private func stepUpDeviceTemperature(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.adjustDeviceTemperature(deviceId: devId, delta: 1.0)
    }

    @objc private func stepUpHalfDeviceTemperature(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.adjustDeviceTemperature(deviceId: devId, delta: 0.5)
    }

    @objc private func stepDownHalfDeviceTemperature(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.adjustDeviceTemperature(deviceId: devId, delta: -0.5)
    }

    @objc private func stepDownDeviceTemperature(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.adjustDeviceTemperature(deviceId: devId, delta: -1.0)
    }

    /// 设为菜单栏主显常驻设备 (v1.9.39)
    @objc private func setPrimaryDeviceFromMenu(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.menuBarDeviceId = devId
        refreshTemperature()
        let name = model.allUnifiedDevices.first(where: { $0.id == devId })?.name ?? "目标空调"
        model.operationNotice = AppModel.OperationNotice(text: "已将「\(name)」设为菜单栏主显设备", isError: false)
    }

    @objc private func toggleDevicePower(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        let currentPower = model.attribute("onOffStatus", deviceId: devId)?.boolValue ?? false
        model.sendAttribute("onOffStatus", value: .bool(!currentPower), deviceId: devId)
    }

    @objc private func setQuickCooling(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.sendAttribute("onOffStatus", value: .bool(true), deviceId: devId)
        model.sendAttribute("operationMode", value: .string(ACModeCode.cooling.rawValue), deviceId: devId)
        model.sendAttribute("targetTemperature", value: .double(26.0), deviceId: devId)
    }

    @objc private func setQuickHeating(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.sendAttribute("onOffStatus", value: .bool(true), deviceId: devId)
        model.sendAttribute("operationMode", value: .string(ACModeCode.heating.rawValue), deviceId: devId)
        model.sendAttribute("targetTemperature", value: .double(20.0), deviceId: devId)
    }

    @objc private func setQuickDehumidify(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.sendAttribute("onOffStatus", value: .bool(true), deviceId: devId)
        model.sendAttribute("operationMode", value: .string(ACModeCode.dehumidify.rawValue), deviceId: devId)
        model.sendAttribute("targetTemperature", value: .double(24.0), deviceId: devId)
    }

    @objc private func setQuickFan(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.sendAttribute("onOffStatus", value: .bool(true), deviceId: devId)
        model.sendAttribute("operationMode", value: .string(ACModeCode.fan.rawValue), deviceId: devId)
        model.sendAttribute("targetTemperature", value: .double(26.0), deviceId: devId)
    }

    @objc private func setQuickAuto(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.sendAttribute("onOffStatus", value: .bool(true), deviceId: devId)
        model.sendAttribute("operationMode", value: .string(ACModeCode.auto.rawValue), deviceId: devId)
        model.sendAttribute("targetTemperature", value: .double(24.0), deviceId: devId)
    }

    @objc private func applyQuickCoolingPrimary() {
        guard let devId = primaryDeviceId else { return }
        model.sendAttribute("onOffStatus", value: .bool(true), deviceId: devId)
        model.sendAttribute("operationMode", value: .string(ACModeCode.cooling.rawValue), deviceId: devId)
        model.sendAttribute("targetTemperature", value: .double(26.0), deviceId: devId)
    }

    @objc private func applyQuickHeatingPrimary() {
        guard let devId = primaryDeviceId else { return }
        model.sendAttribute("onOffStatus", value: .bool(true), deviceId: devId)
        model.sendAttribute("operationMode", value: .string(ACModeCode.heating.rawValue), deviceId: devId)
        model.sendAttribute("targetTemperature", value: .double(20.0), deviceId: devId)
    }

    @objc private func applyQuickDehumidifyPrimary() {
        guard let devId = primaryDeviceId else { return }
        model.sendAttribute("onOffStatus", value: .bool(true), deviceId: devId)
        model.sendAttribute("operationMode", value: .string(ACModeCode.dehumidify.rawValue), deviceId: devId)
        model.sendAttribute("targetTemperature", value: .double(24.0), deviceId: devId)
    }

    @objc private func applyQuickFanPrimary() {
        guard let devId = primaryDeviceId else { return }
        model.sendAttribute("onOffStatus", value: .bool(true), deviceId: devId)
        model.sendAttribute("operationMode", value: .string(ACModeCode.fan.rawValue), deviceId: devId)
        model.sendAttribute("targetTemperature", value: .double(26.0), deviceId: devId)
    }

    @objc private func applyQuickAutoPrimary() {
        guard let devId = primaryDeviceId else { return }
        model.sendAttribute("onOffStatus", value: .bool(true), deviceId: devId)
        model.sendAttribute("operationMode", value: .string(ACModeCode.auto.rawValue), deviceId: devId)
        model.sendAttribute("targetTemperature", value: .double(24.0), deviceId: devId)
    }

    @objc private func openFilterCare() {
        openMainWindow()
        model.showFilterCareSheet = true
    }

    @objc private func resetDeviceFilterFromMenu(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        model.resetFilterMaintenance(for: devId)
        refreshTemperature()
    }

    @objc private func resetAllFiltersFromMenu() {
        model.resetAllFilterMaintenance()
        refreshTemperature()
    }

    @objc private func resetPrimaryFilterFromMenu() {
        if let primaryId = primaryDeviceId {
            model.resetFilterMaintenance(for: primaryId)
        } else {
            model.resetAllFilterMaintenance()
        }
        refreshTemperature()
    }

    @objc private func cancelAllSchedulesFromMenu() {
        let count = model.cancelAllSchedules()
        if count > 0 {
            refreshTemperature()
        }
    }

    @objc private func pauseAllSchedulesFromMenu() {
        let count = model.setAllScheduledActionsEnabled(false)
        if count > 0 {
            model.operationNotice = AppModel.OperationNotice(text: "⏸ 已临时暂停全屋所有定时任务（共 \(count) 个）", isError: false)
            refreshTemperature()
        }
    }

    @objc private func resumeAllSchedulesFromMenu() {
        let count = model.setAllScheduledActionsEnabled(true)
        if count > 0 {
            model.operationNotice = AppModel.OperationNotice(text: "▶️ 已恢复全屋所有定时任务生效（共 \(count) 个）", isError: false)
            refreshTemperature()
        }
    }

    @objc private func toggleSingleScheduleEnabledFromMenu(_ sender: NSMenuItem) {
        guard let idStr = sender.representedObject as? String,
              let uuid = UUID(uuidString: idStr) else { return }
        if let action = model.scheduledActions.first(where: { $0.id == uuid }) {
            let nextState = !action.enabled
            model.setScheduledActionEnabled(uuid, enabled: nextState)
            let statusText = nextState ? "已恢复生效" : "已临时暂停"
            model.operationNotice = AppModel.OperationNotice(text: "⏱ 定时任务「\(action.name)」\(statusText)", isError: false)
            refreshTemperature()
        }
    }

    @objc private func cancelSingleScheduleFromMenu(_ sender: NSMenuItem) {
        guard let idStr = sender.representedObject as? String,
              let uuid = UUID(uuidString: idStr) else { return }
        if let action = model.scheduledActions.first(where: { $0.id == uuid }) {
            model.removeScheduledAction(action)
            model.operationNotice = AppModel.OperationNotice(text: "🗑 已取消计划任务「\(action.name)」", isError: false)
            refreshTemperature()
        }
    }

    @objc private func toggleSiblingSchedulesFromMenu(_ sender: NSMenuItem) {
        guard let idStrs = sender.representedObject as? [String] else { return }
        let uuids = Set(idStrs.compactMap { UUID(uuidString: $0) })
        let targets = model.scheduledActions.filter { uuids.contains($0.id) }
        guard !targets.isEmpty else { return }
        let anyEnabled = targets.contains(where: \.enabled)
        let newEnabled = !anyEnabled
        let modified = model.setScheduledActionsEnabled(ids: uuids, enabled: newEnabled)
        let actionDesc = newEnabled ? "恢复" : "暂停"
        model.operationNotice = AppModel.OperationNotice(text: "\(newEnabled ? "▶️" : "⏸") 已\(actionDesc)同频批次任务（共 \(modified) 台空调）", isError: false)
        refreshTemperature()
    }

    @objc private func cancelSiblingSchedulesFromMenu(_ sender: NSMenuItem) {
        guard let idStrs = sender.representedObject as? [String] else { return }
        let uuids = Set(idStrs.compactMap { UUID(uuidString: $0) })
        let removed = model.removeScheduledActions(ids: uuids)
        if removed > 0 {
            model.operationNotice = AppModel.OperationNotice(text: "🗑 已同步取消同频批次任务（共 \(removed) 台空调）", isError: false)
            refreshTemperature()
        }
    }

    /// 判定两个计划调度任务是否属于同一时间、同一属性、同一动作值且同一重复规则的同频协同任务 (v1.9.70 升级无序集合比对与周期跨天智能同频判定)
    private static func isSiblingSchedule(_ a: ScheduledAction, _ b: ScheduledAction) -> Bool {
        guard a.attrName == b.attrName else { return false }
        guard a.attrValue == b.attrValue else { return false }
        guard a.repeatsDaily == b.repeatsDaily else { return false }
        guard Set(a.repeatWeekdays) == Set(b.repeatWeekdays) else { return false }
        if a.repeatsDaily || !a.repeatWeekdays.isEmpty {
            let cal = Calendar.current
            let hourA = cal.component(.hour, from: a.fireDate)
            let minA = cal.component(.minute, from: a.fireDate)
            let hourB = cal.component(.hour, from: b.fireDate)
            let minB = cal.component(.minute, from: b.fireDate)
            return hourA == hourB && minA == minB
        } else {
            return abs(a.fireDate.timeIntervalSince(b.fireDate)) <= 5.0
        }
    }

    @objc private func pauseDeviceSchedulesFromMenu(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        let count = model.setScheduledActionsEnabled(for: devId, enabled: false)
        if count > 0 {
            let devName = model.allUnifiedDevices.first(where: { $0.id == devId })?.name ?? "设备"
            model.operationNotice = AppModel.OperationNotice(text: "⏸ 已临时暂停「\(devName)」所有定时任务（共 \(count) 个）", isError: false)
            refreshTemperature()
        }
    }

    @objc private func resumeDeviceSchedulesFromMenu(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        let count = model.setScheduledActionsEnabled(for: devId, enabled: true)
        if count > 0 {
            let devName = model.allUnifiedDevices.first(where: { $0.id == devId })?.name ?? "设备"
            model.operationNotice = AppModel.OperationNotice(text: "▶️ 已恢复「\(devName)」所有定时任务生效（共 \(count) 个）", isError: false)
            refreshTemperature()
        }
    }

    @objc private func cancelDeviceSchedulesFromMenu(_ sender: NSMenuItem) {
        guard let devId = sender.representedObject as? String else { return }
        let count = model.cancelSchedules(for: devId)
        if count > 0 {
            let devName = model.allUnifiedDevices.first(where: { $0.id == devId })?.name ?? "设备"
            model.operationNotice = AppModel.OperationNotice(text: "🗑 已取消「\(devName)」所有定时与倒计时（共 \(count) 个）", isError: false)
            refreshTemperature()
        }
    }

    @objc private func quickCountdownFromMenu(_ sender: NSMenuItem) {
        let (minutes, powerOn, specificDeviceId, forceAll): (Int, Bool, String?, Bool) = {
            if let mins = sender.representedObject as? Int {
                return (mins, false, nil, false)
            }
            if let dict = sender.representedObject as? [String: Any] {
                let mins = dict["minutes"] as? Int ?? 30
                let on = dict["powerOn"] as? Bool ?? false
                let devId = dict["deviceId"] as? String
                let all = dict["all"] as? Bool ?? false
                return (mins, on, devId, all)
            }
            return (0, false, nil, false)
        }()
        guard minutes > 0 else { return }

        let targetDevices: [AppModel.UnifiedDevice] = {
            if forceAll {
                return model.allUnifiedDevices.filter { model.reachability(for: $0.id).isControllable }
            }
            if let devId = specificDeviceId, let dev = model.allUnifiedDevices.first(where: { $0.id == devId }) {
                return [dev]
            }
            if let primaryId = primaryDeviceId, let dev = model.allUnifiedDevices.first(where: { $0.id == primaryId }) {
                return [dev]
            }
            return model.allUnifiedDevices.filter { model.reachability(for: $0.id).isControllable }
        }()
        guard !targetDevices.isEmpty else {
            model.operationNotice = AppModel.OperationNotice(text: "未检测到可控制的空调设备", isError: true)
            return
        }
        let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let timeDesc = (minutes >= 60 && minutes % 60 == 0) ? "\(minutes / 60) 小时" : "\(minutes) 分钟"
        let actionDesc = powerOn ? "开机" : "关机"
        guard let valJSON = ScheduledAction.valueJSON(.bool(powerOn)) else { return }

        var newActions: [ScheduledAction] = []
        for dev in targetDevices {
            let action = ScheduledAction(
                name: "「\(dev.name)」\(timeDesc)后\(actionDesc)",
                deviceId: dev.id,
                attrName: "onOffStatus",
                attrDesc: "开关",
                attrValueJSON: valJSON,
                fireDate: fireDate,
                repeatsDaily: false,
                repeatWeekdays: [],
                enabled: true
            )
            newActions.append(action)
        }
        model.addScheduledActions(newActions)
        let scope = targetDevices.count > 1 ? "全屋 \(targetDevices.count) 台空调" : "「\(targetDevices[0].name)」"
        let glyph = powerOn ? "❄️" : "⏱"
        model.operationNotice = AppModel.OperationNotice(text: "\(glyph) 已为\(scope)设定 \(timeDesc) 后自动\(actionDesc)", isError: false)
        refreshTemperature()
    }

    @objc private func setAllWindSpeedFromMenu(_ sender: NSMenuItem) {
        guard let speed = sender.representedObject as? String else { return }
        _ = model.setWindSpeedAll(speedName: speed, autoPowerOn: false)
        refreshTemperature()
    }

    @objc private func setDeviceWindSpeedFromMenu(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: String],
              let devId = dict["deviceId"],
              let speed = dict["speed"] else { return }
        _ = model.setWindSpeed(deviceIds: [devId], speedName: speed, autoPowerOn: false)
        refreshTemperature()
    }

    @objc private func setPrimaryWindSpeedFromMenu(_ sender: NSMenuItem) {
        guard let speed = sender.representedObject as? String else { return }
        if let primaryId = primaryDeviceId {
            _ = model.setWindSpeed(deviceIds: [primaryId], speedName: speed, autoPowerOn: false)
        } else {
            _ = model.setWindSpeedAll(speedName: speed, autoPowerOn: false)
        }
        refreshTemperature()
    }

    @objc private func toggleLaunchAtLogin() {
        model.launchAtLogin.toggle()
    }

    @objc private func toggleMenuBarTemperature() {
        model.menuBarShowTemperature.toggle()
        refreshTemperature()
    }

    @objc private func setTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = ThemeMode(rawValue: raw) else { return }
        model.themeMode = mode
    }

    /// 格式化时间跨度（用于 Tooltip 等语句流式表达） (v1.9.67)
    private static func formatRemainingTimeSpan(remSecs: Int) -> String {
        if remSecs < 60 {
            return "不到 1 分钟"
        } else if remSecs < 3600 {
            return "\(remSecs / 60) 分钟"
        } else if remSecs < 86400 {
            let h = remSecs / 3600
            let m = (remSecs % 3600) / 60
            return m > 0 ? "\(h) 小时 \(m) 分钟" : "\(h) 小时"
        } else {
            let d = remSecs / 86400
            let h = (remSecs % 86400) / 3600
            return h > 0 ? "\(d) 天 \(h) 小时" : "\(d) 天"
        }
    }

    /// 计算并格式化计划调度任务的实时剩余时间描述 (v1.9.65 毫秒级高精消歧, v1.9.67 长周期智能格式化)
    private static func formatRemainingTime(fireDate: Date, now: Date = Date()) -> String {
        let diff = Int(fireDate.timeIntervalSince(now))
        if diff <= 0 {
            return "即将执行"
        } else if diff < 60 {
            return "剩余不到 1 分钟"
        } else if diff < 3600 {
            return "剩余 \(diff / 60) 分钟"
        } else if diff < 86400 {
            let h = diff / 3600
            let m = (diff % 3600) / 60
            return m > 0 ? "剩余 \(h)小时\(m)分" : "剩余 \(h)小时"
        } else {
            let d = diff / 86400
            let h = (diff % 86400) / 3600
            return h > 0 ? "剩余 \(d)天\(h)小时" : "剩余 \(d)天"
        }
    }

    private static let schedulePrefixRegex: NSRegularExpression? = {
        let pattern = #"^(?:(?:定时|预约)?(?:全屋)?(?:在)?\s*)*(?:(?:明天|后天|大后天|次日|工作日|平时|周末三天|周末|双休|单休|每天|周[一二三四五六日天0-7周至到\-~、\s]+|每周[一二三四五六日天0-7、\s]+|[、,，和与及跟以及还有或者或加/／\s]+)\s*)*(?:\d{1,2}:\d{2}(?::\d{2})?\s*)*(?:\d+\s*(?:分钟|小时|钟头)后|晨间过渡(?:关机)?\s*)*"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    private static let scheduleSuffixRegex: NSRegularExpression? = {
        let pattern = #"\s*(?:\(|（|\[)(?:每天|工作日|平时|周末三天|周末|双休|单休|(?:每)?周[一二三四五六日天周至到\-~、\s]+)(?:\)|）|\])\s*$"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// 智能提取计划调度或倒计时任务的干净动作谓词（以硬件底层真实布尔载荷权威裁决开关机，消除“开关”双词倒置开机意图缺陷，并提炼温阶/模式及清洗冗余前缀与重复周期标签） (v1.9.66, v1.9.67, v1.9.68, v1.9.69, v1.9.71 预编译正则与单休/周末三天完备纳管)
    private static func extractPlanActionVerb(from action: ScheduledAction, devName: String) -> String {
        var name = action.name
        if !devName.isEmpty && name.hasPrefix("「\(devName)」") {
            name = String(name.dropFirst("「\(devName)」".count))
        } else if let match = name.range(of: #"^「.+?」"#, options: .regularExpression) {
            name.removeSubrange(match)
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 如果是开关机属性，以实际动作布尔负载为首要权威判定（彻底杜绝包含“开关”等词导致开机被反向识别为关机）
        if action.attrName == "onOffStatus" {
            if let boolVal = action.attrValue?.boolValue {
                return boolVal ? "开机" : "关机"
            }
            if name.contains("关机") || name.contains("关空调") || name.contains("关闭") {
                return "关机"
            }
            if name.contains("开机") || name.contains("开空调") || name.contains("开启") || name.contains("打开") {
                return "开机"
            }
            return (action.attrValue == .bool(true)) ? "开机" : "关机"
        }

        // 2. 目标温度属性：提炼精准目标温阶（如“设定温度 26°C”）
        if action.attrName == "targetTemperature" {
            if let d = action.attrValue?.doubleValue {
                let tempStr = (d.truncatingRemainder(dividingBy: 1.0) == 0) ? "\(Int(d))°C" : String(format: "%.1f°C", d)
                return "设定温度 \(tempStr)"
            }
        }

        // 3. 运行模式属性：提炼具体模式切换
        if action.attrName == "operationMode" {
            if let raw = action.attrValue?.stringValue, let code = ACModeCode.match(from: raw) {
                return "切换\(code.desc)"
            }
        }

        // 4. 其他任务类型（自清洁/睡眠曲线/自定义调温等）：清洗前置时间与周期前缀及冗余前缀 (v1.9.71 预编译正则与单休/周末三天完备纳管)
        if let regex = schedulePrefixRegex {
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            name = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
        }
        // 清洗末尾附带的周期重复后缀（如“（工作日）”、“（每天）”、“（单休）”），防止与菜单后续追加的周期标签形成双重重复
        if let regex = scheduleSuffixRegex {
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            name = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "执行任务"
        }
        return name
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let haierOpenMainWindow = Notification.Name("haierOpenMainWindow")
}
