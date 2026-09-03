import SwiftUI
import HaierACCore

/// 菜单栏迷你控制面板（类似控制中心卡片）
struct MenuBarControlsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private var activeDevice: DeviceInfo? {
        guard case .ready = model.phase else { return nil }
        return model.devices.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let device = activeDevice {
                deviceHeader(device)
                controlRows(device)
                Divider().overlay(Theme.hairline)
                launchAtLoginRow
                Divider().overlay(Theme.hairline)
                footer
            } else {
                notLoggedIn
                Divider().overlay(Theme.hairline)
                launchAtLoginRow
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(Theme.canvas)
    }

    // MARK: - 开机自启

    private var launchAtLoginRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 16)
            Text("开机自启（菜单栏常驻）")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkMuted)
            Spacer()
            Toggle("", isOn: $model.launchAtLogin)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Theme.accent)
        }
    }

    // MARK: - 设备头部

    private func deviceHeader(_ device: DeviceInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "air.conditioner.horizontal")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.accent)
            Text(device.deviceName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let onOff = model.attribute("onOffStatus", deviceId: device.id), let isOn = onOff.boolValue {
                Text(isOn ? "运行中" : "已关机")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOn ? Theme.success : Theme.inkTertiary)
            }
        }
    }

    // MARK: - 控制行

    @ViewBuilder
    private func controlRows(_ device: DeviceInfo) -> some View {
        VStack(spacing: 8) {
            // 情景灯光（主开关，置顶）
            if let light = model.attribute("lightStatus", deviceId: device.id), light.writable {
                MenuBarToggleRow(attr: light, deviceId: device.id, emphasized: true)
            }
            // 屏显
            if let screen = model.attribute("screenDisplayStatus", deviceId: device.id), screen.writable {
                MenuBarToggleRow(attr: screen, deviceId: device.id)
            }
            // 电源
            if let onOff = model.attribute("onOffStatus", deviceId: device.id), onOff.writable {
                MenuBarToggleRow(attr: onOff, deviceId: device.id)
            }
            // 温度
            if let temp = model.attribute("targetTemperature", deviceId: device.id), let value = temp.doubleValue {
                HStack {
                    Text("目标温度")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkMuted)
                    Spacer()
                    Text(String(format: "%.1f°C", value))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    // MARK: - 底部

    private var footer: some View {
        HStack {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("打开主窗口", systemImage: "macwindow")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.inkMuted)

            Spacer()

            ThemePickerMenu()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.inkTertiary)
        }
    }

    // MARK: - 未登录态

    private var notLoggedIn: some View {
        VStack(spacing: 10) {
            Image(systemName: "snowflake")
                .font(.system(size: 20))
                .foregroundStyle(Theme.inkTertiary)
            Text(model.phase == .connecting ? "连接中..." : "尚未登录")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkMuted)
            Button("打开应用登录") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(Theme.primaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// 菜单栏开关行
struct MenuBarToggleRow: View {
    @EnvironmentObject var model: AppModel
    let attr: DeviceAttribute
    let deviceId: String
    var emphasized: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: emphasized ? "lightbulb.fill" : (attr.name == "onOffStatus" ? "power" : "display"))
                .font(.system(size: 12))
                .foregroundStyle(emphasized ? Theme.accentHover : Theme.inkSubtle)
                .frame(width: 16)
            Text(attr.desc)
                .font(.system(size: 13, weight: emphasized ? .medium : .regular))
                .foregroundStyle(emphasized ? Theme.ink : Theme.inkMuted)
            Spacer()
            Toggle("", isOn: Binding(
                get: { attr.boolValue ?? false },
                set: { on in
                    model.sendAttribute(attr.name, value: .bool(on), deviceId: deviceId)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Theme.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                .fill(emphasized ? Theme.surface2 : Theme.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                        .strokeBorder(emphasized ? Theme.accent.opacity(0.4) : Theme.hairline, lineWidth: 1)
                )
        )
    }
}
