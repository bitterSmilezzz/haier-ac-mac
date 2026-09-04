import SwiftUI
import HaierACCore

/// 情景模式区：预设组合一键下发（本地存储）
struct SceneSection: View {
    @EnvironmentObject var model: AppModel
    @State private var showAddSheet = false
    /// 应用情景时的目标设备（空 = 第一台设备）
    @State private var targetDeviceId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            HStack {
                Text("情景模式")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)
                    .tracking(0.4)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("自定义", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(Theme.secondaryButtonStyle())
            }

            if model.scenes.isEmpty {
                Text("用预设组合一键设置空调：如「睡眠」「离家」。点击右上角自定义创建。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(Theme.spaceMD)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.cardBackground(Theme.surface1))
            } else {
                // 目标设备选择（多设备时显示）
                if model.devices.count + model.manualDevices.count > 1 {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkTertiary)
                        Picker("", selection: $targetDeviceId) {
                            Text("第一台设备").tag("")
                            ForEach(model.devices.map { (id: $0.id, name: $0.deviceName) } +
                                    model.manualDevices.map { (id: $0.deviceId, name: $0.name) }, id: \.id) { d in
                                Text(d.name).tag(d.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(Theme.inkMuted)
                        Spacer()
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.spaceSM) {
                        ForEach(model.scenes) { scene in
                            SceneCard(scene: scene, targetDeviceId: targetDeviceId)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.spaceLG)  // 与页面对齐（视觉修复：情景区曾左移贴边）
        .sheet(isPresented: $showAddSheet) {
            AddSceneSheet()
                .environmentObject(model)
        }
    }
}

/// 单张情景卡片：图标 + 名称 + 动作摘要 + 应用按钮
private struct SceneCard: View {
    @EnvironmentObject var model: AppModel
    let scene: AppModel.ScenePreset
    let targetDeviceId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: scene.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button {
                    model.removeScene(scene)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkTertiary)
                }
                .buttonStyle(.plain)
            }

            Text(scene.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)

            Text(scene.actions.map { $0.attrDesc }.joined(separator: " · "))
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkSubtle)
                .lineLimit(2, reservesSpace: true)

            Button {
                model.applyScene(scene, targetDeviceId: targetDeviceId)
            } label: {
                Text("一键应用")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                            .fill(Theme.accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!model.gatewayConnected)
        }
        .padding(Theme.spaceMD)
        .frame(width: 132, height: 132)
        .background(Theme.cardBackground(Theme.surface1))
    }
}

/// 自定义情景弹窗：选设备 → 选属性 → 设值 → 加入动作列表 → 命名保存
struct AddSceneSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var sceneName = ""
    @State private var sceneIcon = "sparkles"

    @State private var deviceId = ""
    @State private var attrName = ""

    @State private var boolValue = false
    @State private var listValue = ""
    @State private var stepValue: Double = 26

    /// 已添加的动作（预览用）
    @State private var pendingActions: [AppModel.SceneAction] = []

    private var selectableDevices: [(id: String, name: String)] {
        model.devices.map { (id: $0.id, name: $0.deviceName) } +
        model.manualDevices.map { (id: $0.deviceId, name: $0.name) }
    }

    private var attrs: [String: DeviceAttribute] { model.attributes[deviceId] ?? [:] }

    private var writableAttrs: [DeviceAttribute] {
        attrs.values.filter { $0.writable }.sorted { $0.desc < $1.desc }
    }

    private var selectedAttr: DeviceAttribute? { attrs[attrName] }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            Text("自定义情景")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)

            TextField("情景名称（如：午休）", text: $sceneName)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )

            Picker("设备", selection: $deviceId) {
                Text("请选择设备").tag("")
                ForEach(selectableDevices, id: \.id) { d in
                    Text(d.name).tag(d.id)
                }
            }
            .onChange(of: deviceId) { _ in
                attrName = ""
                if let first = writableAttrs.first { attrName = first.name }
            }

            Picker("动作", selection: $attrName) {
                Text("请选择动作").tag("")
                ForEach(writableAttrs, id: \.name) { attr in
                    Text(attr.desc).tag(attr.name)
                }
            }
            .onChange(of: attrName) { _ in loadAttrDefaults() }

            if let attr = selectedAttr {
                valueControl(attr)

                Button {
                    addPendingAction()
                } label: {
                    Label("添加此动作", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            if !pendingActions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("已添加 \(pendingActions.count) 个动作")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.inkSubtle)
                    ForEach(Array(pendingActions.enumerated()), id: \.offset) { index, action in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.success)
                            Text(action.attrDesc)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.inkMuted)
                            Spacer()
                            Button {
                                pendingActions.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.inkTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Theme.spaceSM)
                .background(Theme.surface1)
                .cornerRadius(Theme.radiusMD)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(Theme.secondaryButtonStyle())
                Button("保存情景") {
                    saveScene()
                    dismiss()
                }
                .buttonStyle(Theme.primaryButtonStyle())
                .disabled(sceneName.trimmingCharacters(in: .whitespaces).isEmpty || pendingActions.isEmpty)
            }
        }
        .padding(Theme.spaceLG)
        .frame(width: 400)
        .background(Theme.canvas)
        .onAppear {
            if deviceId.isEmpty, let first = selectableDevices.first {
                deviceId = first.id
                if let attr = writableAttrs.first { attrName = attr.name }
            }
        }
    }

    @ViewBuilder
    private func valueControl(_ attr: DeviceAttribute) -> some View {
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
            Text("该属性无预设值，无法加入情景")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkTertiary)
        }
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

    private func addPendingAction() {
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
        pendingActions.append(AppModel.SceneAction(
            deviceId: deviceId,
            attrName: attr.name,
            attrDesc: attr.desc,
            valueJSON: json
        ))
    }

    private func saveScene() {
        model.addScene(
            name: sceneName.trimmingCharacters(in: .whitespaces),
            icon: sceneIcon,
            actions: pendingActions
        )
    }
}
