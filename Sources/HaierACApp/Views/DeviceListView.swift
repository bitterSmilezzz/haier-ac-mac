import SwiftUI
import HaierACCore

struct DeviceListView: View {
    @EnvironmentObject var model: AppModel
    @State private var showManualAdd = false
    @State private var manualDeviceId = ""
    @State private var manualName = ""
    /// 批量选择模式（v1.5）
    @State private var batchMode = false
    @State private var selectedDeviceIds: Set<String> = []

    /// 可批量操作的设备（云端 + 手动）
    private var batchableDevices: [(id: String, name: String)] {
        model.devices.map { (id: $0.id, name: $0.deviceName) } +
        model.manualDevices.map { (id: $0.deviceId, name: $0.name) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spaceMD) {
                        UpdateBanner()
                        header
                        if totalCount == 0 {
                            emptyStateCard
                        }
                        cloudDevicesSection
                        manualDevicesSection
                        SceneSection()
                        ScheduleSection()
                        discoverySection
                        // 批量控制面板：批量模式 + 至少选中一台时显示
                        if batchMode && !selectedDeviceIds.isEmpty {
                            BatchControlPanel(deviceIds: Array(selectedDeviceIds))
                                .padding(.horizontal, Theme.spaceLG)
                        }
                    }
                    .padding(.bottom, Theme.spaceLG)
                }
                .navigationDestination(for: DeviceInfo.self) { device in
                    DeviceControlView(device: device)
                }
                .overlay(alignment: .top) {
                    OperationToast()
                        .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showManualAdd) {
            manualAddSheet
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(batchMode ? "选择设备" : "我的设备")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .tracking(-0.6)
                Text(batchMode ? "已选 \(selectedDeviceIds.count) 台，点击卡片切换选择" : "\(totalCount) 台设备 · \(model.gatewayConnected ? "实时连接" : "连接中断")")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSubtle)
            }
            Spacer()
            if batchMode {
                Button {
                    selectedDeviceIds = []
                    batchMode = false
                } label: {
                    Label("取消", systemImage: "xmark")
                }
                .buttonStyle(Theme.secondaryButtonStyle())
            } else {
                Button {
                    batchMode = true
                } label: {
                    Label("批量控制", systemImage: "square.stack.3d.up.fill")
                }
                .buttonStyle(Theme.secondaryButtonStyle())
                .disabled(batchableDevices.count < 2)
            }
            ThemePickerMenu()
            Button {
                model.logout()
            } label: {
                Label("退出", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(Theme.secondaryButtonStyle())
        }
        .padding(.horizontal, Theme.spaceLG)
        .padding(.top, Theme.spaceMD)
    }

    private var totalCount: Int {
        model.devices.count + model.manualDevices.count
    }

    // MARK: - 云端设备

    @ViewBuilder
    private var cloudDevicesSection: some View {
        if !model.devices.isEmpty {
            VStack(alignment: .leading, spacing: Theme.spaceSM) {
                sectionTitle("云端设备（海尔智家账号）")
                ForEach(model.devices) { device in
                    if batchMode {
                        // 批量模式：点击切换选中
                        DeviceCard(device: device, model: model)
                            .overlay(alignment: .trailing) {
                                checkmarkOverlay(isSelected: selectedDeviceIds.contains(device.id))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(device.id)
                            }
                    } else {
                        NavigationLink(value: device) {
                            DeviceCard(device: device, model: model)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.spaceLG)
        }
    }

    /// 批量选择指示：右上角圆圈勾选
    private func checkmarkOverlay(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Theme.accent : Theme.surface3)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(isSelected ? .clear : Theme.hairline, lineWidth: 1))
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(Theme.spaceMD)
    }

    private func toggleSelection(_ id: String) {
        if selectedDeviceIds.contains(id) {
            selectedDeviceIds.remove(id)
        } else {
            selectedDeviceIds.insert(id)
        }
    }

    /// 无任何设备时的空态引导卡片
    private var emptyStateCard: some View {
        VStack(spacing: Theme.spaceSM) {
            Image(systemName: "air.conditioner.horizontal")
                .font(.system(size: 28))
                .foregroundStyle(Theme.inkTertiary)
            Text("还没有可控制的设备")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Text("账号下暂未发现空调设备。\n可尝试扫描当前 WiFi，或在下方手动输入设备的 deviceId。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spaceLG)
        .padding(.horizontal, Theme.spaceMD)
        .background(Theme.cardBackground(Theme.surface1))
        .padding(.horizontal, Theme.spaceLG)
    }

    // MARK: - 手动设备

    @ViewBuilder
    private var manualDevicesSection: some View {
        if !model.manualDevices.isEmpty {
            VStack(alignment: .leading, spacing: Theme.spaceSM) {
                sectionTitle("手动添加")
                ForEach(model.manualDevices) { manual in
                    HStack(spacing: Theme.spaceMD) {
                        if batchMode {
                            // 批量模式：点击切换选中
                            Button {
                                toggleSelection(manual.deviceId)
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                        .fill(selectedDeviceIds.contains(manual.deviceId) ? Theme.accent : Theme.surface2)
                                        .frame(width: 44, height: 44)
                                    if selectedDeviceIds.contains(manual.deviceId) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    } else {
                                        Image(systemName: "plus.square.on.square")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(Theme.inkSubtle)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                    .fill(Theme.surface2)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "plus.square.on.square")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(manual.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Text(manual.deviceId)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.inkSubtle)
                        }

                        Spacer()

                        Button {
                            Task { await model.addDevice(deviceId: manual.deviceId, name: manual.name) }
                        } label: {
                            Text("设为可控")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.removeManualDevice(manual)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Theme.spaceMD)
                    .background(Theme.cardBackground(Theme.surface1))
                }
            }
            .padding(.horizontal, Theme.spaceLG)
        }
    }

    // MARK: - 发现区

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            sectionTitle("局域网发现（当前 WiFi）")

            HStack(spacing: Theme.spaceSM) {
                Button {
                    Task { await model.discoverDevices() }
                } label: {
                    HStack(spacing: 6) {
                        if model.isDiscovering {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.accent)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 12))
                        }
                        Text(model.isDiscovering ? "扫描中..." : "扫描当前 WiFi 设备")
                    }
                }
                .buttonStyle(Theme.primaryButtonStyle())
                .disabled(model.isDiscovering)

                Button {
                    showManualAdd = true
                } label: {
                    Label("手动添加", systemImage: "plus")
                }
                .buttonStyle(Theme.secondaryButtonStyle())
            }

            if model.isDiscovering {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在广播发现请求，约 3 秒...")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .padding(Theme.spaceMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground(Theme.surface1))
            }

            if !model.discoveredDevices.isEmpty {
                VStack(spacing: Theme.spaceXS) {
                    ForEach(model.discoveredDevices) { device in
                        DiscoveredDeviceRow(device: device)
                    }
                }
                .padding(Theme.spaceMD)
                .background(Theme.cardBackground(Theme.surface1))
            } else if !model.isDiscovering && model.phase == .ready {
                Text("点击「扫描当前 WiFi 设备」查找同一网络下的海尔/统帅设备。\n提示：部分设备型号不支持局域网发现，可改用「手动添加」输入设备 ID。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(Theme.spaceMD)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.cardBackground(Theme.surface1))
            }
        }
        .padding(.horizontal, Theme.spaceLG)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.inkSubtle)
            .tracking(0.4)
    }

    // MARK: - 手动添加弹窗

    private var manualAddSheet: some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            Text("手动添加设备")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("输入设备的 deviceId（可在海尔智家 App 设备详情或扫描结果中查看）")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)

            TextField("deviceId（必填）", text: $manualDeviceId)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )

            TextField("设备名称（可选）", text: $manualName)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("取消") {
                    showManualAdd = false
                }
                .buttonStyle(Theme.secondaryButtonStyle())
                Button("添加") {
                    let id = manualDeviceId
                    let name = manualName
                    manualDeviceId = ""
                    manualName = ""
                    showManualAdd = false
                    Task { await model.addDevice(deviceId: id, name: name) }
                }
                .buttonStyle(Theme.primaryButtonStyle())
                .disabled(manualDeviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Theme.spaceLG)
        .frame(width: 380)
        .background(Theme.canvas)
    }
}

/// 发现到的设备行
struct DiscoveredDeviceRow: View {
    @EnvironmentObject var model: AppModel
    let device: DiscoveredDevice
    @State private var added = false

    private var isInList: Bool {
        model.devices.contains { $0.id == device.deviceId } ||
        model.manualDevices.contains { $0.deviceId == device.deviceId }
    }

    var body: some View {
        HStack(spacing: Theme.spaceSM) {
            Image(systemName: "wifi")
                .font(.system(size: 13))
                .foregroundStyle(Theme.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceId ?? "未知设备")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("\(device.ip)\(device.mac.isEmpty ? "" : " · \(device.mac)")")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.inkSubtle)
            }

            Spacer()

            if isInList {
                Text("已添加")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.success)
            } else {
                Button {
                    let id = device.deviceId ?? device.ip
                    let name = device.deviceId ?? device.ip
                    added = true
                    Task { await model.addDevice(deviceId: id, name: name) }
                } label: {
                    Text("添加")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(added)
            }
        }
        .padding(.vertical, 6)
    }
}

/// 云端设备卡片
struct DeviceCard: View {
    let device: DeviceInfo
    @ObservedObject var model: AppModel
    @State private var isHovering = false

    private var isOn: Bool? {
        model.attribute("onOffStatus", deviceId: device.id)?.boolValue
    }

    /// 当前室内温度（无数据时 nil）
    private var indoorTemp: Double? {
        guard let attr = AppModel.indoorTemperatureAttribute(in: model.attributes[device.id] ?? [:]) else { return nil }
        return attr.doubleValue
    }

    var body: some View {
        HStack(spacing: Theme.spaceMD) {
            // 状态图标
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                    .fill(isHovering ? Theme.accent.opacity(0.14) : Theme.surface2)
                    .frame(width: 44, height: 44)
                Image(systemName: "air.conditioner.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isHovering ? Theme.accentHover : Theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(device.deviceName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(device.productNameT ?? device.deviceType ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSubtle)
                    .lineLimit(1)
            }

            Spacer()

            // 当前室内温度（大字，感知最强的信息）
            if let temp = indoorTemp {
                HStack(spacing: 2) {
                    Text(String(format: "%.0f", temp))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("°")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.bottom, 6)
                }
            }

            // 状态徽标
            if let isOn {
                Text(isOn ? "开机" : "关机")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOn ? Theme.success : Theme.inkTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Theme.surface2)
                            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                    )
            }

            Circle()
                .fill(device.online ? Theme.success : Theme.inkTertiary)
                .frame(width: 8, height: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHovering ? Theme.accentHover : Theme.inkTertiary)
        }
        .padding(Theme.spaceMD)
        .background(Theme.cardBackground(Theme.surface1))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLG, style: .continuous)
                .strokeBorder(isHovering ? Theme.accent.opacity(0.55) : .clear, lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.008 : 1)
        .shadow(color: isHovering ? .black.opacity(0.12) : .clear, radius: 6, y: 2)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
