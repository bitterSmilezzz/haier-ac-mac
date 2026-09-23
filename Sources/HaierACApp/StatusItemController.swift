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

        // 温度/开关/自清洁/睡眠/白噪音/设备选择/温度显示等状态变化时刷新菜单栏标题与悬浮提示 Tooltip
        Publishers.MergeMany(
            model.$attributes.map { _ in () }.eraseToAnyPublisher(),
            model.$devices.map { _ in () }.eraseToAnyPublisher(),
            model.$menuBarDeviceId.map { _ in () }.eraseToAnyPublisher(),
            model.$menuBarShowTemperature.map { _ in () }.eraseToAnyPublisher(),
            model.$isSelfCleaningActive.map { _ in () }.eraseToAnyPublisher(),
            model.$selfCleaningRemainingSeconds.map { _ in () }.eraseToAnyPublisher(),
            model.$activeSleepSession.map { _ in () }.eraseToAnyPublisher(),
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

        // 状态栏图标与标题动态感知 (v1.9.22)
        if model.isSelfCleaningActive {
            let m = model.selfCleaningRemainingSeconds / 60
            let s = model.selfCleaningRemainingSeconds % 60
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "蒸发器自清洁")
            button.image?.isTemplate = true
            button.title = " 56°C (\(String(format: "%02d:%02d", m, s)))"
        } else if model.activeSleepSession != nil {
            button.image = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "睡眠曲线运行中")
            button.image?.isTemplate = true
            if let text = model.menuBarTemperatureText {
                button.title = " \(text)"
            } else {
                button.title = ""
            }
        } else {
            button.image = NSImage(systemSymbolName: "air.conditioner.horizontal", accessibilityDescription: "海尔空调")
            button.image?.isTemplate = true
            if let text = model.menuBarTemperatureText {
                button.title = " \(text)"
            } else {
                button.title = ""
            }
        }
        button.imagePosition = .imageLeft
        statusItem?.length = NSStatusItem.variableLength

        // 动态构建悬浮 Tooltip 状态概览 (v1.9.21)
        var tooltipParts: [String] = ["海尔空调控制"]
        let deviceId = model.menuBarDeviceId ?? model.devices.first?.id ?? model.manualDevices.first?.deviceId
        if let deviceId = deviceId {
            let devName = model.devices.first(where: { $0.id == deviceId })?.deviceName ??
                          model.manualDevices.first(where: { $0.deviceId == deviceId })?.name ?? "空调"
            let attrs = model.attributes[deviceId] ?? [:]
            let isPowerOn = attrs["onOffStatus"]?.boolValue ?? false
            let mode = attrs["operationMode"]?.value?.stringValue ?? "制冷"
            let targetTemp = attrs["targetTemperature"]?.doubleValue ?? 26.0
            let indoorTemp = model.currentIndoorTemperature(for: deviceId)

            if isPowerOn {
                var line = "📍 \(devName): 开机中 | 模式: \(mode) | 设定: \(String(format: "%.0f°C", targetTemp))"
                if let indoor = indoorTemp {
                    line += " | 室内: \(String(format: "%.1f°C", indoor))"
                }
                tooltipParts.append(line)
            } else {
                tooltipParts.append("📍 \(devName): 关机待机中")
            }
        }

        if model.isSelfCleaningActive {
            let m = model.selfCleaningRemainingSeconds / 60
            let s = model.selfCleaningRemainingSeconds % 60
            tooltipParts.append("🔥 56°C 高温除菌自清洁进行中 (剩余 \(String(format: "%02d:%02d", m, s)))")
        }

        if let session = model.activeSleepSession {
            tooltipParts.append("🌙 智能睡眠曲线运行中 (\(session.curveConfig.name))")
        }

        if AmbientSoundEngine.shared.isPlaying {
            tooltipParts.append("🎵 助眠白噪音播放中 (\(model.sleepAmbientSoundType.displayName))")
        }

        tooltipParts.append("💡 左键点击呼出快捷控制面板，右键点击展开系统菜单")
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

    private func showPanel(relativeTo button: NSButton) {
        let popover: NSPopover
        if let existing = self.popover {
            popover = existing
            if let host = popover.contentViewController as? NSHostingController<AnyView> {
                host.rootView = AnyView(
                    MenuBarControlsView()
                        .environmentObject(model)
                        .preferredColorScheme(model.themeMode.colorScheme)
                )
            }
        } else {
            popover = NSPopover()
            popover.behavior = .transient  // 点击外部自动关闭；关闭时销毁，无幽灵窗口
            popover.animates = true
            let host = NSHostingController(
                rootView: AnyView(
                    MenuBarControlsView()
                        .environmentObject(model)
                        .preferredColorScheme(model.themeMode.colorScheme)
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
        let voiceItem = NSMenuItem(title: "语音控制... (⌃⌥A)", action: #selector(openVoiceControl), keyEquivalent: "")
        voiceItem.target = self
        menu.addItem(voiceItem)

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
