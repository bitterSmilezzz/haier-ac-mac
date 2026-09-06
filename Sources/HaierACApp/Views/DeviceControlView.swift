import SwiftUI
import Charts
import HaierACCore

/// 主窗口核心设备控制面板
/// 融合 macOS Vibrant Material 与 Linear 设计体系：
/// 1. 顶部环境遥测状态胶囊（Status Capsules）
/// 2. 居中大字阶 Temperature Pod 温控卡片
/// 3. 24h 平滑 Area Trend 曲线（含实时温度光标点）
/// 4. 模式与风速分段矩阵
/// 5. 次级属性与扩展控制
struct DeviceControlView: View {
    @EnvironmentObject var model: AppModel
    let device: DeviceInfo

    /// 分类抽屉展开状态
    @State private var expandedGroupIds: Set<String> = ["wind", "health"]
    /// 实时温度脉冲动效
    @State private var beaconPulsing = false

    private var attrs: [String: DeviceAttribute] {
        model.attributes[device.id] ?? [:]
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            if attrs.isEmpty {
                emptyStateView
            } else {
                let isPowerOn = model.attribute("onOffStatus", deviceId: device.id)?.boolValue ?? false
                let modeDesc = model.attribute("operationMode", deviceId: device.id)?.value?.stringValue
                let tint = Theme.modeTint(modeDesc: modeDesc, isOn: isPowerOn)
                let modeCat = Theme.modeCategory(modeDesc: modeDesc, isOn: isPowerOn)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spaceLG) {
                        // 1. 顶部连接与环境遥测胶囊
                        headerAndStatusCapsules(isPowerOn: isPowerOn, modeCat: modeCat, tint: tint)

                        // 2. 核心 Temperature Pod
                        temperatureHeroPod(isPowerOn: isPowerOn, modeCat: modeCat, tint: tint)

                        // 3. 运行模式与风速选择矩阵
                        if isPowerOn {
                            modeAndFanSection(tint: tint)
                        }

                        // 4. 灯光与快控 Bento 行
                        quickControlsSection(isPowerOn: isPowerOn, tint: tint)

                        // 5. 24 小时温度趋势 Area Trend
                        temperatureTrendSection(tint: tint)

                        // 6. 全部扩展可写属性
                        allWritableSection
                    }
                    .padding(Theme.spaceLG)
                }
            }
        }
        .navigationTitle(device.deviceName)
    }

    // MARK: - 1. 顶部环境遥测状态胶囊

    private func headerAndStatusCapsules(isPowerOn: Bool, modeCat: ACModeCategory, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            // 设备型号与连接状态
            HStack(spacing: Theme.spaceSM) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.gatewayConnected ? (isPowerOn ? Theme.success : Theme.inkTertiary) : Theme.warning)
                        .frame(width: 8, height: 8)
                    Text(model.gatewayConnected ? (isPowerOn ? "实时网关连接建立" : "空调已关机") : "网关重连中...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(model.gatewayConnected ? Theme.inkMuted : Theme.warning)
                }

                Spacer()

                if let modelName = device.productNameT, !modelName.isEmpty {
                    Text(modelName)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }

            // 状态胶囊组
            HStack(spacing: Theme.spaceSM) {
                // 室内温度胶囊（高亮重点）
                if let attr = AppModel.indoorTemperatureAttribute(in: attrs),
                   let temp = attr.doubleValue {
                    HStack(spacing: 5) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.temperatureColor(celsius: temp))
                        Text(String(format: "室内 %.0f°", temp))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Theme.surface2)
                            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                    )
                }

                // 室内湿度胶囊
                if let hum = AppModel.indoorHumidityAttribute(in: attrs),
                   let value = hum.doubleValue {
                    statusCapsule(icon: "humidity.fill", text: String(format: "湿度 %.0f%%", value), tint: Color.blue)
                }

                // 当前运行模式胶囊
                if let mode = attrs["operationMode"],
                   case .list(let opts) = mode.valueRange,
                   let current = mode.value?.stringValue,
                   let opt = opts.first(where: { $0.data.stringValue == current }) {
                    statusCapsule(icon: modeCat.icon, text: opt.desc, tint: tint)
                }

                // 当前风速胶囊
                if let wind = attrs["windSpeed"],
                   case .list(let opts) = wind.valueRange,
                   let current = wind.value?.stringValue,
                   let opt = opts.first(where: { $0.data.stringValue == current }) {
                    statusCapsule(icon: "fan", text: opt.desc, tint: Theme.inkMuted)
                }

                Spacer()
            }
        }
    }

    private func statusCapsule(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12, weight: .medium))
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

    // MARK: - 2. 核心 Temperature Pod

    @ViewBuilder
    private func temperatureHeroPod(isPowerOn: Bool, modeCat: ACModeCategory, tint: Color) -> some View {
        if let temp = attrs["targetTemperature"], temp.writable,
           case .step(let min, let max, let step) = temp.valueRange {
            let current = temp.doubleValue ?? min

            HStack(alignment: .center) {
                // 左侧：状态与巨幅温度读数
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("目标温度")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.inkSubtle)

                        Text(isPowerOn ? "· \(modeCat.label)中" : "· 关机中")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isPowerOn ? tint : Theme.inkTertiary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", current))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isPowerOn ? tint : Theme.inkTertiary)

                        Text("°C")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }

                Spacer()

                // 右侧：大触感 Stepper 胶囊
                HStack(spacing: 16) {
                    Button {
                        let new = Swift.max(min, current - step)
                        withAnimation(Theme.spring) {
                            model.sendAttribute(temp.name, value: .double(Theme.roundStep(value: new, step: step)), deviceId: device.id)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(Theme.surface3)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.ink)
                    .disabled(!isPowerOn)

                    Button {
                        let new = Swift.min(max, current + step)
                        withAnimation(Theme.spring) {
                            model.sendAttribute(temp.name, value: .double(Theme.roundStep(value: new, step: step)), deviceId: device.id)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(Theme.surface3)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.ink)
                    .disabled(!isPowerOn)
                }
                .padding(5)
                .background(
                    Capsule()
                        .fill(Theme.surface2)
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                )
            }
            .padding(Theme.spaceLG)
            .background(Theme.bentoCardBackground(radius: Theme.radiusLG, tint: isPowerOn ? tint : nil))
        }
    }

    // MARK: - 3. 运行模式与风速选择矩阵

    private func modeAndFanSection(tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            Text("模式与风速")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.inkSubtle)
                .tracking(0.4)

            VStack(spacing: Theme.spaceSM) {
                // 运行模式选择矩阵
                if let mode = attrs["operationMode"], mode.writable, case .list(let opts) = mode.valueRange {
                    let currentVal = mode.value?.stringValue ?? ""

                    HStack(spacing: 8) {
                        ForEach(opts) { opt in
                            let isSelected = opt.data.stringValue == currentVal
                            let optCat = Theme.modeCategory(modeDesc: opt.desc, isOn: true)

                            Button {
                                withAnimation(Theme.springFast) {
                                    model.sendAttribute("operationMode", value: opt.data, deviceId: device.id)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: optCat.icon)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    Text(opt.desc)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(isSelected ? Color.white : Theme.inkMuted)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                        .fill(isSelected ? tint : Theme.surface2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                                .strokeBorder(isSelected ? tint.opacity(0.4) : Theme.hairline, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 风速分段选择
                if let wind = attrs["windSpeed"], wind.writable, case .list(let opts) = wind.valueRange {
                    let currentVal = wind.value?.stringValue ?? ""

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "fan.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.inkSubtle)
                            Text("风速")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.inkSubtle)
                        }
                        .frame(width: 50, alignment: .leading)

                        HStack(spacing: 4) {
                            ForEach(opts) { opt in
                                let isSelected = opt.data.stringValue == currentVal

                                Button {
                                    withAnimation(Theme.springFast) {
                                        model.sendAttribute("windSpeed", value: opt.data, deviceId: device.id)
                                    }
                                } label: {
                                    Text(opt.desc)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .foregroundStyle(isSelected ? Theme.ink : Theme.inkSubtle)
                                        .background(
                                            RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                                                .fill(isSelected ? Theme.surface3 : Color.clear)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                                                        .strokeBorder(isSelected ? Theme.hairlineStrong : Color.clear, lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(3)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                .fill(Theme.surface2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                        .strokeBorder(Theme.hairline, lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(Theme.spaceMD)
            .background(Theme.bentoCardBackground(radius: Theme.radiusMD))
        }
    }

    // MARK: - 4. 灯光与快控 Bento 行

    private func quickControlsSection(isPowerOn: Bool, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            Text("开关与灯光")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.inkSubtle)
                .tracking(0.4)

            HStack(spacing: Theme.spaceMD) {
                // 主电源控制卡片
                if let onOff = attrs["onOffStatus"], onOff.writable {
                    HStack(spacing: Theme.spaceMD) {
                        ZStack {
                            Circle()
                                .fill(isPowerOn ? tint : Theme.surface3)
                                .frame(width: 44, height: 44)
                            Image(systemName: "power")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(isPowerOn ? Color.white : Theme.inkSubtle)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("空调电源")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(isPowerOn ? "运行正常" : "已待机关机")
                                .font(.system(size: 11))
                                .foregroundStyle(isPowerOn ? Theme.success : Theme.inkSubtle)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { isPowerOn },
                            set: { on in
                                withAnimation(Theme.spring) {
                                    model.sendAttribute(onOff.name, value: .bool(on), deviceId: device.id)
                                }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(tint)
                    }
                    .padding(Theme.spaceMD)
                    .background(Theme.bentoCardBackground(radius: Theme.radiusLG, tint: isPowerOn ? tint : nil))
                }

                // 机身情景灯光控制卡片
                if let light = attrs["lightStatus"], light.writable {
                    let isLightOn = light.boolValue ?? false
                    HStack(spacing: Theme.spaceMD) {
                        ZStack {
                            Circle()
                                .fill(isLightOn ? Theme.accent : Theme.surface3)
                                .frame(width: 44, height: 44)
                            Image(systemName: isLightOn ? "lightbulb.fill" : "lightbulb")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(isLightOn ? Color.white : Theme.inkSubtle)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("机身屏显灯光")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(isLightOn ? "面板已常亮" : "面板已休眠")
                                .font(.system(size: 11))
                                .foregroundStyle(isLightOn ? Theme.accentHover : Theme.inkSubtle)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { isLightOn },
                            set: { on in
                                withAnimation(Theme.spring) {
                                    model.sendAttribute(light.name, value: .bool(on), deviceId: device.id)
                                }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Theme.accent)
                    }
                    .padding(Theme.spaceMD)
                    .background(Theme.bentoCardBackground(radius: Theme.radiusLG, tint: isLightOn ? Theme.accent : nil))
                }
            }
        }
    }

    // MARK: - 5. 24 小时温度趋势 Area Trend

    @ViewBuilder
    private func temperatureTrendSection(tint: Color) -> some View {
        let samples = model.temperatureSeries(deviceId: device.id)
        if samples.count >= 2 {
            let temps = samples.map(\.temperature)
            let minTemp = temps.min() ?? 16
            let maxTemp = temps.max() ?? 30
            let latestSample = samples.last

            VStack(alignment: .leading, spacing: Theme.spaceMD) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 13))
                            .foregroundStyle(tint)
                        Text("24 小时室温趋势（Area Trend）")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }

                    Spacer()

                    // 极值与实时读数
                    HStack(spacing: 8) {
                        if let latest = latestSample {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(tint)
                                    .frame(width: 6, height: 6)
                                Text(String(format: "当前 %.1f°", latest.temperature))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(tint)
                            }
                        }

                        Text(String(format: "最低 %.0f° / 最高 %.0f°", minTemp, maxTemp))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }

                Chart {
                    ForEach(samples) { sample in
                        LineMark(
                            x: .value("时间", sample.timestamp),
                            y: .value("温度", sample.temperature)
                        )
                        .foregroundStyle(tint)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("时间", sample.timestamp),
                            y: .value("温度", sample.temperature)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tint.opacity(0.28), tint.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // 实时温度脉冲点（符合 Spec L21: pulsing live-temperature beacon）
                    if let latest = latestSample {
                        PointMark(
                            x: .value("时间", latest.timestamp),
                            y: .value("温度", latest.temperature)
                        )
                        .foregroundStyle(tint)
                        .symbolSize(beaconPulsing ? 64 : 28)
                        .opacity(beaconPulsing ? 0.7 : 1.0)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f°", v))
                                    .font(.system(size: 10))
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
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.inkTertiary)
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
            .padding(Theme.spaceMD)
            .background(Theme.bentoCardBackground(radius: Theme.radiusMD))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    beaconPulsing = true
                }
            }
        }
    }

    // MARK: - 6. 全部扩展可写属性（分类折叠 Bento 抽屉）

    @ViewBuilder
    private var allWritableSection: some View {
        let lightNames = Set(attrs.values.filter { $0.isLightRelated }.map(\.name))
        let commonNames: Set<String> = ["onOffStatus", "targetTemperature", "operationMode", "windSpeed"]
        let rest = attrs.values
            .filter { $0.writable && !lightNames.contains($0.name) && !commonNames.contains($0.name) }
            .sorted { $0.desc < $1.desc }

        if !rest.isEmpty {
            let groups = categorizeAttributes(rest)

            VStack(alignment: .leading, spacing: Theme.spaceMD) {
                HStack {
                    Text("高级与扩展功能（\(rest.count)）")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.inkSubtle)
                        .tracking(0.4)

                    Spacer()

                    Button {
                        withAnimation(Theme.springSmooth) {
                            if expandedGroupIds.count == groups.count {
                                expandedGroupIds.removeAll()
                            } else {
                                expandedGroupIds = Set(groups.map(\.id))
                            }
                        }
                    } label: {
                        Text(expandedGroupIds.count == groups.count ? "收起全部" : "展开全部")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(groups) { group in
                    let isExpanded = expandedGroupIds.contains(group.id)

                    VStack(spacing: 0) {
                        Button {
                            withAnimation(Theme.springSmooth) {
                                if isExpanded {
                                    expandedGroupIds.remove(group.id)
                                } else {
                                    expandedGroupIds.insert(group.id)
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.surface2)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: group.icon)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Theme.accent)
                                }

                                Text(group.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.ink)

                                Spacer()

                                Text("\(group.attributes.count) 项设置")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.inkTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Theme.surface2)
                                    )

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.inkTertiary)
                                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            }
                            .padding(.horizontal, Theme.spaceMD)
                            .padding(.vertical, 10)
                            .background(Theme.surface1)
                        }
                        .buttonStyle(.plain)

                        if isExpanded {
                            Divider().overlay(Theme.hairline)

                            VStack(spacing: 0) {
                                ForEach(Array(group.attributes.enumerated()), id: \.element.id) { index, attr in
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
                                    if index < group.attributes.count - 1 {
                                        Divider()
                                            .overlay(Theme.hairline)
                                            .padding(.vertical, 2)
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.spaceMD)
                            .padding(.vertical, 6)
                            .background(Theme.surface1)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func categorizeAttributes(_ attrs: [DeviceAttribute]) -> [AttributeDrawerGroup] {
        var grouped: [AttributeCategory: [DeviceAttribute]] = [:]
        for cat in AttributeCategory.allCases {
            grouped[cat] = []
        }
        for attr in attrs {
            let cat = AttributeCategory.classify(attr)
            grouped[cat, default: []].append(attr)
        }

        return AttributeCategory.allCases.compactMap { cat in
            guard let list = grouped[cat], !list.isEmpty else { return nil }
            return AttributeDrawerGroup(id: cat.id, title: cat.title, icon: cat.icon, attributes: list)
        }
    }

enum AttributeCategory: String, CaseIterable, Identifiable {
    case wind
    case health
    case sleep
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wind: return "风向与摆风控制"
        case .health: return "健康与自清洁"
        case .sleep: return "伴眠与能效设置"
        case .other: return "高级与硬件参数"
        }
    }

    var icon: String {
        switch self {
        case .wind: return "arrow.triangle.swap"
        case .health: return "leaf.fill"
        case .sleep: return "moon.zzz.fill"
        case .other: return "slider.horizontal.2.square"
        }
    }

    static func classify(_ attr: DeviceAttribute) -> AttributeCategory {
        let desc = attr.desc.lowercased()
        let name = attr.name.lowercased()
        if desc.contains("风") || desc.contains("摆") || desc.contains("扫") || desc.contains("吹") || name.contains("wind") || name.contains("swing") {
            return .wind
        } else if desc.contains("洁") || desc.contains("净") || desc.contains("湿") || desc.contains("健康") || desc.contains("除菌") || desc.contains("新风") || name.contains("clean") || name.contains("health") {
            return .health
        } else if desc.contains("睡") || desc.contains("省") || desc.contains("静") || desc.contains("辅热") || desc.contains("锁") || desc.contains("音") || name.contains("sleep") || name.contains("eco") {
            return .sleep
        } else {
            return .other
        }
    }
}

struct AttributeDrawerGroup: Identifiable {
    let id: String
    let title: String
    let icon: String
    let attributes: [DeviceAttribute]
}

    // MARK: - 空态

    private var emptyStateView: some View {
        VStack(spacing: Theme.spaceMD) {
            if !model.gatewayConnected {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.warning)
                Text("网关连接中断，正在自动重连...")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSubtle)
            } else {
                ProgressView()
                    .controlSize(.regular)
                    .tint(Theme.accent)
                Text("正在拉取空调数字模型...")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSubtle)
                Text("若长时间无响应，请返回设备列表重试")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - SwiftUI Preview

#if DEBUG
struct DeviceControlView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceControlView(device: DeviceInfo(
            deviceId: "test-device",
            deviceName: "客厅空调",
            deviceType: "AC",
            productNameT: "海尔云溪 1.5 匹挂机",
            online: true
        ))
        .environmentObject(AppModel.shared)
        .frame(width: 600, height: 800)
    }
}
#endif
