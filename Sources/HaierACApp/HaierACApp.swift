import SwiftUI
import AppKit
import HaierACCore

/// 应用委托：启动时后台恢复会话，不自动打开主窗口
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 后台恢复登录会话（菜单栏面板可直接使用，不弹主窗口）
        AppModel.shared.restoreSession()
        // 后台检查 GitHub 是否有新版本（G3 失效预案）
        Task { await AppModel.shared.checkForUpdates() }

        // 菜单栏状态项（NSStatusItem + NSPopover，无幽灵窗口）
        let controller = StatusItemController(model: AppModel.shared)
        controller.setup()
        statusItemController = controller

        // 启动后关闭自动出现的主窗口，转入后台（SwiftUI 窗口在此刻已创建完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            for window in NSApp.windows {
                if window.title == "海尔空调控制" {
                    window.close()
                }
            }
            NSApp.hide(nil)
        }
    }

    /// 应用级 URL 处理（haierac://main）：窗口全部关闭时也能打开主窗口。
    /// 视图级 onOpenURL 在无窗口时不触发，必须在这里处理。
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "haierac" {
            openMainWindow()
        }
    }

    /// 打开（或重建）主窗口
    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "海尔空调控制" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NotificationCenter.default.post(name: .haierOpenMainWindow, object: nil)
        }
    }

    /// 点击 Dock 图标时恢复主窗口（手动主动点击才显示）
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }
}

@main
struct HaierACApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("海尔空调控制", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 520, minHeight: 640)
                .preferredColorScheme(model.themeMode.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: .haierOpenMainWindow)) { _ in
                    openWindow(id: "main")
                }
        }
        .windowResizability(.contentMinSize)
        // 快捷指令/Shortcuts 集成：AppIntents.swift 中的 ACAppShortcuts 由系统自动发现，
        // 无需场景修饰符（本 SDK 的 AppIntents 接口不暴露 Scene.appIntents）
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .loggedOut:
                LoginView()
                    .transition(.opacity)
            case .connecting:
                ZStack {
                    Theme.canvas.ignoresSafeArea()
                    VStack(spacing: Theme.spaceMD) {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(Theme.accent)
                        Text("连接海尔智家云...")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
                .transition(.opacity)
            case .ready:
                DeviceListView()
                    .transition(.opacity)
            case .error(let message):
                ZStack {
                    Theme.canvas.ignoresSafeArea()
                    VStack(spacing: Theme.spaceMD) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.warning)
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.spaceXL)
                        Button("返回登录") {
                            model.logout()
                        }
                        .buttonStyle(Theme.secondaryButtonStyle())
                        .padding(.top, Theme.spaceXS)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.phase == .ready || model.phase == .loggedOut)
    }
}
