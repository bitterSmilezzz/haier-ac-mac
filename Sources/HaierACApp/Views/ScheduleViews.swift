import SwiftUI
import HaierACCore

/// 定时/倒计时任务列表区（显示在设备列表页）
struct ScheduleSection: View {
    @EnvironmentObject var model: AppModel
    @State private var showAddSheet = false

    private var sortedActions: [ScheduledAction] {
        model.scheduledActions.sorted { $0.fireDate < $1.fireDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            HStack {
                Text("定时任务（本地调度）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)
                    .tracking(0.4)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("新增", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(Theme.secondaryButtonStyle())
            }

            if sortedActions.isEmpty {
                Text("到点自动向空调发送指令（如 22:00 关机）。\n本地调度需 App 运行中生效，退出或睡眠期间到点的任务将在下次启动后补发。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(Theme.spaceMD)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.cardBackground(Theme.surface1))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedActions.enumerated()), id: \.element.id) { index, action in
                        ScheduleRow(action: action)
                        if index < sortedActions.count - 1 {
                            Divider().overlay(Theme.hairline).padding(.leading, Theme.spaceMD)
                        }
                    }
                }
                .background(Theme.cardBackground(Theme.surface1))
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddScheduleSheet()
                .environmentObject(model)
        }
    }
}

/// 单条调度任务行
private struct ScheduleRow: View {
    @EnvironmentObject var model: AppModel
    let action: ScheduledAction

    private var deviceName: String {
        model.devices.first(where: { $0.id == action.deviceId })?.deviceName
            ?? model.manualDevices.first(where: { $0.deviceId == action.deviceId })?.name
            ?? action.deviceId
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: action.fireDate)
    }

    var body: some View {
        HStack(spacing: Theme.spaceMD) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                    .fill(action.repeatsDaily ? Theme.accent.opacity(0.12) : Theme.surface2)
                    .frame(width: 44, height: 44)
                Image(systemName: action.repeatsDaily ? "repeat" : "timer")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(action.repeatsDaily ? Theme.accent : Theme.inkMuted)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(action.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("\(deviceName) · \(timeText)\(action.repeatsDaily ? " · 每天" : "")")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSubtle)
            }

            Spacer()

            if action.enabled {
                Text("待触发")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.success.opacity(0.1)))
            }

            Button {
                model.removeScheduledAction(action)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.spaceMD)
        .padding(.vertical, 10)
    }
}

/// 新增调度任务弹窗：定时（每日重复可选）或倒计时
struct AddScheduleSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    enum Kind: String, CaseIterable {
        case schedule = "定时"
        case countdown = "倒计时"
    }

    @State private var kind: Kind = .schedule
    @State private var fireTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var countdownMinutes: Int = 30
    @State private var repeatsDaily = false

    /// 目标设备
    @State private var deviceId: String = ""
    /// 目标属性名（选中后驱动下方值控件）
    @State private var attrName: String = ""

    /// 值控件状态（根据属性类型决定）
    @State private var boolValue = false
    @State private var listValue: String = ""
    @State private var stepValue: Double = 26

    private var selectableDevices: [(id: String, name: String)] {
        let cloud = model.devices.map { (id: $0.id, name: $0.deviceName) }
        let manual = model.manualDevices.map { (id: $0.deviceId, name: $0.name) }
        return cloud + manual
    }

    private var attrs: [String: DeviceAttribute] {
        model.attributes[deviceId] ?? [:]
    }

    /// 可写属性（去掉灯光区，保留常用 + 其他）
    private var writableAttrs: [DeviceAttribute] {
        attrs.values.filter { $0.writable }.sorted { $0.desc < $1.desc }
    }

    private var selectedAttr: DeviceAttribute? {
        attrs[attrName]
    }

    private var canSubmit: Bool {
        !deviceId.isEmpty && !attrName.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            Text("新增定时任务")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)

            // 类型切换
            Picker("类型", selection: $kind) {
                ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            // 设备选择
            Picker("设备", selection: $deviceId) {
                Text("请选择设备").tag("")
                ForEach(selectableDevices, id: \.id) { device in
                    Text(device.name).tag(device.id)
                }
            }
            .onChange(of: deviceId) { _ in
                attrName = ""  // 切设备后重置属性
                if let first = writableAttrs.first {
                    attrName = first.name
                }
            }

            // 属性选择
            Picker("动作", selection: $attrName) {
                Text("请选择动作").tag("")
                ForEach(writableAttrs, id: \.name) { attr in
                    Text(attr.desc).tag(attr.name)
                }
            }
            .onChange(of: attrName) { _ in
                loadAttrDefaults()
            }

            // 值控件（按属性类型渲染）
            if let attr = selectedAttr {
                valueControl(attr)
            }

            // 时间设置
            if kind == .schedule {
                DatePicker("触发时间", selection: $fireTime, displayedComponents: .hourAndMinute)
                Toggle("每天重复", isOn: $repeatsDaily)
            } else {
                Stepper("\(countdownMinutes) 分钟后触发", value: $countdownMinutes, in: 1...720)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(Theme.secondaryButtonStyle())
                Button("添加") {
                    addAction()
                    dismiss()
                }
                .buttonStyle(Theme.primaryButtonStyle())
                .disabled(!canSubmit)
            }
        }
        .padding(Theme.spaceLG)
        .frame(width: 400)
        .background(Theme.canvas)
        .onAppear {
            // 预选第一台设备与第一个属性
            if deviceId.isEmpty, let first = selectableDevices.first {
                deviceId = first.id
                if let attr = writableAttrs.first {
                    attrName = attr.name
                }
            }
        }
    }

    @ViewBuilder
    private func valueControl(_ attr: DeviceAttribute) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("将 \(attr.desc) 设为：")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)

            switch attr.valueRange {
            case .list(let opts):
                if attr.isBinarySwitch {
                    Toggle(attr.desc, isOn: $boolValue)
                } else {
                    Picker(attr.desc, selection: $listValue) {
                        ForEach(opts) { opt in
                            Text(opt.desc).tag(opt.data.stringValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
            case .step(let min, let max, let step):
                HStack {
                    Slider(value: $stepValue, in: min...max, step: step)
                        .tint(Theme.accent)
                    Text(String(format: "%.1f", stepValue))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(width: 40, alignment: .trailing)
                }
            case .none:
                Text("该属性无预设值，将在触发时保持当前值")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .padding(Theme.spaceSM)
        .background(Theme.surface1)
        .cornerRadius(Theme.radiusMD)
    }

    private func loadAttrDefaults() {
        guard let attr = selectedAttr else { return }
        switch attr.valueRange {
        case .list(let opts):
            boolValue = attr.boolValue ?? false
            listValue = attr.value?.stringValue ?? opts.first?.data.stringValue ?? ""
        case .step(let min, _, _):
            stepValue = attr.doubleValue ?? min
        case .none:
            break
        }
    }

    /// 由当前表单状态生成任务并加入模型
    private func addAction() {
        guard let attr = selectedAttr else { return }
        let value: AttrValue
        switch attr.valueRange {
        case .list(let opts):
            if attr.isBinarySwitch {
                value = .bool(boolValue)
            } else {
                guard let opt = opts.first(where: { $0.data.stringValue == listValue }) else { return }
                value = opt.data
            }
        case .step:
            value = .double(stepValue)
        case .none:
            return
        }
        guard let json = ScheduledAction.valueJSON(value) else { return }

        let fireDate: Date
        if kind == .countdown {
            fireDate = Date().addingTimeInterval(TimeInterval(countdownMinutes * 60))
        } else {
            // 定时：所选时刻若已过则顺延到明天
            let base = fireTime
            fireDate = base > Date() ? base : (Calendar.current.date(byAdding: .day, value: 1, to: base) ?? base)
        }

        let name: String
        if kind == .countdown {
            name = "\(countdownMinutes) 分钟后 \(attr.desc)"
        } else {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            name = "\(f.string(from: fireDate)) \(attr.desc)\(repeatsDaily ? "（每天）" : "")"
        }

        model.addScheduledAction(ScheduledAction(
            name: name,
            deviceId: deviceId,
            attrName: attr.name,
            attrDesc: attr.desc,
            attrValueJSON: json,
            fireDate: fireDate,
            repeatsDaily: kind == .schedule && repeatsDaily,
            enabled: true
        ))
    }
}
