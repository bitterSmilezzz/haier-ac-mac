import SwiftUI
import HaierACCore

/// 自定义智能睡眠温阶曲线编辑器弹窗
/// 支持自由配置各阶段时长、目标温度、风速及关机时刻，并提供实时阶梯预览
struct CustomSleepCurveSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let editingCurve: SleepCurveConfig?

    @State private var name: String = ""
    @State private var desc: String = ""
    @State private var stages: [SleepStage] = []

    init(editingCurve: SleepCurveConfig? = nil) {
        self.editingCurve = editingCurve
        if let curve = editingCurve {
            _name = State(initialValue: curve.name)
            _desc = State(initialValue: curve.desc)
            _stages = State(initialValue: curve.stages)
        } else {
            _name = State(initialValue: "我的专属睡眠")
            _desc = State(initialValue: "个性化温阶调节，贴合个人睡眠节律")
            _stages = State(initialValue: [
                SleepStage(name: "入睡舒适", afterMinutes: 0, targetTemperature: 25.0, windSpeed: "微风", powerOn: true),
                SleepStage(name: "深睡呵护", afterMinutes: 120, targetTemperature: 26.0, windSpeed: "微风", powerOn: true),
                SleepStage(name: "熟睡恒温", afterMinutes: 300, targetTemperature: 27.0, windSpeed: "微风", powerOn: true),
                SleepStage(name: "醒来关机", afterMinutes: 480, targetTemperature: 27.0, windSpeed: "微风", powerOn: false)
            ])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            headerView

            Divider().overlay(Theme.hairlineSubtle)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spaceLG) {
                    // 1. 实时阶梯温阶预览
                    staircasePreviewPod

                    // 2. 基础信息设置
                    basicInfoSection

                    // 3. 各阶段温控设置
                    stagesSection
                }
                .padding(Theme.spaceLG)
            }
        }
        .frame(width: 520, height: 620)
        .background(Theme.canvas)
    }

    // MARK: - 顶栏

    private var headerView: some View {
        HStack {
            Button("取消") {
                dismiss()
            }
            .buttonStyle(Theme.secondaryButtonStyle())

            Spacer()

            Text(editingCurve == nil ? "新建睡眠温阶曲线" : "编辑睡眠曲线")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Spacer()

            Button("保存") {
                saveCurve()
                dismiss()
            }
            .buttonStyle(Theme.primaryButtonStyle())
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || stages.isEmpty)
        }
        .padding(.horizontal, Theme.spaceLG)
        .padding(.vertical, Theme.spaceMD)
    }

    // MARK: - 1. 实时阶梯预览

    private var staircasePreviewPod: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
                Text("温阶预览")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)
                Spacer()
                Text("共 \(stages.count) 个阶段 · 总时长 \(formatTotalDuration())")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
            }

            HStack(spacing: 6) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stage.timeLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkTertiary)

                        if stage.powerOn {
                            Text(String(format: "%.1f°", stage.targetTemperature))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.temperatureColor(celsius: stage.targetTemperature))
                        } else {
                            Text("关机")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.danger)
                        }

                        Text(stage.name.isEmpty ? "阶段 \(index + 1)" : stage.name)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkMuted)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface2)
                    .cornerRadius(Theme.radiusSM)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSM)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                }
            }
        }
        .padding(Theme.spaceMD)
        .background(Theme.surface1)
        .cornerRadius(Theme.radiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    // MARK: - 2. 基础信息设置

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("基础信息")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSubtle)

            VStack(spacing: 10) {
                HStack {
                    Text("曲线名称")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 70, alignment: .leading)

                    TextField("如：周末长睡、午休小憩", text: $name)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Theme.surface2)
                        .cornerRadius(Theme.radiusSM)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusSM)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                }

                HStack {
                    Text("描述说明")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 70, alignment: .leading)

                    TextField("简要说明适用场景", text: $desc)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Theme.surface2)
                        .cornerRadius(Theme.radiusSM)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusSM)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                }
            }
            .padding(Theme.spaceMD)
            .background(Theme.surface1)
            .cornerRadius(Theme.radiusMD)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMD)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }
    }

    // MARK: - 3. 各阶段设置

    private var stagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("分阶段温阶设置")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)

                Spacer()

                Button {
                    addNewStage()
                } label: {
                    Label("添加阶段", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(Theme.secondaryButtonStyle())
            }

            VStack(spacing: 12) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    stageRow(index: index, stage: stage)
                }
            }
        }
    }

    private func stageRow(index: Int, stage: SleepStage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("阶段 \(index + 1)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                TextField("阶段名称", text: Binding(
                    get: { stage.name },
                    set: { stages[index].name = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.surface2)
                .cornerRadius(Theme.radiusSM)
                .frame(width: 110)

                Spacer()

                if stages.count > 1 {
                    Button {
                        stages.remove(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.danger)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().overlay(Theme.hairlineSubtle)

            HStack(spacing: 16) {
                // 生效时间
                VStack(alignment: .leading, spacing: 4) {
                    Text("生效时刻")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)

                    if index == 0 {
                        Text("立即生效 (0h)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.inkSubtle)
                            .padding(.vertical, 4)
                    } else {
                        Stepper(value: Binding(
                            get: { stage.afterMinutes },
                            set: { stages[index].afterMinutes = max(30, $0) }
                        ), in: 30...720, step: 30) {
                            Text(formatMinutes(stage.afterMinutes))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }

                // 目标温度
                if stage.powerOn {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("目标温度")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkTertiary)

                        Stepper(value: Binding(
                            get: { stage.targetTemperature },
                            set: { stages[index].targetTemperature = min(max($0, 16.0), 30.0) }
                        ), in: 16.0...30.0, step: 0.5) {
                            Text(String(format: "%.1f°C", stage.targetTemperature))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.temperatureColor(celsius: stage.targetTemperature))
                        }
                    }
                }

                // 风速与电源动作
                VStack(alignment: .leading, spacing: 4) {
                    Text("运行动作")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)

                    HStack(spacing: 6) {
                        Picker("", selection: Binding(
                            get: { stage.powerOn },
                            set: { stages[index].powerOn = $0 }
                        )) {
                            Text("保持开机").tag(true)
                            Text("自动关机").tag(false)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(Theme.ink)

                        if stage.powerOn {
                            Picker("", selection: Binding(
                                get: { stage.windSpeed },
                                set: { stages[index].windSpeed = $0 }
                            )) {
                                Text("微风").tag("微风")
                                Text("低风").tag("低风")
                                Text("中风").tag("中风")
                                Text("强劲").tag("强劲")
                                Text("自动").tag("自动")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(Theme.ink)
                        }
                    }
                }
            }
        }
        .padding(Theme.spaceMD)
        .background(Theme.surface1)
        .cornerRadius(Theme.radiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    // MARK: - 辅助方法

    private func addNewStage() {
        let lastMinutes = stages.last?.afterMinutes ?? 0
        let newMinutes = lastMinutes + 60
        let lastTemp = stages.last?.targetTemperature ?? 26.0
        let newStage = SleepStage(
            name: "阶段 \(stages.count + 1)",
            afterMinutes: newMinutes,
            targetTemperature: min(lastTemp + 0.5, 28.0),
            windSpeed: "微风",
            powerOn: true
        )
        stages.append(newStage)
    }

    private func saveCurve() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        // 按时间排序阶段
        let sortedStages = stages.sorted { $0.afterMinutes < $1.afterMinutes }

        let config = SleepCurveConfig(
            id: editingCurve?.id ?? UUID(),
            name: trimmedName.isEmpty ? "专属睡眠" : trimmedName,
            desc: trimmedDesc.isEmpty ? "自定义睡眠温阶曲线" : trimmedDesc,
            icon: "moon.stars.fill",
            stages: sortedStages,
            isCustom: true
        )

        if editingCurve != nil {
            model.updateCustomSleepCurve(config)
        } else {
            model.addCustomSleepCurve(config)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes % 60 == 0 {
            return "\(minutes / 60)小时后"
        } else {
            return String(format: "%.1f小时后", Double(minutes) / 60.0)
        }
    }

    private func formatTotalDuration() -> String {
        guard let last = stages.last else { return "0小时" }
        return formatMinutes(last.afterMinutes)
    }
}
