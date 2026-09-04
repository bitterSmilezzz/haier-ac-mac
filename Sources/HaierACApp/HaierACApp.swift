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

    /// 点击 Dock 图标时恢复主窗口（手动主动点击才显示）
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows {
                if window.title == "海尔空调控制" {
                    window.makeKeyAndOrderFront(nil)
                }
            }
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
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        switch model.phase {
        case .loggedOut:
            LoginView()
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
        case .ready:
            DeviceListView()
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
        }
    }
}
