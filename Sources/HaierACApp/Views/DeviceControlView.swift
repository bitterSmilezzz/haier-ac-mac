import SwiftUI
import Charts
import HaierACCore

struct DeviceControlView: View {
    @EnvironmentObject var model: AppModel
    let device: DeviceInfo

    private var attrs: [String: DeviceAttribute] {
        model.attributes[device.id] ?? [:]
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            if attrs.isEmpty {
                // 数字模型未加载/加载失败时的空态
                VStack(spacing: Theme.spaceMD) {
                    if !model.gatewayConnected {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 30))
                            .foregroundStyle(Theme.warning)
                        Text("连接中断，自动重连中...")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSubtle)
                    } else {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(Theme.accent)
                        Text("正在获取设备状态...")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSubtle)
                        Text("若长时间无响应，请返回设备列表重试")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spaceLG) {
                        // 头部信息
                        header

                        // 实时状态胶囊（室内温度/模式/风速）
                        statusPills

                        // 灯光/显示区（强调卡片）
                        lightSection

                        // 常用控制
                        commonSection

                        // 温度趋势（24h 历史曲线）
                        temperatureTrendSection

                        // 全部可写属性
                        allWritableSection
                    }
                    .padding(Theme.spaceLG)
                }
            }
        }
        .navigationTitle(device.deviceName)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: Theme.spaceSM) {
            Circle()
                .fill(model.gatewayConnected ? Theme.success : Theme.warning)
                .frame(width: 8, height: 8)
            Text(model.gatewayConnected ? "实时连接已建立" : "连接中断，自动重连中...")
                .font(.system(size: 12))
                .foregroundStyle(model.gatewayConnected ? Theme.inkMuted : Theme.warning)
            Spacer()
            Text(device.productNameT ?? "")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkTertiary)
        }
    }

    /// 实时状态胶囊行：室内温度 / 模式 / 风速（只读，直观展示当前状态）
    private var statusPills: some View {
        HStack(spacing: Theme.spaceSM) {
            // 室内温度（大字突出）
            if let attr = AppModel.indoorTemperatureAttribute(in: attrs),
               let temp = attr.doubleValue {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accentHover)
                    Text(String(format: "%.0f°", temp))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("室内")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .padding(.horizontal, Theme.spaceSM)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Theme.surface2)
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                )
            }

            // 运行模式
            if let mode = attrs["operationMode"],
               case .list(let opts) = mode.valueRange,
               let current = mode.value?.stringValue,
               let opt = opts.first(where: { $0.data.stringValue == current }) {
                statusPill(icon: "slider.horizontal.3", text: opt.desc)
            }

            // 风速
            if let wind = attrs["windSpeed"],
               case .list(let opts) = wind.valueRange,
               let current = wind.value?.stringValue,
               let opt = opts.first(where: { $0.data.stringValue == current }) {
                statusPill(icon: "fan", text: opt.desc)
            }

            Spacer()
        }
    }

    private func statusPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSubtle)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Theme.surface1)
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        )
    }

    // MARK: - 灯光区（置顶强调）

    @ViewBuilder
    private var lightSection: some View {
        let lightAttrs = attrs.values
            .filter { $0.writable && $0.isLightRelated }
            .sorted { a, b in
                let pa = a.name == "lightStatus" ? 0 : 1
                let pb = b.name == "lightStatus" ? 0 : 1
                if pa != pb { return pa < pb }
                return a.desc < b.desc
            }

        if !lightAttrs.isEmpty {
            VStack(alignment: .leading, spacing: Theme.spaceMD) {
                Text("灯光 / 显示")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)
                    .tracking(0.4)

                if let light = lightAttrs.first(where: { $0.name == "lightStatus" }) {
                    // 主灯光开关：大开关卡片
                    LightHeroCard(attr: light, deviceId: device.id)
                }

                ForEach(lightAttrs.filter { $0.name != "lightStatus" }) { attr in
                    BinarySwitchRow(attr: attr, deviceId: device.id)
                        .padding(.horizontal, Theme.spaceMD)
                        .padding(.vertical, 10)
                        .background(Theme.cardBackground(Theme.surface1))
                }
            }
        }
    }

    // MARK: - 常用控制

    @ViewBuilder
    private var commonSection: some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            Text("常用控制")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.inkSubtle)
                .tracking(0.4)

            VStack(spacing: 0) {
                if let onOff = attrs["onOffStatus"], onOff.writable {
                    BinarySwitchRow(attr: onOff, deviceId: device.id)
                    rowDivider
                }
                if let temp = attrs["targetTemperature"], temp.writable, case .step(let min, let max, let step) = temp.valueRange {
                    TemperatureRow(attr: temp, deviceId: device.id, min: min, max: max, step: step)
                    rowDivider
                }
                if let mode = attrs["operationMode"], mode.writable, case .list(let opts) = mode.valueRange {
                    ListPickerRow(attr: mode, options: opts, deviceId: device.id)
                    rowDivider
                }
                if let wind = attrs["windSpeed"], wind.writable, case .list(let opts) = wind.valueRange {
                    ListPickerRow(attr: wind, options: opts, deviceId: device.id)
                }
            }
            .padding(.horizontal, Theme.spaceMD)
            .padding(.vertical, 6)
            .background(Theme.cardBackground(Theme.surface1))
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Theme.hairline)
            .padding(.vertical, 2)
    }

    // MARK: - 温度趋势（24h 曲线）

    @ViewBuilder
    private var temperatureTrendSection: some View {
        let samples = model.temperatureSeries(deviceId: device.id)
        if samples.count >= 2 {
            VStack(alignment: .leading, spacing: Theme.spaceMD) {
                HStack {
                    Text("温度趋势（最近 24 小时）")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.inkSubtle)
                        .tracking(0.4)
                    Spacer()
                    // 极值摘要
                    if let min = samples.map(\.temperature).min(),
                       let max = samples.map(\.temperature).max() {
                        Text(String(format: "%.0f° ~ %.0f°", min, max))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }

                Chart(samples) { sample in
                    LineMark(
                        x: .value("时间", sample.timestamp),
                        y: .value("温度", sample.temperature)
                    )
                    .foregroundStyle(Theme.accent)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("时间", sample.timestamp),
                        y: .value("温度", sample.temperature)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.25), Theme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f°", v))
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.inkTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.hour())
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.inkTertiary)
                            }
                        }
                    }
                }
                .frame(height: 130)
            }
            .padding(Theme.spaceMD)
            .background(Theme.cardBackground(Theme.surface1))
        }
    }

    // MARK: - 全部可写属性

    @ViewBuilder
    private var allWritableSection: some View {
        let lightNames = Set(attrs.values.filter { $0.isLightRelated }.map(\.name))
        let commonNames: Set<String> = ["onOffStatus", "targetTemperature", "operationMode", "windSpeed"]
        let rest = attrs.values
            .filter { $0.writable && !lightNames.contains($0.name) && !commonNames.contains($0.name) }
            .sorted { $0.desc < $1.desc }

        if !rest.isEmpty {
            VStack(alignment: .leading, spacing: Theme.spaceMD) {
                Text("其他设置（\(rest.count)）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)
                    .tracking(0.4)

                VStack(spacing: 0) {
                    ForEach(Array(rest.enumerated()), id: \.element.id) { index, attr in
                        Group {
                            switch attr.valueRange {
                            case .list(let opts):
                                if attr.isBinarySwitch {
                                    BinarySwitchRow(attr: attr, deviceId: device.id)
                                } else {
                                    ListPickerRow(attr: attr, options: opts, deviceId: device.id)
                                }
                            case .step(let min, let max, let step):
                                if attr.name.lowercased().contains("temp") || attr.name.lowercased().contains("humidity") {
                                    TemperatureRow(attr: attr, deviceId: device.id, min: min, max: max, step: step)
                                } else {
                                    StepSliderRow(attr: attr, deviceId: device.id, min: min, max: max, step: step)
                                }
                            case .none:
                                HStack {
                                    Text(attr.desc)
                                        .foregroundStyle(Theme.inkMuted)
                                    Spacer()
                                    Text(attr.value?.stringValue ?? "-")
                                        .foregroundStyle(Theme.inkSubtle)
                                }
                            }
                        }
                        if index < rest.count - 1 {
                            rowDivider
                        }
                    }
                }
                .padding(.horizontal, Theme.spaceMD)
                .padding(.vertical, 6)
                .background(Theme.cardBackground(Theme.surface1))
            }
        }
    }
}

// MARK: - 主灯光开关大卡片

struct LightHeroCard: View {
    @EnvironmentObject var model: AppModel
    let attr: DeviceAttribute
    let deviceId: String

    private var isOn: Bool {
        attr.boolValue ?? false
    }

    var body: some View {
        HStack(spacing: Theme.spaceMD) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusLG, style: .continuous)
                    .fill(isOn ? Theme.accent : Theme.surface3)
                    .frame(width: 56, height: 56)
                Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isOn ? .white : Theme.inkSubtle)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(attr.desc)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(isOn ? "空调机身灯光已开启" : "空调机身灯光已关闭")
                    .font(.system(size: 12))
                    .foregroundStyle(isOn ? Theme.accentHover : Theme.inkSubtle)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { on in
                    model.sendAttribute(attr.name, value: .bool(on), deviceId: deviceId)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Theme.accent)
            .scaleEffect(1.3)
            .padding(.trailing, 4)
        }
        .padding(Theme.spaceLG)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusLG, style: .continuous)
                .fill(Theme.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusLG, style: .continuous)
                        .strokeBorder(isOn ? Theme.accent.opacity(0.5) : Theme.hairline, lineWidth: 1)
                )
        )
    }
}

// MARK: - 行组件

/// 开关行（2 值 LIST 属性）
struct BinarySwitchRow: View {
    @EnvironmentObject var model: AppModel
    let attr: DeviceAttribute
    let deviceId: String

    var body: some View {
        HStack {
            Text(attr.desc)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
            Spacer()
            Toggle("", isOn: Binding(
                get: { attr.boolValue ?? false },
                set: { on in
                    model.sendAttribute(attr.name, value: .bool(on), deviceId: deviceId)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Theme.accent)
        }
        .padding(.vertical, 8)
    }
}

/// LIST 属性选择器
struct ListPickerRow: View {
    @EnvironmentObject var model: AppModel
    let attr: DeviceAttribute
    let options: [ListOption]
    let deviceId: String

    var body: some View {
        HStack {
            Text(attr.desc)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
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
            .frame(maxWidth: 200)
            .tint(Theme.inkMuted)
        }
        .padding(.vertical, 8)
    }
}

/// STEP 温度行
struct TemperatureRow: View {
    @EnvironmentObject var model: AppModel
    let attr: DeviceAttribute
    let deviceId: String
    let min: Double
    let max: Double
    let step: Double

    var body: some View {
        HStack {
            Text(attr.desc)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
            Spacer()
            Stepper(value: Binding(
                get: { attr.doubleValue ?? min },
                set: { newValue in
                    let rounded = (newValue / step).rounded() * step
                    model.sendAttribute(attr.name, value: .double(rounded), deviceId: deviceId)
                }
            ), in: min...max, step: step) {
                Text(String(format: "%.1f°C", attr.doubleValue ?? min))
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .frame(width: 80, alignment: .trailing)
            }
            .frame(maxWidth: 280)
        }
        .padding(.vertical, 8)
    }
}

/// STEP 数值滑块
struct StepSliderRow: View {
    @EnvironmentObject var model: AppModel
    let attr: DeviceAttribute
    let deviceId: String
    let min: Double
    let max: Double
    let step: Double

    var body: some View {
        HStack {
            Text(attr.desc)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
            Spacer()
            Slider(value: Binding(
                get: { attr.doubleValue ?? min },
                set: { newValue in
                    let rounded = (newValue / step).rounded() * step
                    model.sendAttribute(attr.name, value: .double(rounded), deviceId: deviceId)
                }
            ), in: min...max, step: step)
            .tint(Theme.accent)
            .frame(maxWidth: 160)
            Text(attr.value?.stringValue ?? "-")
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(Theme.inkMuted)
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}
