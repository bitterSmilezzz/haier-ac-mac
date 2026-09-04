import SwiftUI
import HaierACCore

/// 批量控制面板：对选中的多台设备同时下发同一指令
/// 支持：电源 / 目标温度 / 模式 / 风速（设备支持哪项显示哪项）
struct BatchControlPanel: View {
    @EnvironmentObject var model: AppModel
    /// 选中的设备 ID 列表
    let deviceIds: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            HStack {
                Label("批量控制（\(deviceIds.count) 台）", systemImage: "square.stack.3d.up.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }

            // 汇总第一台设备的可写属性作为控制项（同品牌设备属性一致）
            let attrs = model.attributes[deviceIds.first ?? ""] ?? [:]

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
                    let current = attr.doubleValue ?? min
                    let new = Swift.max(min, current - step)
                    model.sendAttributeToDevices(attr.name, value: .double((new / step).rounded() * step), deviceIds: deviceIds)
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
                    model.sendAttributeToDevices(attr.name, value: .double((new / step).rounded() * step), deviceIds: deviceIds)
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
