import SwiftUI
import HaierACCore

/// 批量控制面板：对选中的多台设备同时下发同一指令
/// 支持：电源 / 目标温度 / 模式 / 风速（设备支持哪项显示哪项）
struct BatchControlPanel: View {
    @EnvironmentObject var model: AppModel
    /// 选中的设备 ID 列表
    let deviceIds: [String]

    var body: some View {
        let controllableCount = deviceIds.filter { id in
            model.reachability(for: id).isControllable
        }.count
        let isBatchAvailable = controllableCount > 0

        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            HStack {
                Label("批量控制（\(deviceIds.count) 台设备，\(controllableCount) 台就绪）", systemImage: "square.stack.3d.up.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if !model.gatewayConnected {
                    Text("网关重连中")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.warning)
                } else if controllableCount == 0 {
                    Text("所选设备均离线")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.offline)
                }
            }

            if !model.gatewayConnected {
                HStack(spacing: 6) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.warning)
                    Text("网关连接断开，批量下发已暂停")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
            } else if controllableCount < deviceIds.count && controllableCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSubtle)
                    Text("部分设备离线（\(deviceIds.count - controllableCount) 台），指令将自动跳过并仅发给就绪设备")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
            }

            // 汇总首个具备有效属性的设备作为控制模板（杜绝首台设备离线导致属性字典为空白）
            let attrs: [String: DeviceAttribute] = {
                for id in deviceIds {
                    let map = model.attributes[id] ?? [:]
                    if !map.isEmpty { return map }
                }
                return model.attributes[deviceIds.first ?? ""] ?? [:]
            }()

            // 批量一键预设与电源控制 (v1.9.34 集合精确匹配 & 新增所选/全屋开机)
            let allIds = Set(model.allUnifiedDevices.map(\.id))
            let isAllSelected = !allIds.isEmpty && Set(deviceIds) == allIds
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Button {
                        model.applyPreset(deviceIds: deviceIds, mode: .cooling, temperature: 26.0)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 11))
                            Text("清爽 26°C")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.surface2)
                        .foregroundStyle(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.applyPreset(deviceIds: deviceIds, mode: .heating, temperature: 20.0)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                            Text("暖房 20°C")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.surface2)
                        .foregroundStyle(Theme.warning)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.applyPreset(deviceIds: deviceIds, mode: .auto, temperature: 24.0)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                            Text("智能 24°C")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.surface2)
                        .foregroundStyle(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Button {
                        model.applyPreset(deviceIds: deviceIds, mode: .dehumidify, temperature: 24.0)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 11))
                            Text("舒爽除湿")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Theme.surface2)
                        .foregroundStyle(Color.teal)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.applyPreset(deviceIds: deviceIds, mode: .fan, temperature: 26.0)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "wind")
                                .font(.system(size: 11))
                            Text("清新送风")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Theme.surface2)
                        .foregroundStyle(Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Button {
                        model.turnOnDevices(deviceIds: deviceIds)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "power.circle")
                                .font(.system(size: 11))
                            Text(isAllSelected ? "全屋开机" : "所选开机")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.surface2)
                        .foregroundStyle(Theme.success)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.turnOffDevices(deviceIds: deviceIds)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                                .font(.system(size: 11))
                            Text(isAllSelected ? "全屋关机" : "所选关机")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.surface2)
                        .foregroundStyle(Theme.inkMuted)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(!isBatchAvailable)
            .opacity(isBatchAvailable ? 1.0 : 0.6)

            VStack(spacing: 0) {
                if let onOff = attrs["onOffStatus"], onOff.writable {
                    batchToggleRow(title: "电源", icon: "power", attr: onOff)
                    batchDivider
                }
                if let temp = attrs["targetTemperature"], temp.writable, case .step(let min, let max, let step) = temp.valueRange {
                    batchTemperatureRow(attr: temp, min: min, max: max, step: step)
                    batchDivider
                }
                if let mode = attrs["operationMode"], mode.writable, case .list(let opts) = mode.valueRange {
                    batchListRow(title: "模式", icon: "slider.horizontal.3", attr: mode, options: opts)
                    batchDivider
                }
                if let wind = attrs["windSpeed"], wind.writable, case .list(let opts) = wind.valueRange {
                    batchListRow(title: "风速", icon: "fan", attr: wind, options: opts)
                }
            }
            .padding(.horizontal, Theme.spaceMD)
            .padding(.vertical, 6)
            .background(Theme.cardBackground(Theme.surface1))
            .disabled(!isBatchAvailable)
            .opacity(isBatchAvailable ? 1.0 : 0.6)
        }
    }

    private var batchDivider: some View {
        Divider().overlay(Theme.hairline).padding(.vertical, 2)
    }

    /// 布尔开关行（电源等）
    private func batchToggleRow(title: String, icon: String, attr: DeviceAttribute) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
            Spacer()
            Toggle("", isOn: Binding(
                get: { attr.boolValue ?? false },
                set: { on in
                    model.sendAttributeToDevices(attr.name, value: .bool(on), deviceIds: deviceIds)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Theme.accent)
        }
        .padding(.vertical, 7)
    }

    /// 温度行：减 / 当前值 / 加（只调目标温度）
    private func batchTemperatureRow(attr: DeviceAttribute, min: Double, max: Double, step: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 18)
            Text("目标温度")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
            Spacer()
            HStack(spacing: 10) {
                Button {
                    model.adjustTemperature(deviceIds: deviceIds, delta: -step, includeStandby: true)
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
                    model.adjustTemperature(deviceIds: deviceIds, delta: step, includeStandby: true)
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
        .padding(.vertical, 7)
    }

    /// 列表选择行（模式/风速）
    private func batchListRow(title: String, icon: String, attr: DeviceAttribute, options: [ListOption]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
            Spacer()
            Picker("", selection: Binding(
                get: {
                    options.first(where: { $0.data.stringValue == attr.value?.stringValue })?.data.stringValue
                        ?? options.first?.data.stringValue ?? ""
                },
                set: { newValue in
                    guard let opt = options.first(where: { $0.data.stringValue == newValue }) else { return }
                    model.sendAttributeToDevices(attr.name, value: opt.data, deviceIds: deviceIds)
                }
            )) {
                ForEach(options) { opt in
                    Text(opt.desc).tag(opt.data.stringValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Theme.inkMuted)
            .frame(width: 140)
        }
        .padding(.vertical, 6)
    }
}
