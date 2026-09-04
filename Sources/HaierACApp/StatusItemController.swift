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

        // 温度/开关变化时刷新菜单栏标题
        model.$attributes
            .combineLatest(model.$menuBarDeviceId, model.$menuBarShowTemperature, model.$devices)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshTemperature() }
            }
            .store(in: &cancellables)
    }

    /// 菜单栏图标旁显示当前温度（如 26°）
    private func refreshTemperature() {
        guard let button = statusItem?.button else { return }
        if let text = model.menuBarTemperatureText {
            button.title = " \(text)"
            button.imagePosition = .imageLeft
        } else {
            button.title = ""
        }
        statusItem?.length = NSStatusItem.variableLength
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
        } else {
            popover = NSPopover()
            popover.behavior = .transient  // 点击外部自动关闭；关闭时销毁，无幽灵窗口
            popover.animates = true
            let host = NSHostingController(
                rootView: MenuBarControlsView()
                    .environmentObject(model)
                    .preferredColorScheme(model.themeMode.colorScheme)
            )
            popover.contentViewController = host
            self.popover = popover
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    /// 右键：上下文菜单（打开主窗口 / 开机自启 / 主题 / 退出）
    private func showContextMenu() {
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

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

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "海尔空调控制" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // 窗口已销毁时通过 openWindow 场景重建（由 App 侧处理）
            NotificationCenter.default.post(name: .haierOpenMainWindow, object: nil)
        }
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
