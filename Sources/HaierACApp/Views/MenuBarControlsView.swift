import SwiftUI
import HaierACCore

/// 菜单栏小窗口控制面板（点击菜单栏图标弹出的独立窗口）
struct MenuBarControlsView: View {
    @EnvironmentObject var model: AppModel

    /// 当前选中的设备（支持多设备切换）
    @State private var selectedDeviceId: String?

    private var activeDevices: [DeviceInfo] {
        guard case .ready = model.phase else { return [] }
        return model.devices
    }

    private var currentDevice: DeviceInfo? {
        if let selectedDeviceId, let device = activeDevices.first(where: { $0.id == selectedDeviceId }) {
            return device
        }
        return activeDevices.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let device = currentDevice {
                windowHeader(device)
                if activeDevices.count > 1 {
                    devicePicker
                }
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
        .frame(width: 300)
        .background(Theme.canvas)
        .overlay(alignment: .top) {
            OperationToast()
                .padding(.top, 4)
        }
    }

    // MARK: - 窗口头部（仿控制中心）

    private func windowHeader(_ device: DeviceInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "air.conditioner.horizontal")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.accent)
            Text("海尔空调")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let onOff = model.attribute("onOffStatus", deviceId: device.id), let isOn = onOff.boolValue {
                Text(isOn ? "运行中" : "已关机")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOn ? Theme.success : Theme.inkTertiary)
            }
        }
        .padding(.bottom, 2)
    }

    /// 多设备切换
    private var devicePicker: some View {
        Picker("", selection: Binding(
            get: { currentDevice?.id ?? activeDevices.first?.id ?? "" },
            set: { selectedDeviceId = $0 }
        )) {
            ForEach(activeDevices) { device in
                Text(device.deviceName).tag(device.id)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(Theme.inkMuted)
    }

    // MARK: - 控制区

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
            // 温度步进
            if let temp = model.attribute("targetTemperature", deviceId: device.id), temp.writable,
               case .step(let min, let max, let step) = temp.valueRange {
                MenuBarTemperatureRow(attr: temp, deviceId: device.id, min: min, max: max, step: step)
            }
            // 模式
            if let mode = model.attribute("operationMode", deviceId: device.id), mode.writable,
               case .list(let opts) = mode.valueRange {
                MenuBarModeRow(attr: mode, options: opts, deviceId: device.id)
            }
        }
    }

    // MARK: - 底部

    private var footer: some View {
        HStack {
            Button {
                // NSPopover 环境无 openWindow，通过通知让主窗口侧打开
                NotificationCenter.default.post(name: .haierOpenMainWindow, object: nil)
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
                NotificationCenter.default.post(name: .haierOpenMainWindow, object: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(Theme.primaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - 菜单栏开关行

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

// MARK: - 菜单栏温度行

struct MenuBarTemperatureRow: View {
    @EnvironmentObject var model: AppModel
    let attr: DeviceAttribute
    let deviceId: String
    let min: Double
    let max: Double
    let step: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 16)
            Text(attr.desc)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkMuted)
            Spacer()
            HStack(spacing: 10) {
                Button {
                    let current = attr.doubleValue ?? min
                    let new = Swift.max(min, current - step)
                    model.sendAttribute(attr.name, value: .double((new / step).rounded() * step), deviceId: deviceId)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkMuted)

                Text(String(format: "%.1f°", attr.doubleValue ?? min))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44)

                Button {
                    let current = attr.doubleValue ?? min
                    let new = Swift.min(max, current + step)
                    model.sendAttribute(attr.name, value: .double((new / step).rounded() * step), deviceId: deviceId)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkMuted)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                    .fill(Theme.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - 菜单栏模式行

struct MenuBarModeRow: View {
    @EnvironmentObject var model: AppModel
    let attr: DeviceAttribute
    let options: [ListOption]
    let deviceId: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "fan")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 16)
            Text(attr.desc)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkMuted)
            Spacer()
            Picker("", selection: Binding(
                get: {
                    options.first(where: { $0.data.stringValue == attr.value?.stringValue })?.data.stringValue
                        ?? options.first?.data.stringValue ?? ""
                },
                set: { newValue in
                    guard let opt = options.first(where: { $0.data.stringValue == newValue }) else { return }
                    model.sendAttribute(attr.name, value: opt.data, deviceId: deviceId)
                }
            )) {
                ForEach(options) { opt in
                    Text(opt.desc).tag(opt.data.stringValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Theme.inkMuted)
            .frame(width: 150)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}
