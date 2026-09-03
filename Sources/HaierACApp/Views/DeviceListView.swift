import SwiftUI
import HaierACCore

struct DeviceListView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spaceMD) {
                        // 标题区
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("我的设备")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                    .tracking(-0.6)
                                Text("\(model.devices.count) 台设备 · \(model.gatewayConnected ? "实时连接" : "连接中断")")
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

                        // 设备卡片
                        ForEach(model.devices) { device in
                            NavigationLink(value: device) {
                                DeviceCard(device: device, model: model)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Theme.spaceLG)
                    }
                    .padding(.bottom, Theme.spaceLG)
                }
                .navigationDestination(for: DeviceInfo.self) { device in
                    DeviceControlView(device: device)
                }
            }
        }
    }
}

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
