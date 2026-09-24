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
            let targetId = model.menuBarDeviceId ?? model.allUnifiedDevices.first?.id
            let isPowerOn: Bool = {
                guard let targetId else { return false }
                return model.reachability(for: targetId) == .available && (model.attribute("onOffStatus", deviceId: targetId)?.boolValue ?? false)
            }()
            let symbolName = isPowerOn ? "air.conditioner.horizontal.fill" : "air.conditioner.horizontal"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: isPowerOn ? "海尔空调 (运行中)" : "海尔空调 (待机)")
            button.image?.isTemplate = true
            if let text = model.menuBarTemperatureText {
                button.title = " \(text)"
            } else {
                button.title = ""
            }
        }
        button.imagePosition = .imageLeft
        statusItem?.length = NSStatusItem.variableLength

        // 动态构建悬浮 Tooltip 状态概览 (v1.9.29 全量统一全屋设备与三态感知)
        var tooltipParts: [String] = [
            model.gatewayConnected ? "海尔空调控制 (网关在线)" : "⚠️ 海尔云端网关重连中..."
        ]
        let allDevices = model.allUnifiedDevices
        let primaryTargetId = model.menuBarDeviceId ?? allDevices.first?.id
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
                        var line = "\(starPrefix) \(devName): \(modeGlyph) \(String(format: "%.0f°C", targetTemp))"
                        if let indoor = indoorTemp {
                            line += " (室内 \(String(format: "%.1f°C", indoor)))"
                        }
                        tooltipParts.append(line)
                    } else {
                        var line = "\(starPrefix) \(devName): 关机待机"
                        if let indoor = indoorTemp {
                            line += " (室内 \(String(format: "%.1f°C", indoor)))"
                        }
                        tooltipParts.append(line)
                    }
                }
            }
        }

        // 瞬时总功率 (v1.9.23)
        let instantPower = EnergyAnalyticsEngine.shared.currentInstantaneousPower
        if instantPower > 10.0 {
            tooltipParts.append("⚡️ 全屋空调瞬时功率: \(Int(round(instantPower))) W")
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

        let filterClean = model.filterCleanlinessPercentage
        if filterClean <= 30 {
            tooltipParts.append("⚠️ 滤网洁净度较低 (\(filterClean)%)，建议拆洗保养")
        }

        tooltipParts.append("💡 左键呼出快捷控制面板，右键展开系统菜单")
        button.toolTip = tooltipParts.joined(separator: "\n")
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

        if allDevices.count > 1 {
            // 多设备场景：若有空调处于开机状态，提供全屋一键快速关机 (v1.9.28)
            if !onDevices.isEmpty {
                let turnOffAllItem = NSMenuItem(title: "⏻ 关闭全屋空调 (\(onDevices.count) 台运行中)", action: #selector(turnOffAllDevices), keyEquivalent: "")
                turnOffAllItem.target = self
                turnOffAllItem.isEnabled = model.gatewayConnected
                menu.addItem(turnOffAllItem)
            }

            // 多设备级联控制子菜单 (v1.9.28)
            let devicesMenu = NSMenu()
            devicesMenu.autoenablesItems = false
            for dev in allDevices {
                let devId = dev.id
                let isPowerOn = model.attribute("onOffStatus", deviceId: devId)?.boolValue ?? false
                let reach = model.reachability(for: devId)
                let isControllable = reach.isControllable

                let devSubmenu = NSMenu()
                devSubmenu.autoenablesItems = false

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
                    title: "一键制冷 26°C",
                    action: #selector(setQuickCooling(_:)),
                    keyEquivalent: ""
                )
                coolItem.target = self
                coolItem.representedObject = devId
                coolItem.isEnabled = isControllable
                devSubmenu.addItem(coolItem)

                // 一键制热 20°C
                let heatItem = NSMenuItem(
                    title: "一键制热 20°C",
                    action: #selector(setQuickHeating(_:)),
                    keyEquivalent: ""
                )
                heatItem.target = self
                heatItem.representedObject = devId
                heatItem.isEnabled = isControllable
                devSubmenu.addItem(heatItem)

                let statusBadge: String
                switch reach {
                case .gatewayReconnecting: statusBadge = "⏳ 重连中"
                case .deviceOffline: statusBadge = "⚡️ 离线"
                case .available: statusBadge = isPowerOn ? "🟢 开机" : "⚪️ 待机"
                }

                let devItem = NSMenuItem(title: "\(dev.name) (\(statusBadge))", action: nil, keyEquivalent: "")
                devicesMenu.setSubmenu(devSubmenu, for: devItem)
                devicesMenu.addItem(devItem)
            }

            let devicesParentItem = NSMenuItem(title: "空调设备控制矩阵...", action: nil, keyEquivalent: "")
            menu.setSubmenu(devicesMenu, for: devicesParentItem)
            menu.addItem(devicesParentItem)
        } else if let dev = allDevices.first {
            // 单设备场景：保留快速电源开关
            let isPowerOn = model.attribute("onOffStatus", deviceId: dev.id)?.boolValue ?? false
            let powerTitle = isPowerOn ? "关机「\(dev.name)」" : "开机「\(dev.name)」"
            let powerItem = NSMenuItem(title: powerTitle, action: #selector(togglePrimaryPower), keyEquivalent: "")
            powerItem.target = self
            powerItem.isEnabled = model.reachability(for: dev.id).isControllable
            menu.addItem(powerItem)
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

        // 滤网健康与自清洁快速入口 (v1.9.21)
        let filterTitle = model.isSelfCleaningActive ?
            "56°C 自清洁进行中 (\(model.selfCleaningRemainingSeconds / 60)m\(model.selfCleaningRemainingSeconds % 60)s)..." :
            "滤网保养与自清洁 (洁净度 \(model.filterCleanlinessPercentage)%)..."
        let filterItem = NSMenuItem(title: filterTitle, action: #selector(openFilterCare), keyEquivalent: "")
        filterItem.target = self
        menu.addItem(filterItem)

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

    @objc private func togglePrimaryPower() {
        guard let targetId = model.menuBarDeviceId ?? model.allUnifiedDevices.first?.id else { return }
        let currentPower = model.attribute("onOffStatus", deviceId: targetId)?.boolValue ?? false
        model.sendAttribute("onOffStatus", value: .bool(!currentPower), deviceId: targetId)
    }

    @objc private func turnOffAllDevices() {
        let controllableOnIds = model.allUnifiedDevices
            .filter { model.reachability(for: $0.id).isControllable && model.attribute("onOffStatus", deviceId: $0.id)?.boolValue == true }
            .map(\.id)
        guard !controllableOnIds.isEmpty else { return }
        model.sendAttributeToDevices("onOffStatus", value: .bool(false), deviceIds: controllableOnIds)
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

    @objc private func openFilterCare() {
        openMainWindow()
        model.showFilterCareSheet = true
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

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let haierOpenMainWindow = Notification.Name("haierOpenMainWindow")
}
