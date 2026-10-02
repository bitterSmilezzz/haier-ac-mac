import SwiftUI
import AppKit
import Charts
import HaierACCore

/// 菜单栏控制中心 Bento Popover
/// 遵循 macOS 控制中心规范：毛玻璃材质底衬、Bento 网格模块、状态感知动态强调色与微触感弹簧动效
struct MenuBarControlsView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var ambient = AmbientSoundEngine.shared

    /// 菜单栏选中的睡眠曲线方案
    @State private var selectedSleepCurveId: UUID?
    /// 一键情景下发生效范围：false 为当前机，true 为全屋多联 (v1.9.104)
    @State private var sceneScopeAll = false
    /// 目标温度调节生效范围：false 为当前机，true 为全屋多联联动 (v1.9.108)
    @State private var tempScopeAll = false
    /// 全屋联动调温步进：true 为 0.5°C 高精微调，false 为 1.0°C 标准温阶 (持久化同步至 AppModel, v1.9.111, v1.9.113)
    private var wholeHouseFineStep: Bool {
        get { model.wholeHouseFineStep }
        nonmutating set { model.wholeHouseFineStep = newValue }
    }
    /// 运行模式与风速调节生效范围：false 为当前机，true 为全屋多联联动 (v1.9.112)
    @State private var modeScopeAll = false

    private var selectedSleepCurve: SleepCurveConfig {
        if let id = selectedSleepCurveId, let curve = model.allSleepCurves.first(where: { $0.id == id }) {
            return curve
        }
        return model.allSleepCurves.first ?? .standard
    }

    private var activeDevices: [DeviceInfo] {
        model.effectiveDevices
    }

    private var currentDevice: DeviceInfo? {
        let targetId = model.primaryDeviceId
        if let targetId, let device = activeDevices.first(where: { $0.id == targetId }) {
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

                let reachability = model.reachability(for: device)

                // 物理离线与网关断网三态防护横幅
                switch reachability {
                case .available:
                    EmptyView()
                case .gatewayReconnecting:
                    HStack(spacing: 6) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.warning)
                        Text("网关重连中，控制指令暂不可用")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSubtle)
                        Spacer()
                        Button("重试") {
                            model.retryConnection()
                        }
                        .font(.system(size: 10, weight: .medium))
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.accent)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
                case .deviceOffline:
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.offline)
                        Text("当前空调未连入网络，控制指令暂不可用")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
                }

                // 2. 快捷操作 Bento 矩阵（电源、情景灯光、屏显）
                quickActionsPod(device: device, attrs: attrs, isPowerOn: isPowerOn, tint: tint)
                    .disabled(!reachability.isControllable)
                    .opacity(reachability.isControllable ? 1.0 : 0.6)

                // 2.1 智能睡眠快速启停模块 (运行中显示进度与随时停止，空闲时开启受设备可达性门禁保护)
                sleepControlPod(device: device)

                // 2.2 蒸发器自清洁状态与洁净保护指示 (若处于清洁中或洁净保护期) (v1.9.114)
                if model.isSelfCleaningActive || model.isSelfCleaningProtectionActive(for: device.id) {
                    selfCleaningPod(device: device)
                }

                // 2.25 滤网积尘健康预警与拆洗保养胶囊 (若当前机滤网洁净度 <= 30%) (v1.9.114)
                filterWarningPod(device: device)

                // 2.3 睡眠助眠白噪音快捷播控 (若正在播放或配置开启)
                if ambient.isPlaying || model.sleepAmbientSoundEnabled {
                    ambientSoundPod
                }

                // 2.4 活跃定时与倒计时任务快捷指示胶囊 (全屋调度全景感知与跨房间管理) (v1.9.104, v1.9.105)
                if hasScheduledActions(device: device) {
                    activeSchedulePod(device: device)
                }

                // 2.5 一键情景预设 Bento 矩阵 (若存在配置情景) (v1.9.103/v1.9.104)
                if !model.scenes.isEmpty {
                    scenesPod(device: device, reachability: reachability)
                }

                // 3. 核心温控 Bento 卡片
                temperatureBentoPod(device: device, attrs: attrs, isPowerOn: isPowerOn, tint: tint)
                    .disabled(!reachability.isControllable)
                    .opacity(reachability.isControllable ? 1.0 : 0.6)

                // 4. 模式与风速分段矩阵
                if isPowerOn {
                    modeAndFanPod(device: device, attrs: attrs, tint: tint)
                        .disabled(!reachability.isControllable)
                        .opacity(reachability.isControllable ? 1.0 : 0.6)
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
        .animation(Theme.springSmooth, value: currentDevice?.id)
        .onAppear {
            if selectedSleepCurveId == nil {
                selectedSleepCurveId = model.allSleepCurves.first?.id
            }
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
                        let reachability = model.reachability(for: device)
                        let dotColor: Color = {
                            switch reachability {
                            case .gatewayReconnecting:
                                return Theme.warning
                            case .deviceOffline:
                                return Theme.offline
                            case .available:
                                return isPowerOn ? Theme.success : Theme.inkTertiary
                            }
                        }()
                        let statusText: String = {
                            switch reachability {
                            case .gatewayReconnecting:
                                return "重连中..."
                            case .deviceOffline:
                                return "设备离线"
                            case .available:
                                return isPowerOn ? "\(modeCat.label)中" : "已关机"
                            }
                        }()

                        Circle()
                            .fill(dotColor)
                            .frame(width: 6, height: 6)
                        Text(statusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.inkSubtle)
                        if reachability == .gatewayReconnecting {
                            Button {
                                model.retryConnection()
                            } label: {
                                Text("立即重试")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        } else if reachability == .deviceOffline {
                            Text("（未连网）")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.inkTertiary)
                        }
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

                // 语音控制快捷按钮
                Button {
                    VoiceCapsuleWindowController.shared.show()
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(5)
                        .background(
                            Circle()
                                .fill(Theme.surface2)
                                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .help("语音控制 (Control+Option+A)")
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
        let allDevices = model.allUnifiedDevices
        let onDevices = allDevices.filter {
            model.reachability(for: $0.id).isControllable &&
            (model.attributes[$0.id]?["onOffStatus"]?.boolValue == true)
        }
        let anyDeviceOn = !onDevices.isEmpty
        let controllableDevices = allDevices.filter { model.reachability(for: $0.id).isControllable }

        return HStack(spacing: 8) {
            // 本机电源主开关
            Button {
                triggerHaptic()
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
            .help(isPowerOn ? "关闭「\(device.deviceName)」" : "开启「\(device.deviceName)」")

            // 多设备全屋电源快捷联动 (v1.9.109: 达成控制中心情景/温控/电源三位一体全屋对称)
            if allDevices.count > 1 {
                Button {
                    triggerHaptic()
                    withAnimation(Theme.spring) {
                        if anyDeviceOn {
                            _ = model.turnOffAllDevices()
                        } else {
                            _ = model.turnOnAllDevices()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: anyDeviceOn ? "poweroff" : "power")
                            .font(.system(size: 10, weight: .semibold))
                        Text(anyDeviceOn ? "全屋全关 (\(onDevices.count))" : "全屋开机")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(anyDeviceOn ? Theme.danger : Theme.accent)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                            .fill(anyDeviceOn ? Theme.danger.opacity(0.10) : Theme.accent.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                                    .strokeBorder(anyDeviceOn ? Theme.danger.opacity(0.3) : Theme.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!model.gatewayConnected || controllableDevices.isEmpty)
                .help(anyDeviceOn ? "一键关闭全屋 \(onDevices.count) 台运行中的空调" : "一键开启全屋 \(controllableDevices.count) 台在线空调")
            }

            // 情景灯光（若支持）
            if let light = attrs["lightStatus"], light.writable {
                let isLightOn = light.boolValue ?? false
                Button {
                    triggerHaptic()
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

    // MARK: - 2.4 活跃定时与倒计时任务指示胶囊 (v1.9.104, v1.9.105 全屋活跃调度全景感知与跨房间管理)

    private func hasScheduledActions(device: DeviceInfo) -> Bool {
        !model.scheduledActions.isEmpty
    }

    @ViewBuilder
    private func activeSchedulePod(device: DeviceInfo) -> some View {
        let allActions = model.scheduledActions
        let enabledActions = allActions.filter(\.enabled)
        let isAllPaused = !allActions.isEmpty && enabledActions.isEmpty

        let deviceEnabledActions = enabledActions
            .filter { $0.deviceId == device.id || $0.deviceId.isEmpty }
            .sorted { $0.fireDate < $1.fireDate }

        let allSortedEnabledActions = enabledActions.sorted { $0.fireDate < $1.fireDate }

        if isAllPaused {
            // 全屋任务全部暂停态
            HStack(spacing: 8) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("定时任务已暂停")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("全屋共 \(allActions.count) 个计划已暂停生效")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }

                Spacer()

                Button {
                    triggerHaptic()
                    withAnimation(Theme.springFast) {
                        _ = model.setAllScheduledActionsEnabled(true)
                    }
                } label: {
                    Text("一键恢复")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.dynamic(light: 0x007AFF, dark: 0x0A84FF))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.dynamic(light: 0x007AFF, dark: 0x0A84FF).opacity(0.12))
                        .cornerRadius(Theme.radiusSM)
                }
                .buttonStyle(.plain)
                .help("一键恢复全屋所有已暂停的定时任务")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                    .fill(Color.dynamic(light: 0xFFF9F0, dark: 0x2E2412))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                            .strokeBorder(Color.dynamic(light: 0xFFE0B2, dark: 0x543B17), lineWidth: 1)
                    )
            )
        } else if let nearest = deviceEnabledActions.first ?? allSortedEnabledActions.first {
            let isCurrentDeviceTask = (nearest.deviceId == device.id || nearest.deviceId.isEmpty)
            let remainingSeconds = nearest.fireDate.timeIntervalSince(Date())
            let timeDesc: String = {
                let df = DateFormatter()
                df.dateFormat = "HH:mm"
                let timeStr = df.string(from: nearest.fireDate)
                if remainingSeconds > 0 && remainingSeconds < 86400 {
                    let mins = max(1, Int(remainingSeconds / 60))
                    if mins >= 60 {
                        let h = mins / 60
                        let m = mins % 60
                        return m > 0 ? "今天 \(timeStr) (\(h)小时\(m)分后)" : "今天 \(timeStr) (\(h)小时后)"
                    } else {
                        return "今天 \(timeStr) (\(mins)分钟后)"
                    }
                } else if remainingSeconds <= 0 {
                    return "即将触发"
                } else {
                    let dfFull = DateFormatter()
                    dfFull.dateFormat = "M月d日 HH:mm"
                    return dfFull.string(from: nearest.fireDate)
                }
            }()

            let repeatDesc = nearest.repeatLabel
            let roomPrefix: String = {
                if isCurrentDeviceTask {
                    return ""
                } else {
                    let rName = model.allUnifiedDevices.first(where: { $0.id == nearest.deviceId })?.name ?? "其他房间"
                    return "「\(rName)」"
                }
            }()

            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dynamic(light: 0x007AFF, dark: 0x0A84FF))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("\(roomPrefix)\(nearest.name)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)

                        if let repeatDesc = repeatDesc {
                            Text(repeatDesc)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.dynamic(light: 0x007AFF, dark: 0x0A84FF))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.dynamic(light: 0x007AFF, dark: 0x0A84FF).opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    let subTitleText: String = {
                        if isCurrentDeviceTask {
                            if allSortedEnabledActions.count > deviceEnabledActions.count {
                                return "\(timeDesc) · 本机\(deviceEnabledActions.count)个/全屋\(allSortedEnabledActions.count)个计划"
                            } else if deviceEnabledActions.count > 1 {
                                return "\(timeDesc) · 共 \(deviceEnabledActions.count) 个计划"
                            } else {
                                return timeDesc
                            }
                        } else {
                            return "\(timeDesc) · 全屋共 \(allSortedEnabledActions.count) 个计划生效中"
                        }
                    }()

                    Text(subTitleText)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                        .lineLimit(1)
                }

                Spacer()

                if allActions.count == 1 {
                    Button {
                        triggerHaptic()
                        withAnimation(Theme.springFast) {
                            model.removeScheduledAction(nearest)
                        }
                    } label: {
                        Text("取消")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.danger.opacity(0.12))
                            .cornerRadius(Theme.radiusSM)
                    }
                    .buttonStyle(.plain)
                    .help("取消当前任务")
                } else {
                    Menu {
                        Button("取消此任务 (\(roomPrefix)\(nearest.name))") {
                            triggerHaptic()
                            withAnimation(Theme.springFast) {
                                model.removeScheduledAction(nearest)
                            }
                        }
                        if !deviceEnabledActions.isEmpty {
                            Button("取消「\(device.deviceName)」全部定时 (\(deviceEnabledActions.count))") {
                                triggerHaptic()
                                withAnimation(Theme.springFast) {
                                    _ = model.cancelSchedules(for: device.id)
                                }
                            }
                            Button("临时暂停「\(device.deviceName)」定时") {
                                triggerHaptic()
                                withAnimation(Theme.springFast) {
                                    _ = model.setScheduledActionsEnabled(for: device.id, enabled: false)
                                }
                            }
                        } else if allActions.contains(where: { ($0.deviceId == device.id || ($0.deviceId.isEmpty && device.id == (model.primaryDeviceId ?? ""))) && !$0.enabled }) {
                            Button("恢复生效「\(device.deviceName)」定时") {
                                triggerHaptic()
                                withAnimation(Theme.springFast) {
                                    _ = model.setScheduledActionsEnabled(for: device.id, enabled: true)
                                }
                            }
                        }
                        Divider()
                        Button("临时暂停全屋所有定时") {
                            triggerHaptic()
                            withAnimation(Theme.springFast) {
                                _ = model.setAllScheduledActionsEnabled(false)
                            }
                        }
                        Button("恢复生效全屋所有定时") {
                            triggerHaptic()
                            withAnimation(Theme.springFast) {
                                _ = model.setAllScheduledActionsEnabled(true)
                            }
                        }
                        Button("取消全屋所有定时") {
                            triggerHaptic()
                            withAnimation(Theme.springFast) {
                                _ = model.cancelAllSchedules()
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("管理")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.danger.opacity(0.12))
                        .cornerRadius(Theme.radiusSM)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                    .fill(Color.dynamic(light: 0xF0F7FF, dark: 0x142033))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                            .strokeBorder(Color.dynamic(light: 0xC5DCFF, dark: 0x1E3A5F), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - 2.5 一键情景预设 Bento 矩阵 (v1.9.103/v1.9.104, v1.9.107 可达性门禁与全景联动)

    private func scenesPod(device: DeviceInfo, reachability: AppModel.DeviceReachability) -> some View {
        let canApplyScene = sceneScopeAll
            ? (model.gatewayConnected && model.allUnifiedDevices.contains { model.reachability(for: $0.id).isControllable })
            : reachability.isControllable

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("一键情景")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)
                Spacer()

                if model.allUnifiedDevices.count > 1 {
                    HStack(spacing: 2) {
                        Button {
                            withAnimation(Theme.springFast) {
                                sceneScopeAll = false
                                triggerHaptic()
                            }
                        } label: {
                            Text("当前机")
                                .font(.system(size: 9, weight: !sceneScopeAll ? .semibold : .regular))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .foregroundStyle(!sceneScopeAll ? Theme.ink : Theme.inkTertiary)
                                .background(
                                    Capsule()
                                        .fill(!sceneScopeAll ? Theme.surface3 : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(Theme.springFast) {
                                sceneScopeAll = true
                                triggerHaptic()
                            }
                        } label: {
                            Text("全屋 (\(model.allUnifiedDevices.count))")
                                .font(.system(size: 9, weight: sceneScopeAll ? .semibold : .regular))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .foregroundStyle(sceneScopeAll ? Theme.ink : Theme.inkTertiary)
                                .background(
                                    Capsule()
                                        .fill(sceneScopeAll ? Theme.surface3 : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(2)
                    .background(Capsule().fill(Theme.surface2))
                } else {
                    Text("当前: \(device.deviceName)")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 2)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: min(model.scenes.count, 3)), spacing: 6) {
                ForEach(model.scenes) { scene in
                    let sceneGlyph: String = {
                        switch scene.name {
                        case "睡眠": return "🌙"
                        case "离家": return "🚪"
                        case "回家": return "🏠"
                        default: return "✨"
                        }
                    }()
                    Button {
                        triggerHaptic()
                        withAnimation(Theme.springFast) {
                            if sceneScopeAll {
                                model.applyScene(scene, allDevices: true)
                            } else {
                                model.applyScene(scene, targetDeviceId: device.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(sceneGlyph)
                                .font(.system(size: 10))
                            Text(scene.name)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(Theme.ink)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                                .fill(Theme.surface2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                                        .strokeBorder(Theme.hairline, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help(sceneScopeAll ? "为全屋所有空调一键应用「\(scene.name)」情景" : "为「\(device.deviceName)」一键应用「\(scene.name)」情景")
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .disabled(!canApplyScene)
        .opacity(canApplyScene ? 1.0 : 0.6)
    }

    // MARK: - 3. 核心温控 Bento 卡片 (v1.9.108 支持当前机/全屋多联联动调温双模式)

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

            // 全屋运行中与可控设备状态感知
            let allDevices = model.allUnifiedDevices
            let onDevices = allDevices.filter {
                model.reachability(for: $0.id) == .available &&
                (model.attributes[$0.id]?["onOffStatus"]?.boolValue == true)
            }
            let controllableDevices = allDevices.filter { model.reachability(for: $0.id).isControllable }
            let allTemps = onDevices.compactMap { model.attribute("targetTemperature", deviceId: $0.id)?.doubleValue }

            VStack(spacing: 8) {
                // 若全屋多联机（>1台），展示顶部作用域切换条，与一键情景 Bento 保持设计语言完全统一
                if allDevices.count > 1 {
                    HStack {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(tint)
                        Text(tempScopeAll ? "全屋目标温度" : "目标温度")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.inkSubtle)

                        Spacer()

                        if tempScopeAll {
                            // 全屋步进粒度切换 (v1.9.111)
                            HStack(spacing: 2) {
                                Button {
                                    withAnimation(Theme.springFast) {
                                        wholeHouseFineStep = false
                                        triggerHaptic()
                                    }
                                } label: {
                                    Text("1.0°")
                                        .font(.system(size: 8.5, weight: !wholeHouseFineStep ? .bold : .regular))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .foregroundStyle(!wholeHouseFineStep ? Theme.ink : Theme.inkTertiary)
                                        .background(Capsule().fill(!wholeHouseFineStep ? Theme.surface3 : Color.clear))
                                }
                                .buttonStyle(.plain)
                                .help("标准 1.0°C 步进")

                                Button {
                                    withAnimation(Theme.springFast) {
                                        wholeHouseFineStep = true
                                        triggerHaptic()
                                    }
                                } label: {
                                    Text("0.5°")
                                        .font(.system(size: 8.5, weight: wholeHouseFineStep ? .bold : .regular))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .foregroundStyle(wholeHouseFineStep ? Theme.ink : Theme.inkTertiary)
                                        .background(Capsule().fill(wholeHouseFineStep ? Theme.surface3 : Color.clear))
                                }
                                .buttonStyle(.plain)
                                .help("高精 0.5°C 微调")
                            }
                            .padding(2)
                            .background(Capsule().fill(Theme.surface2))
                        }

                        HStack(spacing: 2) {
                            Button {
                                withAnimation(Theme.springFast) {
                                    tempScopeAll = false
                                    triggerHaptic()
                                }
                            } label: {
                                Text("当前机")
                                    .font(.system(size: 9, weight: !tempScopeAll ? .semibold : .regular))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(!tempScopeAll ? Theme.ink : Theme.inkTertiary)
                                    .background(
                                        Capsule().fill(!tempScopeAll ? Theme.surface3 : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(Theme.springFast) {
                                    tempScopeAll = true
                                    triggerHaptic()
                                }
                            } label: {
                                Text("全屋 (\(onDevices.count)台运行)")
                                    .font(.system(size: 9, weight: tempScopeAll ? .semibold : .regular))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(tempScopeAll ? Theme.ink : Theme.inkTertiary)
                                    .background(
                                        Capsule().fill(tempScopeAll ? Theme.surface3 : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(2)
                        .background(Capsule().fill(Theme.surface2))
                    }
                }

                HStack(alignment: .center) {
                    if !tempScopeAll || allDevices.count <= 1 {
                        // 单机模式
                        VStack(alignment: .leading, spacing: 2) {
                            if allDevices.count <= 1 {
                                Text("目标温度")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                            Text(String(format: "%.1f°C", current))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(isPowerOn ? tint : Theme.inkTertiary)
                        }

                        Spacer()

                        // 单机加减步进胶囊
                        HStack(spacing: 12) {
                            Button {
                                triggerHaptic()
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
                            .foregroundStyle(isPowerOn && current > min ? Theme.ink : Theme.inkTertiary)
                            .disabled(!isPowerOn || current <= min)

                            Button {
                                triggerHaptic()
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
                            .foregroundStyle(isPowerOn && current < max ? Theme.ink : Theme.inkTertiary)
                            .disabled(!isPowerOn || current >= max)
                        }
                        .padding(3)
                        .background(
                            Capsule()
                                .fill(Theme.surface1)
                                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                        )
                    } else {
                        // 全屋联动模式
                        let hasRunning = !onDevices.isEmpty
                        let canStepDownAll = model.gatewayConnected && (hasRunning
                            ? onDevices.contains { (model.attribute("targetTemperature", deviceId: $0.id)?.doubleValue ?? 26.0) > 16.0 }
                            : !controllableDevices.isEmpty)
                        let canStepUpAll = model.gatewayConnected && (hasRunning
                            ? onDevices.contains { (model.attribute("targetTemperature", deviceId: $0.id)?.doubleValue ?? 26.0) < 30.0 }
                            : !controllableDevices.isEmpty)

                        VStack(alignment: .leading, spacing: 2) {
                            if hasRunning {
                                let avgTemp = allTemps.isEmpty ? 26.0 : (allTemps.reduce(0.0, +) / Swift.Double(allTemps.count))
                                let minTemp = allTemps.min() ?? avgTemp
                                let maxTemp = allTemps.max() ?? avgTemp
                                if minTemp == maxTemp {
                                    Text(String(format: "%.1f°C", avgTemp))
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(tint)
                                } else {
                                    Text(String(format: "%.1f°C", avgTemp))
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(tint)
                                }
                                Text(minTemp == maxTemp ? "全屋同步中" : "\(String(format: "%.0f", minTemp))~\(String(format: "%.0f", maxTemp))°C 均温 · 统一步进")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.inkSubtle)
                                    .lineLimit(1)
                            } else {
                                Text("--.-°C")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.inkTertiary)
                                Text("全屋待机中 · 点击唤醒调温")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.inkSubtle)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        // 全屋统一步进胶囊 (支持 1.0°C / 0.5°C 动态步进, v1.9.111)
                        let stepDelta = wholeHouseFineStep ? 0.5 : 1.0
                        HStack(spacing: 12) {
                            Button {
                                triggerHaptic()
                                withAnimation(Theme.spring) {
                                    _ = model.adjustTemperatureAll(delta: -stepDelta)
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(width: 28, height: 28)
                                    .background(Theme.surface2)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(canStepDownAll ? Theme.ink : Theme.inkTertiary)
                            .disabled(!canStepDownAll)
                            .help(hasRunning ? "全屋运行中空调统一降温 \(String(format: "%.1f", stepDelta))°C" : "开启全屋空调并统一降温 \(String(format: "%.1f", stepDelta))°C")

                            Button {
                                triggerHaptic()
                                withAnimation(Theme.spring) {
                                    _ = model.adjustTemperatureAll(delta: stepDelta)
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(width: 28, height: 28)
                                    .background(Theme.surface2)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(canStepUpAll ? Theme.ink : Theme.inkTertiary)
                            .disabled(!canStepUpAll)
                            .help(hasRunning ? "全屋运行中空调统一升温 \(String(format: "%.1f", stepDelta))°C" : "开启全屋空调并统一升温 \(String(format: "%.1f", stepDelta))°C")
                        }
                        .padding(3)
                        .background(
                            Capsule()
                                .fill(Theme.surface1)
                                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                        )
                    }
                }
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

    // MARK: - 4. 模式与风速分段矩阵 (v1.9.112 支持当前机/全屋多联联动切换)

    @ViewBuilder
    private func modeAndFanPod(
        device: DeviceInfo,
        attrs: [String: DeviceAttribute],
        tint: Color
    ) -> some View {
        let allDevices = model.allUnifiedDevices
        let onDevices = allDevices.filter {
            model.reachability(for: $0.id) == .available &&
            (model.attributes[$0.id]?["onOffStatus"]?.boolValue == true)
        }

        VStack(spacing: 8) {
            // 若全屋多联机（>1台），展示顶部作用域切换条，与目标温度/情景 Bento 保持设计语言完全统一 (v1.9.112)
            if allDevices.count > 1 {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(modeScopeAll ? "全屋模式与风速" : "模式与风速")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.inkSubtle)

                    Spacer()

                    HStack(spacing: 2) {
                        Button {
                            withAnimation(Theme.springFast) {
                                modeScopeAll = false
                                triggerHaptic()
                            }
                        } label: {
                            Text("当前机")
                                .font(.system(size: 9, weight: !modeScopeAll ? .semibold : .regular))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .foregroundStyle(!modeScopeAll ? Theme.ink : Theme.inkTertiary)
                                .background(
                                    Capsule().fill(!modeScopeAll ? Theme.surface3 : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(Theme.springFast) {
                                modeScopeAll = true
                                triggerHaptic()
                            }
                        } label: {
                            Text("全屋 (\(onDevices.count)台运行)")
                                .font(.system(size: 9, weight: modeScopeAll ? .semibold : .regular))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .foregroundStyle(modeScopeAll ? Theme.ink : Theme.inkTertiary)
                                .background(
                                    Capsule().fill(modeScopeAll ? Theme.surface3 : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(2)
                    .background(Capsule().fill(Theme.surface2))
                }
                .padding(.horizontal, 2)
            }

            // 模式选择分段矩阵
            if let mode = attrs["operationMode"], mode.writable, case .list(let opts) = mode.valueRange {
                let currentVal = mode.value?.stringValue ?? ""

                HStack(spacing: 4) {
                    ForEach(opts) { opt in
                        let isSelected: Bool = {
                            if !modeScopeAll || allDevices.count <= 1 {
                                return opt.data.stringValue == currentVal
                            } else {
                                guard !onDevices.isEmpty else { return false }
                                return onDevices.allSatisfy { dev in
                                    let raw = model.attribute("operationMode", deviceId: dev.id)?.value?.stringValue
                                    return raw == opt.data.stringValue
                                }
                            }
                        }()
                        let optCat = Theme.modeCategory(modeDesc: opt.desc, isOn: true)

                        Button {
                            triggerHaptic()
                            withAnimation(Theme.springFast) {
                                if modeScopeAll && allDevices.count > 1 {
                                    let modeCode = ACModeCode(rawValue: opt.data.stringValue) ?? .cooling
                                    if !onDevices.isEmpty {
                                        let onIds = onDevices.map(\.id)
                                        _ = model.setMode(deviceIds: onIds, mode: modeCode)
                                    } else {
                                        _ = model.setModeAll(mode: modeCode)
                                    }
                                } else {
                                    model.sendAttribute("operationMode", value: opt.data, deviceId: device.id)
                                }
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
                        .help(modeScopeAll && allDevices.count > 1 ? (!onDevices.isEmpty ? "为全屋 \(onDevices.count) 台运行中的空调统一设为「\(opt.desc)」模式" : "开启全屋空调并统一设为「\(opt.desc)」模式") : "为「\(device.deviceName)」设为「\(opt.desc)」模式")
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
                        let isSelected: Bool = {
                            if !modeScopeAll || allDevices.count <= 1 {
                                return opt.data.stringValue == currentVal
                            } else {
                                guard !onDevices.isEmpty else { return false }
                                let targetNorm = AppModel.normalizeWindSpeed(opt.desc)
                                return onDevices.allSatisfy { dev in
                                    let raw = model.attribute("windSpeed", deviceId: dev.id)?.value?.stringValue ?? ""
                                    return AppModel.normalizeWindSpeed(raw) == targetNorm
                                }
                            }
                        }()

                        Button {
                            triggerHaptic()
                            withAnimation(Theme.springFast) {
                                if modeScopeAll && allDevices.count > 1 {
                                    if !onDevices.isEmpty {
                                        let onIds = onDevices.map(\.id)
                                        _ = model.setWindSpeed(deviceIds: onIds, speedName: opt.desc, autoPowerOn: false)
                                    } else {
                                        _ = model.setWindSpeedAll(speedName: opt.desc, autoPowerOn: false)
                                    }
                                } else {
                                    model.sendAttribute("windSpeed", value: opt.data, deviceId: device.id)
                                }
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
                        .help(modeScopeAll && allDevices.count > 1 ? (!onDevices.isEmpty ? "为全屋 \(onDevices.count) 台运行中的空调统一设为「\(opt.desc)」风速" : "为全屋空调统一设为「\(opt.desc)」风速") : "为「\(device.deviceName)」设为「\(opt.desc)」风速")
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

            Button {
                triggerHaptic()
                NotificationCenter.default.post(name: .haierOpenMainWindow, object: nil)
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    model.showFilterCareSheet = true
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("滤网与清洁")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.inkMuted)
            .help("打开空调滤网健康度监测与自清洁保养弹窗")

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

    // MARK: - 智能睡眠快速启停模块

    private func sleepControlPod(device: DeviceInfo) -> some View {
        let reachability = model.reachability(for: device)
        return Group {
            if let session = model.activeSleepSession {
                // 运行中状态 (停止按钮始终可用，离线时展示警示标签)
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("智能睡眠中 · \(session.curveConfig.name)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.ink)

                            if !reachability.isControllable {
                                Text(reachability == .gatewayReconnecting ? "重连中" : "离线")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(reachability == .gatewayReconnecting ? Theme.warning : Theme.offline)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background((reachability == .gatewayReconnecting ? Theme.warning : Theme.offline).opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            if session.compensationOffset != 0.0 {
                                let sign = session.compensationOffset > 0 ? "+" : ""
                                Text("✨\(sign)\(String(format: "%.1f", session.compensationOffset))°")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF).opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        if let current = session.currentStage {
                            let displayTemp = session.effectiveTargetTemperature ?? current.targetTemperature
                            let tempStr = String(format: "%.1f°C", displayTemp).replacingOccurrences(of: ".0°C", with: "°C")
                            let countdownText: String = {
                                if let fireDate = session.nextFireDate, let next = session.nextStage {
                                    let mins = max(1, Int(fireDate.timeIntervalSince(Date()) / 60))
                                    return " · \(mins)分后进入「\(next.name)」"
                                }
                                return ""
                            }()

                            Text("\(current.name) · \(tempStr)\(countdownText)")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.inkSubtle)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        model.stopSleepCurve()
                    } label: {
                        Text("停止")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.danger.opacity(0.12))
                            .cornerRadius(Theme.radiusSM)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [
                            Color.dynamic(light: 0xF3F4FF, dark: 0x14162B),
                            Color.dynamic(light: 0xEBEFFF, dark: 0x1B1E38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(Theme.radiusMD)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMD)
                        .strokeBorder(Color.dynamic(light: 0xD0D4FF, dark: 0x2A2E50), lineWidth: 1)
                )
            } else {
                // 空闲未运行状态：方案选择与一键开启（开启按钮受可达性门禁保护）
                HStack(spacing: 8) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))

                    // 方案选择下拉菜单
                    Menu {
                        ForEach(model.allSleepCurves) { curve in
                            Button {
                                selectedSleepCurveId = curve.id
                            } label: {
                                HStack {
                                    Text(curve.name)
                                    if curve.id == selectedSleepCurve.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedSleepCurve.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.inkTertiary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.surface2)
                        .cornerRadius(Theme.radiusSM)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Spacer()

                    // 一键开启按钮 (受可达性门禁约束，离线/重连中禁用)
                    let isControllable = reachability.isControllable
                    Button {
                        guard isControllable else { return }
                        model.startSleepCurve(curve: selectedSleepCurve, deviceId: device.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                            Text("开启睡眠")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(isControllable ? Color.white : Theme.inkTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: isControllable ? [
                                    Color.dynamic(light: 0x5E6AD2, dark: 0x6E78E8),
                                    Color.dynamic(light: 0x4D58C4, dark: 0x5862D6)
                                ] : [
                                    Theme.surface3,
                                    Theme.surface3
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(Theme.radiusSM)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isControllable)
                    .opacity(isControllable ? 1.0 : 0.6)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.surface1)
                .cornerRadius(Theme.radiusMD)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMD)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 蒸发器自清洁状态卡 (v1.9.21, v1.9.111 全局多设备宿主感知与一键切换, v1.9.114 洁净保护期感知)

    @ViewBuilder
    private func selfCleaningPod(device: DeviceInfo) -> some View {
        if model.isSelfCleaningActive {
            let isCurrentDevCleaning = model.selfCleaningDeviceId == device.id || (model.selfCleaningDeviceId == nil && model.allUnifiedDevices.count == 1)
            let hostName = model.selfCleaningDeviceId.map { model.deviceName(for: $0) } ?? device.deviceName
            let rem = model.selfCleaningRemainingSeconds
            let m = rem / 60
            let s = rem % 60
            let elapsed = max(0, 1200 - rem)
            let phaseDesc: String = {
                if elapsed < 300 {
                    return "阶段 1/4 • 急速深冷结霜裹尘"
                } else if elapsed < 600 {
                    return "阶段 2/4 • 逆循环微解冻剥离"
                } else if elapsed < 1080 {
                    return "阶段 3/4 • 56°C 高温杀菌烘干"
                } else {
                    return "阶段 4/4 • 送风排湿冷却恢复"
                }
            }()

            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dynamic(light: 0xF05A28, dark: 0xFF6934))

                VStack(alignment: .leading, spacing: 2) {
                    Text(isCurrentDevCleaning ? "「\(device.deviceName)」56°C 自清洁中" : "「\(hostName)」自清洁进行中")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(isCurrentDevCleaning
                        ? "剩余 \(String(format: "%02d:%02d", m, s)) • \(phaseDesc)"
                        : "剩余 \(String(format: "%02d:%02d", m, s)) • 本机处于待命")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkMuted)
                }

                Spacer()

                if !isCurrentDevCleaning && model.reachability(for: device).isControllable {
                    Button("切至本机") {
                        triggerHaptic()
                        model.startSelfCleaning(deviceId: device.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("将 56°C 深度自清洁转移至当前选中的「\(device.deviceName)」执行")
                }

                Button("中止") {
                    triggerHaptic()
                    model.stopSelfCleaning()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("中止当前正在执行的 56°C 高温除菌自清洁托管")
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                    .fill(Color.dynamic(light: 0xFFF3ED, dark: 0x331C12))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                            .strokeBorder(Color.dynamic(light: 0xFFA07A, dark: 0x8B4513).opacity(0.3), lineWidth: 1)
                    )
            )
        } else if model.isSelfCleaningProtectionActive(for: device.id) {
            // 蒸发器洁净保护期感知（自清洁后 14 天内翅片洁净无尘垢水膜，换热效率提升，v1.9.114, v1.9.118 动态增效折减自洽）
            let discount = model.selfCleaningDiscountPercentage(for: device.id)
            let bonusPct = max(0.5, discount * 0.40)
            let discountStr = String(format: "增效 +%.1f%%", bonusPct)
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.success)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("蒸发器洁净保护中")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(discountStr)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.success)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.success.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text("56°C 除菌保护中，换热翅片洁净低热阻")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkMuted)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                    .fill(Color.dynamic(light: 0xF0FDF4, dark: 0x14281A))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                            .strokeBorder(Theme.success.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - 滤网健康度预警与拆洗维护胶囊 (v1.9.114, v1.9.118 极端阻抗报警与气阻流阻精细感知)

    @ViewBuilder
    private func filterWarningPod(device: DeviceInfo) -> some View {
        let cleanliness = model.filterCleanlinessPercentage(for: device.id)
        if cleanliness <= 30 {
            let penalty = (Double(50 - max(0, cleanliness)) / 50.0) * 5.0
            let extremePenalty = cleanliness <= 10 ? (Double(10 - max(0, cleanliness)) / 10.0) * 1.5 : 0.0
            let totalPenalty = penalty + extremePenalty
            let penaltyStr = totalPenalty > 0 ? String(format: " · 气阻+%.1f%%", totalPenalty) : ""
            HStack(spacing: 8) {
                Image(systemName: cleanliness <= 10 ? "exclamationmark.triangle.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(cleanliness <= 10 ? Theme.danger : Theme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(cleanliness <= 10 ? "🚨 滤网极端阻抗报警" : "滤网积尘预警")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("剩余 \(cleanliness)%\(penaltyStr)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(cleanliness <= 10 ? Theme.danger : Theme.warning)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background((cleanliness <= 10 ? Theme.danger : Theme.warning).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(cleanliness <= 10 ? "进风通道极度受阻，气阻剧增建议立即拆洗" : "进风气阻增加致换热负荷上升，建议拆洗")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }

                Spacer()

                Button {
                    triggerHaptic()
                    NotificationCenter.default.post(name: .haierOpenMainWindow, object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        model.showFilterCareSheet = true
                    }
                } label: {
                    Text("保养重置")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.12))
                        .cornerRadius(Theme.radiusSM)
                }
                .buttonStyle(.plain)
                .help("查看滤网拆洗指南或重置滤网计时")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                    .fill(cleanliness <= 10 ? Color.dynamic(light: 0xFFF2F2, dark: 0x331414) : Color.dynamic(light: 0xFFF9F0, dark: 0x2E2412))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                            .strokeBorder(cleanliness <= 10 ? Color.dynamic(light: 0xFFD0D0, dark: 0x5C2020) : Color.dynamic(light: 0xFFE0B2, dark: 0x543B17), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - 睡眠助眠白噪音迷你播控 (v1.9.21)

    private var ambientSoundPod: some View {
        HStack(spacing: 8) {
            Image(systemName: ambient.isPlaying ? "waveform" : "speaker.slash")
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)

            Text(model.sleepAmbientSoundType.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.ink)

            Spacer()

            Button {
                if ambient.isPlaying {
                    ambient.stop()
                } else {
                    ambient.play(type: model.sleepAmbientSoundType)
                }
            } label: {
                Image(systemName: ambient.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.inkMuted)
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

    // MARK: - 微触感反馈 (v1.9.104)

    private func triggerHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
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
