import SwiftUI
import HaierACCore

/// 空调滤网健康度监测与自清洁保养弹窗 (v1.9.20)
struct FilterCareSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirm = false
    @State private var isSelfCleaningInProgress = false
    @State private var selfCleaningCountdown = 1200 // 20分钟
    @State private var timerTask: Task<Void, Never>? = nil

    private var targetDeviceName: String {
        model.devices.first?.deviceName ?? model.manualDevices.first?.name ?? "海尔空调"
    }

    private var cleanlinessPercentage: Int {
        model.filterCleanlinessPercentage
    }

    private var runningHours: Double {
        Double(model.filterAccumulatedMinutes) / 60.0
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            headerView

            Divider().overlay(Theme.hairlineSubtle)

            ScrollView {
                VStack(spacing: Theme.spaceLG) {
                    // 1. 滤网健康度核心环形指示器
                    healthMetricCard

                    // 2. 深度自清洁操作卡
                    selfCleaningCard

                    // 3. 滤网拆洗图文步骤保养指南
                    cleaningGuideCard
                }
                .padding(Theme.spaceLG)
            }
        }
        .frame(width: 580, height: 620)
        .background(Theme.canvas)
        .alert("重置滤网清洗计时", isPresented: $showResetConfirm) {
            Button("取消", role: .cancel) { }
            Button("确认已清洗重置", role: .destructive) {
                model.resetFilterMaintenance()
            }
        } message: {
            Text("确认您已经完成了滤网的水洗与晾干装回吗？重置后累计运行时间将归零，洁净度恢复为 100%。")
        }
    }

    // MARK: - 顶栏

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15))
                .foregroundStyle(Color.dynamic(light: 0x0071E3, dark: 0x2997FF))

            Text("滤网健康与深度清洁保养")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Spacer()

            Button("完成") {
                dismiss()
            }
            .buttonStyle(Theme.secondaryButtonStyle())
        }
        .padding(.horizontal, Theme.spaceLG)
        .padding(.vertical, Theme.spaceMD)
    }

    // MARK: - 1. 滤网健康度核心卡

    private var healthMetricCard: some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            HStack(alignment: .center, spacing: Theme.spaceLG) {
                // 圆环进度
                ZStack {
                    Circle()
                        .stroke(Theme.surface2, lineWidth: 10)
                        .frame(width: 90, height: 90)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(cleanlinessPercentage) / 100.0)
                        .stroke(
                            statusColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 90, height: 90)
                        .animation(.easeInOut(duration: 0.6), value: cleanlinessPercentage)

                    VStack(spacing: 0) {
                        Text("\(cleanlinessPercentage)%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("洁净度")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }

                // 文字详情
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(targetDeviceName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)

                        Text(statusLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text("当前累计运行: \(String(format: "%.1f", runningHours)) 小时（建议每 250 小时清洗一次）")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSubtle)

                    if let lastClean = model.lastFilterCleanedDate {
                        Text("上次清洗时间: \(formattedDate(lastClean))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkTertiary)
                    } else {
                        Text("近期尚未记录水洗保养")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }

                Spacer()

                // 重置按钮
                Button {
                    showResetConfirm = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13))
                        Text("已清洗重置")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .buttonStyle(Theme.secondaryButtonStyle())
                .help("清洗滤网后重置运行时长与洁净度")
            }
        }
        .padding(Theme.spaceMD)
        .background(Theme.cardBackground(Theme.surface1))
        .cornerRadius(Theme.radiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    // MARK: - 2. 深度自清洁卡

    private var selfCleaningCard: some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            HStack {
                Label("56°C 高温除菌自清洁", systemImage: "flame.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dynamic(light: 0xF05A28, dark: 0xFF6934))

                Spacer()

                if isSelfCleaningInProgress {
                    Text("清洁中 \(formatCountdown(selfCleaningCountdown))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
            }

            Text("利用蒸发器结霜剥离污垢、化霜强力冲洗、56°C高温烘干抑菌三步深度清洁蒸发器翅片，彻底清除霉菌与异味。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSubtle)
                .lineSpacing(2)

            HStack {
                HStack(spacing: 12) {
                    processBadge(step: "1", title: "急速凝霜")
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Theme.inkTertiary)
                    processBadge(step: "2", title: "化霜冲洗")
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Theme.inkTertiary)
                    processBadge(step: "3", title: "高温烘干除菌")
                }

                Spacer()

                if isSelfCleaningInProgress {
                    Button("中止自清洁") {
                        stopSelfCleaning()
                    }
                    .buttonStyle(Theme.secondaryButtonStyle())
                } else {
                    Button {
                        startSelfCleaning()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("启动自清洁")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(Theme.primaryButtonStyle())
                }
            }
        }
        .padding(Theme.spaceMD)
        .background(Theme.cardBackground(Theme.surface1))
        .cornerRadius(Theme.radiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private func processBadge(step: String, title: String) -> some View {
        HStack(spacing: 4) {
            Text(step)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 16, height: 16)
                .background(Theme.accent.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink)
        }
    }

    // MARK: - 3. 滤网拆洗指南

    private var cleaningGuideCard: some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            Label("滤网水洗拆卸指南", systemImage: "wrench.and.screwdriver.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)

            VStack(spacing: 8) {
                guideStepRow(
                    index: "1",
                    title: "安全停机并断电",
                    desc: "关闭空调主机电源，等待室内机导风板完全回位闭合。"
                )
                guideStepRow(
                    index: "2",
                    title: "轻推翻开面板抽出滤网",
                    desc: "双手托住进风面板两侧卡扣向上抬起，顺着滑轨轻轻抽出左右两面防尘滤网。"
                )
                guideStepRow(
                    index: "3",
                    title: "常温清水冲洗并阴凉晾干",
                    desc: "使用软毛刷与 40°C 以下常温水反向冲刷灰尘，彻底风干后再装回机身。"
                )
            }
        }
        .padding(Theme.spaceMD)
        .background(Theme.cardBackground(Theme.surface1))
        .cornerRadius(Theme.radiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private func guideStepRow(index: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Theme.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ink)

                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSubtle)
            }
            Spacer()
        }
        .padding(8)
        .background(Theme.surface2)
        .cornerRadius(Theme.radiusSM)
    }

    // MARK: - 辅助计算与操作

    private var statusColor: Color {
        if cleanlinessPercentage >= 60 {
            return Theme.success
        } else if cleanlinessPercentage >= 25 {
            return Theme.accent
        } else {
            return Theme.warning
        }
    }

    private var statusLabel: String {
        if cleanlinessPercentage >= 80 {
            return "滤网清洁优良"
        } else if cleanlinessPercentage >= 50 {
            return "状态良好"
        } else if cleanlinessPercentage >= 20 {
            return "轻度积尘"
        } else {
            return "建议立即水洗"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: date)
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startSelfCleaning() {
        guard let deviceId = model.devices.first?.id ?? model.manualDevices.first?.deviceId else { return }

        // 尝试下发自清洁专用属性（海尔标准自清洁属性）
        let attrs = model.attributes[deviceId] ?? [:]
        for key in ["selfCleaningStatus", "cleanStatus", "pm25CleanStatus", "sterilizationStatus"] {
            if let attr = attrs[key], attr.writable {
                model.sendAttribute(key, value: .bool(true), deviceId: deviceId)
            }
        }

        isSelfCleaningInProgress = true
        selfCleaningCountdown = 1200
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while isSelfCleaningInProgress && selfCleaningCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                selfCleaningCountdown -= 1
            }
            if selfCleaningCountdown <= 0 {
                isSelfCleaningInProgress = false
                model.operationNotice = AppModel.OperationNotice(text: "蒸发器 56°C 高温自清洁已完成", isError: false)
            }
        }
        model.operationNotice = AppModel.OperationNotice(text: "已启动 56°C 高温除菌自清洁（约20分钟）", isError: false)
    }

    private func stopSelfCleaning() {
        isSelfCleaningInProgress = false
        timerTask?.cancel()
        model.operationNotice = AppModel.OperationNotice(text: "已退出自清洁模式", isError: false)
    }
}
