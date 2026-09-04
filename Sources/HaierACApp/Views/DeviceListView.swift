import SwiftUI
import HaierACCore

struct DeviceListView: View {
    @EnvironmentObject var model: AppModel
    @State private var showManualAdd = false
    @State private var manualDeviceId = ""
    @State private var manualName = ""

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
                        discoverySection
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
                Text("我的设备")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .tracking(-0.6)
                Text("\(totalCount) 台设备 · \(model.gatewayConnected ? "实时连接" : "连接中断")")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSubtle)
            }
            Spacer()
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
                    NavigationLink(value: device) {
                        DeviceCard(device: device, model: model)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.spaceLG)
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
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                .fill(Theme.surface2)
                                .frame(width: 44, height: 44)
                            Image(systemName: "plus.square.on.square")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.inkSubtle)
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

    private var isOn: Bool? {
        model.attribute("onOffStatus", deviceId: device.id)?.boolValue
    }

    var body: some View {
        HStack(spacing: Theme.spaceMD) {
            // 状态图标
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                    .fill(Theme.surface2)
                    .frame(width: 44, height: 44)
                Image(systemName: "air.conditioner.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.accent)
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
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(Theme.spaceMD)
        .background(Theme.cardBackground(Theme.surface1))
    }
}
