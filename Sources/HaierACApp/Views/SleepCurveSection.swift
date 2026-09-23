import SwiftUI
import HaierACCore

/// 智能睡眠温阶曲线卡片组件
/// 遵循 macOS Bento 设计语言：自适应温阶阶梯预览、夜空感知渐变、动态呼吸动效与一键启停
struct SleepCurveSection: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var ambientEngine = AmbientSoundEngine.shared
    @State private var selectedConfig: SleepCurveConfig = .standard
    @State private var targetDeviceId: String = ""
    @State private var showCustomEditor = false
    @State private var editingTarget: SleepCurveConfig? = nil
    @State private var templateTarget: SleepCurveConfig? = nil
    @State private var showHistorySheet = false

    private var activeDevice: DeviceInfo? {
        if !targetDeviceId.isEmpty, let d = model.devices.first(where: { $0.id == targetDeviceId }) {
            return d
        }
        return model.devices.first
    }

    private var effectiveDeviceId: String {
        activeDevice?.id ?? model.manualDevices.first?.deviceId ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            // 顶栏标题
            HStack(spacing: 8) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))

                Text("智能睡眠温阶")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)
                    .tracking(0.4)

                Spacer()

                if model.activeSleepSession != nil {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.success)
                            .frame(width: 6, height: 6)
                        Text("运行中")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.success)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.success.opacity(0.12))
                    .clipShape(Capsule())
                }

                Button {
                    showHistorySheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                        Text("历史")
                            .font(.system(size: 11, weight: .medium))
                        if !model.sleepHistory.isEmpty {
                            Text("\(model.sleepHistory.count)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Theme.accent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(Theme.secondaryButtonStyle())
                .help("查看智能睡眠执行历史与温阶轨迹回放")

                Button {
                    editingTarget = nil
                    templateTarget = nil
                    showCustomEditor = true
                } label: {
                    Label("自定义", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(Theme.secondaryButtonStyle())

                Button {
                    if model.importCurvesFromClipboard() {
                        if let last = model.customSleepCurves.last {
                            selectedConfig = last
                        }
                    }
                } label: {
                    Label("导入", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(Theme.secondaryButtonStyle())
                .help("从系统剪贴板导入睡眠曲线 JSON 配置")
            }

            if let session = model.activeSleepSession {
                activeSessionCard(session: session)
            } else {
                idleConfigCard
            }
        }
        .padding(.horizontal, Theme.spaceLG)
        .sheet(isPresented: $showCustomEditor) {
            CustomSleepCurveSheet(
                editingCurve: editingTarget,
                templateCurve: templateTarget,
                onSaved: { newCurve in
                    selectedConfig = newCurve
                }
            )
            .environmentObject(model)
        }
        .sheet(isPresented: $showHistorySheet) {
            SleepHistorySheet(onSelectCurve: { curve in
                selectedConfig = curve
            })
            .environmentObject(model)
        }
        .onChange(of: model.customSleepCurves) { _ in
            if !model.allSleepCurves.contains(where: { $0.id == selectedConfig.id }) {
                selectedConfig = .standard
            }
        }
    }

    // MARK: - 运行中状态卡片

    private func activeSessionCard(session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.35, green: 0.38, blue: 0.85), Color(red: 0.22, green: 0.25, blue: 0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                        .shadow(color: Color(red: 0.35, green: 0.38, blue: 0.85).opacity(0.4), radius: 6)

                    Image(systemName: "moon.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(session.curveConfig.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)

                        Text("第 \(session.currentStageIndex + 1)/\(session.curveConfig.stages.count) 阶段")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.inkSubtle)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.surface2)
                            .cornerRadius(Theme.radiusSM)
                    }

                    if let current = session.currentStage {
                        HStack(spacing: 6) {
                            let displayTemp = session.effectiveTargetTemperature ?? current.targetTemperature
                            let tempStr = String(format: "%.1f°C", displayTemp).replacingOccurrences(of: ".0°C", with: "°C")
                            Text("当前：\(current.name) · \(tempStr)（\(current.windSpeed)）")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.inkMuted)

                            if session.compensationOffset != 0.0 {
                                let sign = session.compensationOffset > 0 ? "+" : ""
                                Text("✨ 自适应 \(sign)\(String(format: "%.1f", session.compensationOffset))°")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF).opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            if let hum = AppModel.indoorHumidityAttribute(in: model.attributes[session.deviceId] ?? [:])?.doubleValue {
                                HStack(spacing: 2) {
                                    Image(systemName: "humidity.fill")
                                        .font(.system(size: 9))
                                    Text("\(String(format: "%.0f%%", hum))")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF).opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    model.stopSleepCurve()
                } label: {
                    Text("停止")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.danger.opacity(0.12))
                        .cornerRadius(Theme.radiusSM)
                }
                .buttonStyle(.plain)
            }

            // 下一阶段倒计时预告
            if let next = session.nextStage, let fireDate = session.nextFireDate {
                let formatter = DateFormatter()
                let _ = formatter.dateFormat = "HH:mm"
                let fireTimeStr = formatter.string(from: fireDate)

                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)
                    Text("下一阶段：\(fireTimeStr) 自动进入「\(next.name)」\(next.powerOn ? String(format: "%.0f°C", next.targetTemperature) : "关机")")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .padding(.top, 2)
            }

            // 阶段进度小圆点指示
            HStack(spacing: 6) {
                ForEach(0..<session.curveConfig.stages.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx <= session.currentStageIndex ? Theme.accent : Theme.surface3)
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)
        }
        .padding(Theme.spaceMD)
        .background(
            LinearGradient(
                colors: [
                    Color.dynamic(light: 0xF3F4FF, dark: 0x121424),
                    Color.dynamic(light: 0xE8EAFF, dark: 0x181A2E)
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
    }

    // MARK: - 未运行配置卡片

    private var idleConfigCard: some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            // 曲线切换与管理行
            HStack(spacing: 8) {
                Picker("", selection: $selectedConfig) {
                    ForEach(model.allSleepCurves) { cfg in
                        Text(cfg.name).tag(cfg)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if selectedConfig.isCustom {
                    HStack(spacing: 4) {
                        Button {
                            editingTarget = selectedConfig
                            templateTarget = nil
                            showCustomEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkSubtle)
                                .frame(width: 24, height: 24)
                                .background(Theme.surface2)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("编辑此自定义曲线")

                        Button {
                            model.copyCurveJSONToClipboard(selectedConfig)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkSubtle)
                                .frame(width: 24, height: 24)
                                .background(Theme.surface2)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("导出/复制曲线 JSON 到剪贴板")

                        Button {
                            let targetId = selectedConfig.id
                            selectedConfig = .standard
                            model.deleteCustomSleepCurve(id: targetId)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.danger)
                                .frame(width: 24, height: 24)
                                .background(Theme.danger.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("删除此自定义曲线")
                    }
                } else {
                    HStack(spacing: 4) {
                        Button {
                            editingTarget = nil
                            templateTarget = selectedConfig
                            showCustomEditor = true
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                Text("复制")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(Theme.inkSubtle)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(Theme.surface2)
                            .cornerRadius(Theme.radiusSM)
                        }
                        .buttonStyle(.plain)
                        .help("基于「\(selectedConfig.name)」创建自定义曲线")

                        Button {
                            model.copyCurveJSONToClipboard(selectedConfig)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkSubtle)
                                .frame(width: 24, height: 24)
                                .background(Theme.surface2)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("导出预设 JSON 配置到剪贴板")
                    }
                }
            }

            Text(selectedConfig.desc)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)
                .lineLimit(2)

            // 阶段阶梯横向展示
            HStack(spacing: 8) {
                ForEach(selectedConfig.stages) { stage in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stage.timeLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.inkTertiary)

                        HStack(spacing: 3) {
                            if stage.powerOn {
                                Text(String(format: "%.0f°", stage.targetTemperature))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                            } else {
                                Text("关机")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                        }

                        Text(stage.name)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkSubtle)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface2)
                    .cornerRadius(Theme.radiusSM)
                }
            }

            // 夜间环境光与静音联动
            Toggle(isOn: $model.sleepNightDimming) {
                HStack(spacing: 5) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                    Text("夜间就寝联动")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("· 启动时自动关闭机身面板灯光与提示音")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .toggleStyle(.checkbox)
            .padding(.top, 2)

            Toggle(isOn: $model.sleepNotificationDND) {
                HStack(spacing: 5) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSubtle)
                    Text("阶段切换免打扰")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("· 夜间调温静默推进，不发通知弹窗打扰睡眠")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: $model.sleepAdaptiveCompensation) {
                HStack(spacing: 5) {
                    Image(systemName: "thermometer.sun")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                    Text("室内温差自适应补偿")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("· 实测室温偏离时自动微调 ±1°C，防止过冷受凉或闷热")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: $model.sleepHumidityGuard) {
                HStack(spacing: 5) {
                    Image(systemName: "drop.degreesign.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                    Text("温湿度双控健康守护")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("· 闷热高湿微调控湿，偏干减轻抽湿呵护呼吸道")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .toggleStyle(.checkbox)

            // 晨间唤醒平滑过渡
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "sun.haze.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dynamic(light: 0xF05A28, dark: 0xFF6934))
                    Text("晨间唤醒过渡")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("· 清晨醒来自动转为自然风，避免骤热")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }

                Spacer()

                Picker("", selection: $model.sleepMorningTransition) {
                    ForEach(SleepMorningTransitionMode.allCases) { mode in
                        Text(mode.shortLabel).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }
            .padding(.top, 1)

            Toggle(isOn: $model.sleepMorningWakeChime) {
                HStack(spacing: 5) {
                    Image(systemName: "bird.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dynamic(light: 0x27AE60, dark: 0x2ECC71))
                    Text("清晨林鸟唤醒音律")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("· 唤醒时刻自动轻柔播放自然林鸟鸣叫，柔和舒展醒神")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .toggleStyle(.checkbox)

            // 睡眠环境自然白噪音助眠联动 (v1.9.20)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Toggle(isOn: $model.sleepAmbientSoundEnabled) {
                        HStack(spacing: 5) {
                            Image(systemName: "waveform")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                            Text("自然白噪音助眠联动")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Text("· 原生算法合成自然环境音，舒缓宁神")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.inkSubtle)
                        }
                    }
                    .toggleStyle(.checkbox)

                    Spacer()

                    if model.sleepAmbientSoundEnabled {
                        Button {
                            if ambientEngine.isPlaying {
                                ambientEngine.stop(fadeOutDuration: 0.5)
                            } else {
                                ambientEngine.play(type: model.sleepAmbientSoundType, fadeInDuration: 0.5)
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: ambientEngine.isPlaying ? "stop.fill" : "play.fill")
                                    .font(.system(size: 9))
                                Text(ambientEngine.isPlaying ? "试听中" : "试听")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(Theme.secondaryButtonStyle())
                    }
                }

                if model.sleepAmbientSoundEnabled {
                    HStack(spacing: 10) {
                        Picker("声型", selection: $model.sleepAmbientSoundType) {
                            ForEach(AmbientSoundType.allCases) { sound in
                                Label(sound.rawValue, systemImage: sound.icon).tag(sound)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 130)
                        .onChange(of: model.sleepAmbientSoundType) { newType in
                            if ambientEngine.isPlaying {
                                ambientEngine.play(type: newType, fadeInDuration: 0.3)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.1.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.inkSubtle)
                            Slider(value: $model.sleepAmbientSoundVolume, in: 0.05...1.0)
                                .frame(width: 75)
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.inkSubtle)
                        }

                        Spacer()

                        Toggle("深睡淡出", isOn: $model.sleepAmbientAutoFadeOut)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10))
                            .help("进入深睡阶段后自动平缓淡出白噪音，安睡整夜")
                    }
                    .padding(.leading, 18)
                    .padding(.vertical, 2)
                }
            }

            // 定时就寝与睡前预冷 (v1.9.19)
            bedtimeScheduleConfigSection

            // 启动按钮
            Button {
                guard !effectiveDeviceId.isEmpty else { return }
                model.startSleepCurve(curve: selectedConfig, deviceId: effectiveDeviceId)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                    Text("开启「\(selectedConfig.name)」睡眠温阶")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(Theme.primaryButtonStyle())
            .disabled(effectiveDeviceId.isEmpty)

            // 全局快捷键极速启停提示
            HStack(spacing: 4) {
                Image(systemName: "command")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
                Text("macOS 全局快捷键: Control + Option + S 随时一键启停")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 1)
        }
        .padding(Theme.spaceMD)
        .background(Theme.cardBackground(Theme.surface1))
        .cornerRadius(Theme.radiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    // MARK: - 定时就寝与睡前预冷设置 (v1.9.19)

    private var bedtimeBinding: Binding<Date> {
        Binding(
            get: {
                let cal = Calendar.current
                return cal.date(bySettingHour: model.bedtimeSchedule.hour, minute: model.bedtimeSchedule.minute, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let cal = Calendar.current
                model.bedtimeSchedule.hour = cal.component(.hour, from: newDate)
                model.bedtimeSchedule.minute = cal.component(.minute, from: newDate)
            }
        )
    }

    private var bedtimeScheduleConfigSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $model.bedtimeSchedule.enabled) {
                HStack(spacing: 5) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                    Text("定时就寝与睡前预冷")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    if model.bedtimeSchedule.enabled {
                        Text("· \(model.bedtimeSchedule.timeLabel) (\(model.bedtimeSchedule.repeatLabel))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.dynamic(light: 0x5E6AD2, dark: 0x9B8BFF))
                    } else {
                        Text("· 每日/工作日自动启动睡眠温阶，支持提前预冷")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
            }
            .toggleStyle(.checkbox)

            if model.bedtimeSchedule.enabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text("就寝时间")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkSubtle)

                            DatePicker("", selection: bedtimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 80)
                        }

                        HStack(spacing: 6) {
                            Text("目标方案")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkSubtle)

                            Picker("", selection: $model.bedtimeSchedule.curveName) {
                                ForEach(model.allSleepCurves) { cfg in
                                    Text(cfg.name).tag(cfg.name)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)
                        }

                        Spacer()
                    }

                    // 重复周期快速切换
                    HStack(spacing: 8) {
                        Text("重复周期")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSubtle)

                        HStack(spacing: 4) {
                            weekdayButton(label: "工作日", isSelected: model.bedtimeSchedule.repeatWeekdays.sorted() == [2, 3, 4, 5, 6]) {
                                model.bedtimeSchedule.repeatWeekdays = [2, 3, 4, 5, 6]
                            }
                            weekdayButton(label: "每天", isSelected: model.bedtimeSchedule.repeatWeekdays.count == 7) {
                                model.bedtimeSchedule.repeatWeekdays = [1, 2, 3, 4, 5, 6, 7]
                            }
                            weekdayButton(label: "周末", isSelected: model.bedtimeSchedule.repeatWeekdays.sorted() == [1, 7]) {
                                model.bedtimeSchedule.repeatWeekdays = [1, 7]
                            }
                        }
                    }

                    // 睡前预冷开关
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.accent)
                            Text("睡前 15 分钟预冷")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Text("· 提前开启微风降温，营造最佳入眠环境")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.inkSubtle)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { model.bedtimeSchedule.preCoolingMinutes > 0 },
                            set: { model.bedtimeSchedule.preCoolingMinutes = $0 ? 15 : 0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                    }
                }
                .padding(10)
                .background(Theme.surface2)
                .cornerRadius(Theme.radiusSM)
            }
        }
    }

    private func weekdayButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Theme.accent : Theme.inkSubtle)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isSelected ? Theme.accent.opacity(0.12) : Theme.surface1)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
