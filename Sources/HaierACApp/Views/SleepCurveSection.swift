import SwiftUI
import HaierACCore

/// 智能睡眠温阶曲线卡片组件
/// 遵循 macOS Bento 设计语言：自适应温阶阶梯预览、夜空感知渐变、动态呼吸动效与一键启停
struct SleepCurveSection: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedConfig: SleepCurveConfig = .standard
    @State private var targetDeviceId: String = ""
    @State private var showCustomEditor = false
    @State private var editingTarget: SleepCurveConfig? = nil
    @State private var templateTarget: SleepCurveConfig? = nil

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
                    editingTarget = nil
                    templateTarget = nil
                    showCustomEditor = true
                } label: {
                    Label("自定义", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(Theme.secondaryButtonStyle())
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
                        Text("当前：\(current.name) · \(String(format: "%.0f°C", current.targetTemperature))（\(current.windSpeed)）")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkMuted)
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
        }
        .padding(Theme.spaceMD)
        .background(Theme.cardBackground(Theme.surface1))
        .cornerRadius(Theme.radiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}
