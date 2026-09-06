import SwiftUI
import Charts
import HaierACCore

/// 菜单栏控制中心 Bento Popover
/// 遵循 macOS 控制中心规范：毛玻璃材质底衬、Bento 网格模块、状态感知动态强调色与微触感弹簧动效
struct MenuBarControlsView: View {
    @EnvironmentObject var model: AppModel

    /// 当前选中的设备（多设备切换）
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
        VStack(spacing: 10) {
            if let device = currentDevice {
                let attrs = model.attributes[device.id] ?? [:]
                let isPowerOn = model.attribute("onOffStatus", deviceId: device.id)?.boolValue ?? false
                let modeDesc = model.attribute("operationMode", deviceId: device.id)?.value?.stringValue
                let tint = Theme.modeTint(modeDesc: modeDesc, isOn: isPowerOn)
                let modeCat = Theme.modeCategory(modeDesc: modeDesc, isOn: isPowerOn)

                // 1. 顶部状态与设备 Bento
                headerPod(device: device, attrs: attrs, isPowerOn: isPowerOn, modeCat: modeCat, tint: tint)

                // 2. 快捷操作 Bento 矩阵（电源、情景灯光、屏显）
                quickActionsPod(device: device, attrs: attrs, isPowerOn: isPowerOn, tint: tint)

                // 3. 核心温控 Bento 卡片
                temperatureBentoPod(device: device, attrs: attrs, isPowerOn: isPowerOn, tint: tint)

                // 4. 模式与风速分段矩阵
                if isPowerOn {
                    modeAndFanPod(device: device, attrs: attrs, tint: tint)
                }

                // 5. 24小时走势 Sparkline
                sparklinePod(device: device, tint: tint)

                // 6. 分隔线与系统设置
                Divider().overlay(Theme.hairlineSubtle)

                launchAtLoginRow

                Divider().overlay(Theme.hairlineSubtle)

                // 7. 底部导航
                footerView
            } else {
                notLoggedInView
                Divider().overlay(Theme.hairlineSubtle)
                launchAtLoginRow
            }
        }
        .padding(12)
        .frame(width: 316)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLG, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            OperationToast()
                .padding(.top, 4)
        }
    }

    // MARK: - 1. 顶部状态与设备 Bento

    private func headerPod(
        device: DeviceInfo,
        attrs: [String: DeviceAttribute],
        isPowerOn: Bool,
        modeCat: ACModeCategory,
        tint: Color
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // 左侧：空调动态图标 + 设备选择
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.16))
                        .frame(width: 32, height: 32)
                    Image(systemName: isPowerOn ? modeCat.icon : "power")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if activeDevices.count > 1 {
                        Picker("", selection: Binding(
                            get: { currentDevice?.id ?? activeDevices.first?.id ?? "" },
                            set: { id in
                                selectedDeviceId = id
                                model.menuBarDeviceId = id
                            }
                        )) {
                            ForEach(activeDevices) { dev in
                                Text(dev.deviceName).tag(dev.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(Theme.ink)
                        .font(.system(size: 13, weight: .semibold))
                    } else {
                        Text(device.deviceName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(model.gatewayConnected ? (isPowerOn ? Theme.success : Theme.inkTertiary) : Theme.warning)
                            .frame(width: 6, height: 6)
                        Text(model.gatewayConnected ? (isPowerOn ? "\(modeCat.label)中" : "已关机") : "重连中...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
            }

            Spacer()

            // 右侧：室内实时温湿度显示（Status Capsule）
            HStack(spacing: 6) {
                if let attr = AppModel.indoorTemperatureAttribute(in: attrs),
                   let temp = attr.doubleValue {
                    HStack(spacing: 3) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.temperatureColor(celsius: temp))
                        Text(String(format: "%.0f°", temp))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Theme.surface2)
                            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                    )
                }

                if let hum = AppModel.indoorHumidityAttribute(in: attrs),
                   let val = hum.doubleValue {
                    HStack(spacing: 2) {
                        Image(systemName: "humidity.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.blue)
                        Text(String(format: "%.0f%%", val))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Theme.surface1)
                            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - 2. 快捷开关 Bento 矩阵

    private func quickActionsPod(
        device: DeviceInfo,
        attrs: [String: DeviceAttribute],
        isPowerOn: Bool,
        tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            // 电源主开关
            Button {
                withAnimation(Theme.spring) {
                    model.sendAttribute("onOffStatus", value: .bool(!isPowerOn), deviceId: device.id)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .bold))
                    Text(isPowerOn ? "电源开启" : "电源已关")
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(isPowerOn ? Color.white : Theme.inkMuted)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                        .fill(isPowerOn ? tint : Theme.surface2)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                                .strokeBorder(isPowerOn ? tint.opacity(0.4) : Theme.hairline, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            // 情景灯光（若支持）
            if let light = attrs["lightStatus"], light.writable {
                let isLightOn = light.boolValue ?? false
                Button {
                    withAnimation(Theme.spring) {
                        model.sendAttribute("lightStatus", value: .bool(!isLightOn), deviceId: device.id)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isLightOn ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 11, weight: .medium))
                        Text(isLightOn ? "灯光开" : "灯光关")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(isLightOn ? Theme.ink : Theme.inkMuted)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                            .fill(isLightOn ? Theme.surface3 : Theme.surface1)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                                    .strokeBorder(isLightOn ? Theme.accent.opacity(0.4) : Theme.hairline, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 3. 核心温控 Bento 卡片

    @ViewBuilder
    private func temperatureBentoPod(
        device: DeviceInfo,
        attrs: [String: DeviceAttribute],
        isPowerOn: Bool,
        tint: Color
    ) -> some View {
        if let temp = attrs["targetTemperature"], temp.writable,
           case .step(let min, let max, let step) = temp.valueRange {
            let current = temp.doubleValue ?? min

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("目标温度")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.inkSubtle)
                    Text(String(format: "%.1f°C", current))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isPowerOn ? tint : Theme.inkTertiary)
                }

                Spacer()

                // 加减步进胶囊
                HStack(spacing: 12) {
                    Button {
                        let new = Swift.max(min, current - step)
                        withAnimation(Theme.spring) {
                            model.sendAttribute("targetTemperature", value: .double(Theme.roundStep(value: new, step: step)), deviceId: device.id)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(Theme.surface2)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.ink)
                    .disabled(!isPowerOn)

                    Button {
                        let new = Swift.min(max, current + step)
                        withAnimation(Theme.spring) {
                            model.sendAttribute("targetTemperature", value: .double(Theme.roundStep(value: new, step: step)), deviceId: device.id)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(Theme.surface2)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.ink)
                    .disabled(!isPowerOn)
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(Theme.surface1)
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                    .fill(Theme.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                            .strokeBorder(isPowerOn ? tint.opacity(0.3) : Theme.hairline, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - 4. 模式与风速分段矩阵

    @ViewBuilder
    private func modeAndFanPod(
        device: DeviceInfo,
        attrs: [String: DeviceAttribute],
        tint: Color
    ) -> some View {
        VStack(spacing: 8) {
            // 模式选择分段矩阵
            if let mode = attrs["operationMode"], mode.writable, case .list(let opts) = mode.valueRange {
                let currentVal = mode.value?.stringValue ?? ""

                HStack(spacing: 4) {
                    ForEach(opts) { opt in
                        let isSelected = opt.data.stringValue == currentVal
                        let optCat = Theme.modeCategory(modeDesc: opt.desc, isOn: true)

                        Button {
                            withAnimation(Theme.springFast) {
                                model.sendAttribute("operationMode", value: opt.data, deviceId: device.id)
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: optCat.icon)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                                Text(opt.desc)
                                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .foregroundStyle(isSelected ? Color.white : Theme.inkMuted)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                                    .fill(isSelected ? tint : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                        .fill(Theme.surface1)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                )
            }

            // 风速选择分段胶囊
            if let wind = attrs["windSpeed"], wind.writable, case .list(let opts) = wind.valueRange {
                let currentVal = wind.value?.stringValue ?? ""

                HStack(spacing: 4) {
                    Image(systemName: "fan.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                        .frame(width: 14)

                    ForEach(opts) { opt in
                        let isSelected = opt.data.stringValue == currentVal

                        Button {
                            withAnimation(Theme.springFast) {
                                model.sendAttribute("windSpeed", value: opt.data, deviceId: device.id)
                            }
                        } label: {
                            Text(opt.desc)
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .foregroundStyle(isSelected ? Theme.ink : Theme.inkSubtle)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.radiusXS, style: .continuous)
                                        .fill(isSelected ? Theme.surface3 : Color.clear)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.radiusXS, style: .continuous)
                                                .strokeBorder(isSelected ? Theme.hairlineStrong : Color.clear, lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                        .fill(Theme.surface1)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - 5. 24小时走势 Sparkline

    @ViewBuilder
    private func sparklinePod(device: DeviceInfo, tint: Color) -> some View {
        let samples = model.temperatureSeries(deviceId: device.id)
        if samples.count >= 2 {
            let temps = samples.map(\.temperature)
            let minTemp = temps.min() ?? 20
            let maxTemp = temps.max() ?? 26

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("24h 室温趋势")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.inkSubtle)
                    Spacer()
                    Text(String(format: "%.0f° ~ %.0f°", minTemp, maxTemp))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(Theme.inkTertiary)
                }

                Chart(samples) { sample in
                    LineMark(
                        x: .value("时间", sample.timestamp),
                        y: .value("温度", sample.temperature)
                    )
                    .foregroundStyle(tint)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                    AreaMark(
                        x: .value("时间", sample.timestamp),
                        y: .value("温度", sample.temperature)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.24), tint.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 32)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                    .fill(Theme.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - 6. 开机自启行

    private var launchAtLoginRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 16)
            Text("开机自启（常驻菜单栏）")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkMuted)
            Spacer()
            Toggle("", isOn: $model.launchAtLogin)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Theme.accent)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - 7. 底部导航

    private var footerView: some View {
        HStack {
            Button {
                NotificationCenter.default.post(name: .haierOpenMainWindow, object: nil)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11))
                    Text("打开主窗口")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.inkMuted)

            Spacer()

            ThemePickerMenu()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.inkTertiary)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - 未登录态

    private var notLoggedInView: some View {
        VStack(spacing: 10) {
            Image(systemName: "air.conditioner.horizontal")
                .font(.system(size: 24))
                .foregroundStyle(Theme.accent)
            Text(model.phase == .connecting ? "正在恢复云端连接..." : "尚未登录海尔智家")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkMuted)
            Button("打开登录") {
                NotificationCenter.default.post(name: .haierOpenMainWindow, object: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(Theme.primaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
struct MenuBarControlsView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarControlsView()
            .environmentObject(AppModel.shared)
            .frame(width: 316)
            .padding()
            .background(Color.black.opacity(0.2))
    }
}
#endif
