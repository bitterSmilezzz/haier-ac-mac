import SwiftUI
import HaierACCore

@main
struct HaierACApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("海尔空调控制", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 520, minHeight: 640)
                .preferredColorScheme(model.themeMode.colorScheme)
                .task {
                    model.restoreSession()
                }
        }
        .windowResizability(.contentMinSize)

        // 菜单栏迷你控制面板（点击菜单栏图标弹出）
        MenuBarExtra {
            MenuBarControlsView()
                .environmentObject(model)
                .preferredColorScheme(model.themeMode.colorScheme)
        } label: {
            Label("海尔空调", systemImage: "air.conditioner.horizontal")
        }
        .menuBarExtraStyle(.window)
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
